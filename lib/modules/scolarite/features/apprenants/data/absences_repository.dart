import 'package:intl/intl.dart';

import 'package:sig_ensoa/core/supabase_client.dart';
import '../../../models/absence.dart';

/// Données saisies pour l'enregistrement d'une absence. Ni la date de fin
/// ni le caractère justifié/le motif ne sont connus à ce stade — ils sont
/// renseignés plus tard, au retour, via [AbsencesRepository.markRetour].
class AbsenceDraft {
  const AbsenceDraft({
    required this.apprenantId,
    required this.divisionId,
    required this.classeId,
    required this.dateDebut,
  });

  final String apprenantId;
  final String divisionId;
  final String classeId;
  final DateTime dateDebut;

  Map<String, dynamic> toInsertJson() {
    return {
      'apprenant_id': apprenantId,
      'division_id': divisionId,
      'classe_id': classeId,
      'date_debut': DateFormat('yyyy-MM-dd').format(dateDebut),
    };
  }
}

class AbsencesRepository {
  Future<List<Absence>> fetchByClasse(String classeId) async {
    final rows = await scolarite
        .from('absences')
        .select()
        .eq('classe_id', classeId)
        .order('date_debut', ascending: false);
    return rows.map(Absence.fromJson).toList();
  }

  /// Toutes les absences d'une division, toutes phases et stages confondues
  /// — utilisé sous "Toutes phases / stages".
  Future<List<Absence>> fetchByDivision(String divisionId) async {
    final rows = await scolarite
        .from('absences')
        .select()
        .eq('division_id', divisionId)
        .order('date_debut', ascending: false);
    return rows.map(Absence.fromJson).toList();
  }

  /// Toutes les absences d'un apprenant précis — utilisé dans sa fiche
  /// détaillée.
  Future<List<Absence>> fetchByApprenant(String apprenantId) async {
    final rows = await scolarite
        .from('absences')
        .select()
        .eq('apprenant_id', apprenantId)
        .order('date_debut', ascending: false);
    return rows.map(Absence.fromJson).toList();
  }

  Future<void> createAbsence(AbsenceDraft draft) async {
    await scolarite.from('absences').insert(draft.toInsertJson());
  }

  /// Marque le retour d'un apprenant absent : renseigne la date de fin
  /// d'une absence jusque-là en cours, ainsi que le caractère justifié et
  /// le motif éventuel.
  Future<void> markRetour(
    String absenceId, {
    required DateTime dateFin,
    required bool justifiee,
    String? motif,
  }) async {
    await scolarite
        .from('absences')
        .update({
          'date_fin': DateFormat('yyyy-MM-dd').format(dateFin),
          'justifiee': justifiee,
          'motif': motif,
        })
        .eq('id', absenceId);
  }

  Future<void> deleteAbsence(String absenceId) async {
    await scolarite.from('absences').delete().eq('id', absenceId);
  }
}
