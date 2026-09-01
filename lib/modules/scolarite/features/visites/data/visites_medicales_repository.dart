import 'package:intl/intl.dart';

import 'package:sig_ensoa/core/supabase_client.dart';
import '../../../models/visite_medicale.dart';

/// Création d'une visite médicale : le médecin annonce la campagne (titre,
/// classe/stage convoquée, date, type) avant d'y ajouter les apprenants un
/// à un. La division est dérivée de la classe/stage choisie.
class VisiteMedicaleDraft {
  const VisiteMedicaleDraft({
    required this.titre,
    required this.divisionId,
    required this.classeId,
    required this.dateVisite,
    required this.type,
  });

  final String titre;
  final String divisionId;
  final String classeId;
  final DateTime dateVisite;
  final VisiteType type;

  Map<String, dynamic> toJson() {
    return {
      'titre': titre,
      'division_id': divisionId,
      'classe_id': classeId,
      'date_visite': DateFormat('yyyy-MM-dd').format(dateVisite),
      'type': type.value,
    };
  }
}

/// Examen d'un apprenant passé à une visite. L'indice de Pignet est absent :
/// c'est une colonne calculée par la base à partir de la taille, du poids
/// et du PTM (voir la migration 027).
class VisiteApprenantDraft {
  const VisiteApprenantDraft({
    required this.apprenantId,
    required this.resultat,
    this.observations,
    this.tailleCm,
    this.poidsKg,
    this.ptmCm,
    this.tensionArterielle,
    this.pouls,
    this.vod,
    this.vog,
    this.aod,
    this.aog,
    this.urineSucre,
    this.urineAlbumine,
    this.clinique,
    this.sigycop = const {},
  });

  final String apprenantId;
  final VisiteResultat resultat;
  final String? observations;
  final num? tailleCm;
  final num? poidsKg;
  final num? ptmCm;
  final String? tensionArterielle;
  final int? pouls;
  final String? vod;
  final String? vog;
  final String? aod;
  final String? aog;
  final String? urineSucre;
  final String? urineAlbumine;
  final String? clinique;
  final Map<SigycopLettre, int> sigycop;

  Map<String, dynamic> toJson() {
    return {
      'apprenant_id': apprenantId,
      'resultat': resultat.value,
      'observations': observations,
      'taille_cm': tailleCm,
      'poids_kg': poidsKg,
      'ptm_cm': ptmCm,
      'tension_arterielle': tensionArterielle,
      'pouls': pouls,
      'vod': vod,
      'vog': vog,
      'aod': aod,
      'aog': aog,
      'urine_sucre': urineSucre,
      'urine_albumine': urineAlbumine,
      'clinique': clinique,
      for (final lettre in SigycopLettre.values)
        'sigycop_${lettre.name}': sigycop[lettre],
    };
  }
}

class VisitesMedicalesRepository {
  /// Toutes les visites de l'école, les plus récentes d'abord — le médecin
  /// est le seul à y avoir accès (policies RLS).
  Future<List<VisiteMedicale>> fetchAll() async {
    final rows = await scolarite
        .from('visites_medicales')
        .select()
        .order('date_visite', ascending: false);
    return rows.map(VisiteMedicale.fromJson).toList();
  }

  Future<VisiteMedicale?> fetchById(String id) async {
    final row = await scolarite
        .from('visites_medicales')
        .select()
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : VisiteMedicale.fromJson(row);
  }

  Future<void> createVisite(VisiteMedicaleDraft draft) async {
    await scolarite.from('visites_medicales').insert(draft.toJson());
  }

  Future<void> updateVisite(String id, VisiteMedicaleDraft draft) async {
    await scolarite
        .from('visites_medicales')
        .update(draft.toJson())
        .eq('id', id);
  }

  /// Supprime la visite et, en cascade, les examens des apprenants qui y
  /// ont été enregistrés.
  Future<void> deleteVisite(String id) async {
    await scolarite.from('visites_medicales').delete().eq('id', id);
  }

  Future<List<VisiteMedicaleApprenant>> fetchApprenants(String visiteId) async {
    final rows = await scolarite
        .from('visites_medicales_apprenants')
        .select()
        .eq('visite_id', visiteId)
        .order('created_at');
    return rows.map(VisiteMedicaleApprenant.fromJson).toList();
  }

  /// Nombre d'apprenants déjà passés, par visite — pour l'afficher dans la
  /// liste des visites sans charger tous les examens.
  Future<Map<String, int>> fetchEffectifs() async {
    final rows = await scolarite
        .from('visites_medicales_apprenants')
        .select('visite_id');
    final effectifs = <String, int>{};
    for (final row in rows) {
      final visiteId = row['visite_id'] as String;
      effectifs[visiteId] = (effectifs[visiteId] ?? 0) + 1;
    }
    return effectifs;
  }

  Future<void> addApprenant(String visiteId, VisiteApprenantDraft draft) async {
    await scolarite.from('visites_medicales_apprenants').insert({
      'visite_id': visiteId,
      ...draft.toJson(),
    });
  }

  Future<void> updateApprenant(String id, VisiteApprenantDraft draft) async {
    await scolarite
        .from('visites_medicales_apprenants')
        .update(draft.toJson())
        .eq('id', id);
  }

  Future<void> deleteApprenant(String id) async {
    await scolarite.from('visites_medicales_apprenants').delete().eq('id', id);
  }
}
