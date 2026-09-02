import 'package:intl/intl.dart';

import 'package:sig_ensoa/core/supabase_client.dart';
import '../../../models/consultation_medicale.dart';
import '../../../models/medicament.dart';

/// Données saisies pour enregistrer une consultation. Pour une consultation
/// de routine, c'est l'autorisation de l'apprenant à consulter le médecin
/// qui est enregistrée ici (le reste sera saisi par le médecin via
/// [ConsultationsMedicalesRepository.completeConsultation]) ; pour une
/// urgence, [type] vaut [ConsultationType.urgence] et la consultation peut
/// être créée directement avec le statut "en_cours" ou "terminee".
class ConsultationMedicaleDraft {
  const ConsultationMedicaleDraft({
    required this.apprenantId,
    required this.divisionId,
    required this.classeId,
    required this.dateSouhaitee,
    this.type = ConsultationType.routine,
    this.statut,
  });

  final String apprenantId;
  final String divisionId;
  final String classeId;
  final DateTime dateSouhaitee;
  final ConsultationType type;
  final ConsultationStatut? statut;

  Map<String, dynamic> toInsertJson() {
    return {
      'apprenant_id': apprenantId,
      'division_id': divisionId,
      'classe_id': classeId,
      'date_souhaitee': DateFormat('yyyy-MM-dd').format(dateSouhaitee),
      'type': type.value,
      if (statut != null) 'statut': statut!.value,
    };
  }
}

class ConsultationsMedicalesRepository {
  Future<List<ConsultationMedicale>> fetchByClasse(String classeId) async {
    final rows = await scolarite
        .from('consultations_medicales')
        .select()
        .eq('classe_id', classeId)
        .order('date_souhaitee', ascending: false);
    return rows.map(ConsultationMedicale.fromJson).toList();
  }

  /// Toutes les consultations d'une division, toutes phases et stages
  /// confondues — utilisé sous "Toutes phases / stages".
  Future<List<ConsultationMedicale>> fetchByDivision(String divisionId) async {
    final rows = await scolarite
        .from('consultations_medicales')
        .select()
        .eq('division_id', divisionId)
        .order('date_souhaitee', ascending: false);
    return rows.map(ConsultationMedicale.fromJson).toList();
  }

  /// Toutes celles que l'utilisateur a le droit de voir, divisions
  /// confondues — la vue « Toutes ». La RLS borne le résultat.
  Future<List<ConsultationMedicale>> fetchToutes() async {
    final rows = await scolarite
        .from('consultations_medicales')
        .select()
        .order('date_souhaitee', ascending: false);
    return rows.map(ConsultationMedicale.fromJson).toList();
  }

  /// Toutes les consultations d'un apprenant précis — utilisé dans sa
  /// fiche détaillée.
  Future<List<ConsultationMedicale>> fetchByApprenant(
    String apprenantId,
  ) async {
    final rows = await scolarite
        .from('consultations_medicales')
        .select()
        .eq('apprenant_id', apprenantId)
        .order('date_souhaitee', ascending: false);
    return rows.map(ConsultationMedicale.fromJson).toList();
  }

  /// Retourne l'id de la consultation créée — utilisé pour l'urgence, où
  /// des lignes d'ordonnance sont ajoutées juste après dans la foulée.
  Future<String> createConsultation(ConsultationMedicaleDraft draft) async {
    final inserted = await scolarite
        .from('consultations_medicales')
        .insert(draft.toInsertJson())
        .select('id')
        .single();
    return inserted['id'] as String;
  }

  /// Le médecin démarre la consultation autorisée.
  Future<void> startConsultation(String id) async {
    await scolarite
        .from('consultations_medicales')
        .update({'statut': 'en_cours'})
        .eq('id', id);
  }

  /// Le médecin termine la consultation et saisit ses prescriptions —
  /// les médicaments, eux, sont ajoutés séparément via
  /// [addOrdonnanceLigne].
  Future<void> completeConsultation(
    String id, {
    Pathologie? pathologie,
    String? pathologieDetails,
    int? joursRepos,
    required bool exemption,
    required bool hospitalisationInterne,
    required bool hospitalisationExterne,
    String? examensDemandes,
    String? exemptionDetails,
    String? hospitalisationInterneLieu,
    String? hospitalisationExterneLieu,
  }) async {
    await scolarite
        .from('consultations_medicales')
        .update({
          'statut': 'terminee',
          'pathologie': pathologie?.value,
          'pathologie_details': pathologieDetails,
          'jours_repos': joursRepos,
          'exemption': exemption,
          'hospitalisation_interne': hospitalisationInterne,
          'hospitalisation_externe': hospitalisationExterne,
          'examens_demandes': examensDemandes,
          'exemption_details': exemption ? exemptionDetails : null,
          'hospitalisation_interne_lieu': hospitalisationInterne
              ? hospitalisationInterneLieu
              : null,
          'hospitalisation_externe_lieu': hospitalisationExterne
              ? hospitalisationExterneLieu
              : null,
        })
        .eq('id', id);
  }

  Future<void> deleteConsultation(String id) async {
    await scolarite.from('consultations_medicales').delete().eq('id', id);
  }

  Future<List<OrdonnanceLigne>> fetchOrdonnanceLignes(
    String consultationId,
  ) async {
    final rows = await scolarite
        .from('ordonnance_lignes')
        .select()
        .eq('consultation_id', consultationId);
    return rows.map(OrdonnanceLigne.fromJson).toList();
  }

  /// Prescrit un médicament pour cette consultation — décompte
  /// automatiquement son stock (trigger côté base, échoue si le stock est
  /// insuffisant).
  Future<void> addOrdonnanceLigne({
    required String consultationId,
    required String medicamentId,
    required int quantite,
    String? posologie,
  }) async {
    await scolarite.from('ordonnance_lignes').insert({
      'consultation_id': consultationId,
      'medicament_id': medicamentId,
      'quantite': quantite,
      'posologie': posologie,
    });
  }

  /// Annule une prescription — restitue automatiquement le stock (trigger
  /// côté base).
  Future<void> deleteOrdonnanceLigne(String id) async {
    await scolarite.from('ordonnance_lignes').delete().eq('id', id);
  }
}
