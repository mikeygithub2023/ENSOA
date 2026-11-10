import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sig_ensoa/core/supabase_client.dart';
import 'package:sig_ensoa/core/chargement.dart';
import '../models/pannes.dart';
import '../models/vehicule.dart';
import 'fleet_providers.dart';

// --- Pannes ------------------------------------------------------------------

Panne _panneFromRow(Map<String, dynamic> r) => Panne(
  id: r['id'].toString(),
  vehiculeId: r['vehicule_id'].toString(),
  description: r['description'] as String,
  gravite: graviteDepuisDb(r['gravite'] as String),
  dateSignalement: DateTime.parse(r['date_signalement'] as String),
  signaleParId: r['signale_par'] as String,
  demandeId: r['demande_id']?.toString(),
  resolue: r['resolue'] as bool? ?? false,
  reparationId: r['reparation_id']?.toString(),
);

class PannesNotifier extends Notifier<List<Panne>> {
  @override
  List<Panne> build() {
    Future.microtask(refresh);
    return [];
  }

  Future<void> refresh() async {
    final rows = await logistique
        .from('panne')
        .select()
        .order('date_signalement', ascending: false);
    state = (rows as List)
        .map((r) => _panneFromRow(r as Map<String, dynamic>))
        .toList();
    ref.read(chargementProvider.notifier).marquerCharge('pannes');
  }

  Future<void> signaler(Panne p) async {
    await logistique.from('panne').insert({
      'vehicule_id': int.parse(p.vehiculeId),
      'description': p.description,
      'gravite': p.gravite.valeurDb,
      'signale_par': p.signaleParId,
    });
    await refresh();
  }

  Future<void> supprimer(String id) async {
    await logistique.from('panne').delete().eq('id', int.parse(id));
    await refresh();
  }
}

final pannesProvider = NotifierProvider<PannesNotifier, List<Panne>>(
  PannesNotifier.new,
);

/// Les pannes non encore résolues d'un véhicule — celles qu'une demande de
/// réparation reprendra.
final pannesOuvertesProvider = Provider.family<List<Panne>, String>((
  ref,
  vehiculeId,
) {
  return ref
      .watch(pannesProvider)
      .where((p) => p.vehiculeId == vehiculeId && !p.resolue)
      .toList();
});

/// Les pannes ouvertes qu'aucune demande ne reprend encore — les seules
/// qu'une nouvelle demande puisse reprendre. Celles d'une demande en attente,
/// ou d'une réparation en cours, sont déjà prises.
final pannesLibresProvider = Provider.family<List<Panne>, String>((
  ref,
  vehiculeId,
) {
  return ref
      .watch(pannesOuvertesProvider(vehiculeId))
      .where((p) => p.demandeId == null)
      .toList();
});

// --- Demandes de mise en réparation ------------------------------------------

DemandeReparation _demandeFromRow(Map<String, dynamic> r) => DemandeReparation(
  id: r['id'].toString(),
  vehiculeId: r['vehicule_id'].toString(),
  statut: statutDemandeDepuisDb(r['statut'] as String),
  commentaire: r['commentaire'] as String?,
  dateDemande: DateTime.parse(r['date_demande'] as String),
  demandeParId: r['demande_par'] as String,
  dateDecision: r['date_decision'] != null
      ? DateTime.parse(r['date_decision'] as String)
      : null,
  decideParId: r['decide_par'] as String?,
  reparationId: r['reparation_id']?.toString(),
);

class DemandesReparationNotifier extends Notifier<List<DemandeReparation>> {
  @override
  List<DemandeReparation> build() {
    Future.microtask(refresh);
    return [];
  }

  Future<void> refresh() async {
    final rows = await logistique
        .from('demande_reparation')
        .select()
        .order('date_demande', ascending: false);
    state = (rows as List)
        .map((r) => _demandeFromRow(r as Map<String, dynamic>))
        .toList();
    ref.read(chargementProvider.notifier).marquerCharge('demandes_reparation');
  }

  /// Ouvre une demande au vu des pannes du véhicule : la demande attend la
  /// validation d'un supérieur, et les pannes qu'elle reprend s'y rattachent.
  Future<void> demander({
    required String vehiculeId,
    required String demandeParId,
    String? commentaire,
    required List<String> panneIds,
  }) async {
    final row = await logistique
        .from('demande_reparation')
        .insert({
          'vehicule_id': int.parse(vehiculeId),
          'demande_par': demandeParId,
          'commentaire': commentaire,
        })
        .select('id')
        .single();
    final demandeId = row['id'];
    if (panneIds.isNotEmpty) {
      await logistique
          .from('panne')
          .update({'demande_id': demandeId})
          .inFilter('id', panneIds.map(int.parse).toList());
    }
    await refresh();
    ref.read(pannesProvider.notifier).refresh();
  }

  /// Valide la demande : ouvre la réparation et met le véhicule « En
  /// réparation ». C'est le seul endroit où une demande fait basculer l'état
  /// du véhicule.
  ///
  /// Les pannes reprises restent ouvertes, rattachées à la demande : c'est au
  /// retour sur base qu'on dit lesquelles ont été réparées.
  Future<void> valider(
    DemandeReparation d, {
    required String validateurId,
    required String pannesTexte,
  }) async {
    final rep = await logistique
        .from('reparation')
        .insert({
          'pannes_constatees': pannesTexte,
          'vehicule_id': int.parse(d.vehiculeId),
          'utilisateur_id': validateurId,
        })
        .select('id')
        .single();

    await logistique
        .from('demande_reparation')
        .update({
          'statut': 'validee',
          'date_decision': DateTime.now().toIso8601String(),
          'decide_par': validateurId,
          'reparation_id': rep['id'],
        })
        .eq('id', int.parse(d.id));

    await ref
        .read(vehiculesProvider.notifier)
        .updateEtat(d.vehiculeId, EtatVehicule.enReparation);

    await refresh();
    ref.read(reparationsProvider.notifier).refresh();
    ref.read(pannesProvider.notifier).refresh();
  }

  /// Refuse la demande : rien ne bouge côté véhicule, et les pannes
  /// redeviennent libres pour une demande ultérieure.
  Future<void> refuser(
    DemandeReparation d, {
    required String validateurId,
  }) async {
    await logistique
        .from('demande_reparation')
        .update({
          'statut': 'refusee',
          'date_decision': DateTime.now().toIso8601String(),
          'decide_par': validateurId,
        })
        .eq('id', int.parse(d.id));

    await logistique
        .from('panne')
        .update({'demande_id': null})
        .eq('demande_id', int.parse(d.id));

    await refresh();
    ref.read(pannesProvider.notifier).refresh();
  }
}

/// Le retour sur base d'un véhicule réparé : la réparation se clôt, et
/// chaque panne reçoit son sort.
///
/// Les pannes cochées comme réparées se résolvent. Les autres restent sur le
/// véhicule, détachées de leur demande — libres pour une demande ultérieure.
/// Les pannes décelées pendant la réparation et laissées en l'état s'ajoutent
/// au véhicule, avec la trace de la réparation qui les a découvertes. Le
/// véhicule prend enfin l'état constaté au retour.
Future<void> validerRetourSurBase(
  WidgetRef ref, {
  required String reparationId,
  required String vehiculeId,
  required String auteurId,
  required String travauxEffectues,
  required EtatVehicule etatRetour,
  required List<String> pannesReparees,
  required List<String> pannesNonReparees,
  required List<PanneDecelee> pannesDecelees,
}) async {
  await ref
      .read(reparationsProvider.notifier)
      .cloturer(reparationId, solutionsApportees: travauxEffectues);

  if (pannesReparees.isNotEmpty) {
    await logistique
        .from('panne')
        .update({'resolue': true})
        .inFilter('id', pannesReparees.map(int.parse).toList());
  }
  if (pannesNonReparees.isNotEmpty) {
    await logistique
        .from('panne')
        .update({'resolue': false, 'demande_id': null})
        .inFilter('id', pannesNonReparees.map(int.parse).toList());
  }
  if (pannesDecelees.isNotEmpty) {
    await logistique.from('panne').insert([
      for (final p in pannesDecelees)
        {
          'vehicule_id': int.parse(vehiculeId),
          'description': p.description,
          'gravite': p.gravite.valeurDb,
          'signale_par': auteurId,
          'reparation_id': int.parse(reparationId),
        },
    ]);
  }

  await ref.read(vehiculesProvider.notifier).updateEtat(vehiculeId, etatRetour);
  await ref.read(pannesProvider.notifier).refresh();
}

final demandesReparationProvider =
    NotifierProvider<DemandesReparationNotifier, List<DemandeReparation>>(
      DemandesReparationNotifier.new,
    );
