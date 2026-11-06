import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sig_ensoa/core/theme.dart';
import 'package:sig_ensoa/core/chargement.dart';
import 'package:sig_ensoa/core/format.dart';
import 'package:sig_ensoa/shared/widgets/icone_arme.dart';
import '../../data/models/vehicule.dart';
import '../../data/repositories/armament_providers.dart';
import '../../data/repositories/fleet_providers.dart';
import '../../data/repositories/fuel_providers.dart';
import '../../shared/widgets/dashboard_widgets.dart';
import '../../shared/widgets/skeleton.dart';
import '../../shared/widgets/widgets.dart';
import 'alertes_card.dart';

/// Le détail du soutien technique, sous les tuiles du tableau de bord.
///
/// Ce qui se lit déjà sur les tuiles — véhicules disponibles, litres en soute —
/// n'est pas répété : on vient ici pour ce qui demande une décision d'abord
/// (alertes et suivi), pour les mouvements et la répartition ensuite.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key, this.sansCadre = false});

  /// Rendre le contenu nu, sans titre ni défilement propre : le tableau de bord
  /// qui l'accueille s'en charge.
  final bool sansCadre;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // On watch systématiquement tous les providers en premier (même si on va
    // afficher un skeleton) : les providers Riverpod sont paresseux et ne
    // démarrent leur chargement Supabase qu'à la première lecture. Vérifier
    // `estCharge` avant de les lire ne ferait jamais démarrer ce chargement.
    final vehicules = ref.watch(vehiculesProvider);
    final soutesAvecStock = ref.watch(soutesAvecStockProvider);
    final journal = ref.watch(journalCarburantProvider);
    final armes = ref.watch(armesProvider);
    final soutesAlerte = ref.watch(soutesEnAlerteProvider);
    final vehiculesVidange = ref.watch(vehiculesEnAlerteVidangeProvider);
    final dotationsRetard = ref.watch(dotationsEnRetardProvider);
    final armesRetard = ref.watch(armesInspectionEnRetardProvider);

    final charge = estCharge(ref, [
      'vehicules',
      'soutes',
      'soute_stocks',
      'depotages',
      'distributions',
    ]);
    if (!charge) {
      return sansCadre
          ? const SkeletonDashboard()
          : const ScreenScaffold(
              title: 'Tableau de bord',
              children: [SkeletonDashboard()],
            );
    }

    final totalStock = soutesAvecStock.fold<int>(
      0,
      (s, x) => s + x.stock.quantiteTotale,
    );
    // Une soute peut porter plusieurs répartitions : on additionne les lignes
    // qui la concernent, pour n'annoncer qu'un chiffre par soute.
    final parSoute = <String, int>{};
    for (final x in soutesAvecStock) {
      parSoute[x.soute.libelle] =
          (parSoute[x.soute.libelle] ?? 0) + x.stock.quantiteTotale;
    }
    final soutesParVolume =
        parSoute.entries.map((e) => (e.key, e.value)).toList()
          ..sort((a, b) => b.$2.compareTo(a.$2));

    // Le journal porte tout l'historique : la carte annonce « du jour », elle
    // ne doit compter que depuis minuit, heure du poste.
    final maintenant = DateTime.now();
    final minuit = DateTime(maintenant.year, maintenant.month, maintenant.day);
    final duJour = journal.where((j) => !j.date.toLocal().isBefore(minuit));
    final entreesJour = duJour
        .where((j) => j.entree)
        .fold<int>(0, (s, j) => s + j.quantite);
    final sortiesJour = duJour
        .where((j) => !j.entree)
        .fold<int>(0, (s, j) => s + j.quantite);
    final solde = entreesJour - sortiesJour;

    // Comme au garage : un véhicule hors service n'est disponible pour
    // personne, et le compter ferait paraître vide un type qui ne l'est pas.
    final parType = <String, (int, int)>{};
    var horsService = 0;
    for (final v in vehicules) {
      if (v.etat == EtatVehicule.horsService) {
        horsService++;
        continue;
      }
      final (d, t) = parType[v.typeVehicule] ?? (0, 0);
      parType[v.typeVehicule] = (
        d + (v.etat == EtatVehicule.disponible ? 1 : 0),
        t + 1,
      );
    }
    final types = [
      for (final MapEntry(key: type, value: (d, t)) in parType.entries)
        (type, d, t),
    ]..sort((a, b) => b.$3.compareTo(a.$3));

    final alertes = <Alerte>[
      for (final s in soutesAlerte)
        Alerte(
          '${s.soute.libelle} — stock critique',
          () => context.go('/logistique/carburant'),
          icone: Icons.warehouse_rounded,
        ),
      for (final v in vehiculesVidange)
        Alerte(
          '${v.marque} ${v.modele} — vidange à prévoir',
          () => context.go('/logistique/parc'),
          icone: Icons.oil_barrel_rounded,
        ),
      for (final d in dotationsRetard)
        Alerte(
          'Retour d\'arme en retard — ${d.beneficiaireId}',
          () => context.go('/logistique/armement'),
          icone: Icons.assignment_late_rounded,
        ),
      for (final a in armesRetard)
        Alerte(
          '${a.modele} — inspection en retard',
          () => context.go('/logistique/armement'),
          iconeWidget: const IconeArmeTeintee(
            couleur: AppColors.blueBright,
            size: 18,
          ),
        ),
    ];

    final suivi = Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            DotProgressRow(
              icon: Icons.local_gas_station_rounded,
              iconColor: AppColors.blue,
              title: 'Carburant',
              subtitle: 'Soutes au-dessus du seuil critique',
              completed: soutesAvecStock.length - soutesAlerte.length,
              total: soutesAvecStock.length,
              onTap: () => context.go('/logistique/carburant'),
            ),
            const Divider(height: 1),
            DotProgressRow(
              icon: Icons.car_repair_rounded,
              iconColor: AppColors.warning,
              title: 'Maintenance',
              subtitle: 'Véhicules sans vidange en attente',
              completed: vehicules.length - vehiculesVidange.length,
              total: vehicules.length,
              onTap: () => context.go('/logistique/parc'),
            ),
            const Divider(height: 1),
            DotProgressRow(
              icon: Icons.assignment_ind_rounded,
              iconColor: AppColors.navy,
              title: 'Dotations armement',
              subtitle: 'Retours dans les délais',
              completed: dotationsRetard.isEmpty ? 1 : 0,
              total: 1,
              onTap: () => context.go('/logistique/armement'),
            ),
            const Divider(height: 1),
            DotProgressRow(
              iconWidget: const IconeArmeTeintee(
                couleur: AppColors.success,
                size: 22,
              ),
              iconColor: AppColors.success,
              title: 'Inspections armes',
              subtitle: 'Armes à jour de contrôle',
              completed: armes.length - armesRetard.length,
              total: armes.length,
              onTap: () => context.go('/logistique/armement'),
            ),
          ],
        ),
      ),
    );

    final contenu = <Widget>[
      _Rangee(
        gauche: AlertesCard(alertes: alertes),
        droite: suivi,
      ),
      const SizedBox(height: 16),
      _Rangee(
        gauche: FuelOverviewCard(
          title: 'Carburant du jour',
          subtitle: 'Entrées et sorties depuis minuit',
          // Le stock se lit déjà sur sa tuile et sur la carte voisine ; ce que
          // personne d'autre ne dit, c'est ce que la journée a changé.
          stockLabel: 'Solde de la journée',
          stockValue: '${solde > 0 ? '+' : ''}${formatMilliers(solde)} L',
          entrees: entreesJour,
          sorties: sortiesJour,
        ),
        droite: SoutesStockCard(
          title: 'Carburant en soute',
          total: totalStock,
          soutes: soutesParVolume,
        ),
      ),
      const SizedBox(height: 16),
      DisponibiliteParTypeCard(
        title: 'Disponibilité par type',
        subtitle: horsService == 0
            ? 'Véhicules prêts sur le parc en service'
            : 'Véhicules prêts sur le parc en service — '
                  '$horsService hors service, non comptés',
        types: types,
      ),
    ];

    // Sans cadre, le tableau rend sa suite de blocs telle quelle : c'est la
    // page d'accueil qui porte le titre et le défilement.
    return sansCadre
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: contenu,
          )
        : ScreenScaffold(title: 'Tableau de bord', children: contenu);
  }
}

/// Deux cartes de même hauteur côte à côte, ou l'une sous l'autre quand la
/// largeur manque. Aucune des deux ne doit contenir de `LayoutBuilder`, que
/// `IntrinsicHeight` ne sait pas mesurer.
class _Rangee extends StatelessWidget {
  const _Rangee({required this.gauche, required this.droite});

  final Widget gauche;
  final Widget droite;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, contraintes) {
        if (contraintes.maxWidth <= 820) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [gauche, const SizedBox(height: 16), droite],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: gauche),
              const SizedBox(width: 16),
              Expanded(child: droite),
            ],
          ),
        );
      },
    );
  }
}
