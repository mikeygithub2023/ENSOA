import 'package:intl/intl.dart';

import 'package:sig_ensoa/core/supabase_client.dart';
import '../../../models/local_disciplinaire.dart';

/// Ce qu'on saisit en mettant quelqu'un aux locaux disciplinaires. La date
/// de sortie n'en fait pas partie : elle se marque au retour, par
/// [LocauxDisciplinairesRepository.marquerSortie].
class LocalDisciplinaireDraft {
  const LocalDisciplinaireDraft({
    required this.apprenantId,
    required this.divisionId,
    required this.dateDebut,
    required this.jours,
    required this.motif,
    this.classeId,
    this.autorite,
  });

  final String apprenantId;
  final String divisionId;

  /// Nulle pour le personnel de l'école : la base l'accepte ainsi.
  final String? classeId;

  final DateTime dateDebut;
  final int jours;
  final String motif;
  final String? autorite;

  Map<String, dynamic> toInsertJson() {
    return {
      'apprenant_id': apprenantId,
      'division_id': divisionId,
      'classe_id': classeId,
      'date_debut': DateFormat('yyyy-MM-dd').format(dateDebut),
      'jours': jours,
      'motif': motif,
      'autorite': autorite,
    };
  }
}

class LocauxDisciplinairesRepository {
  static const _table = 'locaux_disciplinaires';

  Future<List<LocalDisciplinaire>> fetchByClasse(String classeId) async {
    final rows = await scolarite
        .from(_table)
        .select()
        .eq('classe_id', classeId)
        .order('date_debut', ascending: false);
    return rows.map(LocalDisciplinaire.fromJson).toList();
  }

  /// Toute une division, phases et stages confondus — et le personnel, qui
  /// n'a ni l'un ni l'autre.
  Future<List<LocalDisciplinaire>> fetchByDivision(String divisionId) async {
    final rows = await scolarite
        .from(_table)
        .select()
        .eq('division_id', divisionId)
        .order('date_debut', ascending: false);
    return rows.map(LocalDisciplinaire.fromJson).toList();
  }

  /// Tout ce que l'utilisateur a le droit de voir, divisions confondues —
  /// la vue « Toutes ». La RLS borne le résultat.
  Future<List<LocalDisciplinaire>> fetchTous() async {
    final rows = await scolarite
        .from(_table)
        .select()
        .order('date_debut', ascending: false);
    return rows.map(LocalDisciplinaire.fromJson).toList();
  }

  Future<List<LocalDisciplinaire>> fetchByApprenant(String apprenantId) async {
    final rows = await scolarite
        .from(_table)
        .select()
        .eq('apprenant_id', apprenantId)
        .order('date_debut', ascending: false);
    return rows.map(LocalDisciplinaire.fromJson).toList();
  }

  Future<void> creer(LocalDisciplinaireDraft draft) async {
    await scolarite.from(_table).insert(draft.toInsertJson());
  }

  /// Marque la sortie : la punition est purgée, ou levée avant son terme.
  Future<void> marquerSortie(String id, {required DateTime dateSortie}) async {
    await scolarite
        .from(_table)
        .update({'date_sortie': DateFormat('yyyy-MM-dd').format(dateSortie)})
        .eq('id', id);
  }

  Future<void> supprimer(String id) async {
    await scolarite.from(_table).delete().eq('id', id);
  }
}
