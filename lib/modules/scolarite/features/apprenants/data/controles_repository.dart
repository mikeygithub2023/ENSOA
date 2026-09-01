import 'package:sig_ensoa/core/supabase_client.dart';
import '../../../models/controle.dart';
import '../../../models/note.dart';

/// Données saisies pour l'enregistrement d'un contrôle. [matiereId] n'est
/// renseigné que pour un module (un module EST une matière) ; [libelle]
/// reprend alors le nom de cette matière.
class ControleDraft {
  const ControleDraft({
    required this.divisionId,
    required this.classeId,
    required this.type,
    required this.libelle,
    required this.coefficient,
    this.matiereId,
  });

  final String divisionId;
  final String classeId;
  final ControleType type;
  final String libelle;
  final num coefficient;
  final String? matiereId;

  Map<String, dynamic> toInsertJson() {
    return {
      'division_id': divisionId,
      'classe_id': classeId,
      'type': type.value,
      'libelle': libelle,
      'coefficient': coefficient,
      'matiere_id': matiereId,
    };
  }
}

class ControlesRepository {
  Future<List<Controle>> fetchByClasse(String classeId) async {
    final rows = await scolarite
        .from('controles')
        .select()
        .eq('classe_id', classeId)
        .order('created_at', ascending: false);
    return rows.map(Controle.fromJson).toList();
  }

  /// Toutes les notes d'une classe/stage, tous contrôles confondus — une
  /// seule requête, via la jointure sur `controles`, plutôt qu'un appel par
  /// contrôle. Sert aux statistiques de la classe.
  Future<List<Note>> fetchNotesByClasse(String classeId) async {
    final rows = await scolarite
        .from('notes')
        .select('*, controles!inner(classe_id)')
        .eq('controles.classe_id', classeId);
    return rows.map(Note.fromJson).toList();
  }

  Future<Controle?> fetchById(String controleId) async {
    final row = await scolarite
        .from('controles')
        .select()
        .eq('id', controleId)
        .maybeSingle();
    return row == null ? null : Controle.fromJson(row);
  }

  Future<void> createControle(ControleDraft draft) async {
    await scolarite.from('controles').insert(draft.toInsertJson());
  }

  Future<void> updateControle({
    required String controleId,
    required String libelle,
    required num coefficient,
    String? matiereId,
  }) async {
    await scolarite
        .from('controles')
        .update({
          'libelle': libelle,
          'coefficient': coefficient,
          'matiere_id': matiereId,
        })
        .eq('id', controleId);
  }

  Future<void> deleteControle(String controleId) async {
    await scolarite.from('controles').delete().eq('id', controleId);
  }

  /// Coche/décoche un contrôle pour le calcul des bulletins (menu
  /// "Bulletins", réservé à l'administrateur).
  Future<void> setInclusBulletin(String controleId, bool value) async {
    await scolarite
        .from('controles')
        .update({'inclus_bulletin': value})
        .eq('id', controleId);
  }

  Future<List<Note>> fetchNotes(String controleId) async {
    final rows = await scolarite
        .from('notes')
        .select()
        .eq('controle_id', controleId);
    return rows.map(Note.fromJson).toList();
  }

  /// Toutes les notes (tous apprenants confondus) pour un ensemble de
  /// contrôles — utilisé pour générer en une fois les bulletins de toute
  /// une classe/stage.
  Future<List<Note>> fetchByControleIds(List<String> controleIds) async {
    if (controleIds.isEmpty) return [];
    final rows = await scolarite
        .from('notes')
        .select()
        .inFilter('controle_id', controleIds);
    return rows.map(Note.fromJson).toList();
  }

  /// Toutes les notes d'un apprenant, tous contrôles confondus — utilisé
  /// pour le récapitulatif de notes sur sa fiche.
  Future<List<Note>> fetchByApprenant(String apprenantId) async {
    final rows = await scolarite
        .from('notes')
        .select()
        .eq('apprenant_id', apprenantId);
    return rows.map(Note.fromJson).toList();
  }

  /// Une note se rattache soit à une matière (contrôle continu, examen),
  /// soit à un sous-module (contrôle de type "module") — l'un ou l'autre,
  /// jamais les deux : la base fait respecter la règle (migration 051).
  Future<void> createNote({
    required String controleId,
    required String apprenantId,
    required String? matiereId,
    required num note,
    String? sousModuleId,
  }) async {
    await scolarite.from('notes').insert({
      'controle_id': controleId,
      'apprenant_id': apprenantId,
      'matiere_id': matiereId,
      'sous_module_id': sousModuleId,
      'note': note,
    });
  }

  /// Modifie une note existante en conservant [previousNote] (l'ancienne
  /// valeur) pour l'indicateur "Note modifiée" affiché à l'écran.
  Future<void> updateNote({
    required String noteId,
    required num newNote,
    required num previousNote,
  }) async {
    await scolarite
        .from('notes')
        .update({
          'note': newNote,
          'previous_note': previousNote,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', noteId);
  }

  /// Suppression directe — réservée à l'administrateur par la RLS. Sert
  /// aussi à confirmer une demande de suppression en attente.
  ///
  /// Même précaution que pour un apprenant : sans le `select()` final, une
  /// suppression refusée par la RLS passerait pour un succès.
  Future<void> deleteNote(String noteId) async {
    final supprimees = await scolarite
        .from('notes')
        .delete()
        .eq('id', noteId)
        .select('id');

    if (supprimees.isEmpty) {
      throw Exception(
        'Aucune note n\'a été supprimée : votre rôle ne vous y autorise pas. '
        'Seul l\'administrateur supprime une note — les autres en font la '
        'demande, qui lui est notifiée.',
      );
    }
  }

  /// Un non-administrateur ne peut pas supprimer une note (RLS) : il ne
  /// fait que la marquer "Suppression demandée", ce qui déclenche une
  /// notification à tous les administrateurs (trigger côté base).
  Future<void> requestNoteDeletion(String noteId) async {
    final userId = supabase.auth.currentUser?.id;
    await scolarite
        .from('notes')
        .update({
          'deletion_requested_at': DateTime.now().toIso8601String(),
          'deletion_requested_by': userId,
        })
        .eq('id', noteId);
  }

  /// Annule une demande de suppression en attente sans supprimer la note.
  Future<void> rejectNoteDeletion(String noteId) async {
    await scolarite
        .from('notes')
        .update({'deletion_requested_at': null, 'deletion_requested_by': null})
        .eq('id', noteId);
    await socle.from('notifications').delete().eq('note_id', noteId);
  }
}
