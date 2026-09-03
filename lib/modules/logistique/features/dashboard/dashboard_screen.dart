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

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key, this.sansCadre = false});

  /// Rendre le contenu nu, sans titre ni défilement propre : la page unifiée
  /// s'en charge quand elle réunit les deux domaines.
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
      return const ScreenScaffold(
        title: 'Tableau de bord',
        children: [SkeletonDashboard()],
      );
    }

    final disponibles = vehicules
        .where((v) => v.etat == EtatVehicule.disponible)
        .length;
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
    final entreesJour = journal
        .where((j) => j.entree)
        .fold<int>(0, (s, j) => s + j.quantite);
    final sortiesJour = journal
        .where((j) => !j.entree)
        .fold<int>(0, (s, j) => s + j.quantite);

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

    final contenu = <Widget>[
      LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth > 820;
          final blob = FuelOverviewCard(
            title: 'Aperçu carburant du jour',
            subtitle: 'Entrées / sorties / stock total',
            stockLabel: 'Stock total (toutes soutes)',
            stockValue: '${formatMilliers(totalStock)} L',
            entrees: entreesJour,
            sorties: sortiesJour,
          );
          final darkCard = AlertesCard(alertes: alertes);
          if (!wide) {
            return Column(
              children: [blob, const SizedBox(height: 16), darkCard],
            );
          }
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 6, child: blob),
                const SizedBox(width: 16),
                Expanded(flex: 5, child: darkCard),
              ],
            ),
          );
        },
      ),
      const SizedBox(height: 16),
      LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth > 820;
          final gauge = GaugeCard(
            title: 'Disponibilité du parc',
            subtitle: 'Véhicules prêts à l\'emploi',
            progress: vehicules.isEmpty ? 0 : disponibles / vehicules.length,
            centerValue: '$disponibles/${vehicules.length}',
            centerLabel: 'dispo.',
            color: AppColors.success,
          );
          final pill = SoutesStockCard(
            title: 'Carburant en soute',
            total: totalStock,
            soutes: soutesParVolume,
          );
          if (!wide) {
            return Column(children: [gauge, const SizedBox(height: 16), pill]);
          }
          // Côte à côte, deux cartes de hauteurs différentes donnent une
          // ligne bancale : on leur impose la hauteur de la plus haute,
          // calculée plutôt que mesurée — voir `hauteurPour`.
          return SizedBox(
            height: SoutesStockCard.hauteurPour(soutesParVolume.length),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: gauge),
                const SizedBox(width: 16),
                Expanded(child: pill),
              ],
            ),
          );
        },
      ),
      const SizedBox(height: 24),
      const SectionHeader(title: 'Suivi par domaine'),
      Card(
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
      ),
    ];

    // Sans cadre, le tableau rend sa suite de blocs telle quelle : c'est la
    // page unifiée qui porte le titre et le défilement, pour que scolarité et
    // soutien technique se lisent d'un seul mouvement.
    return sansCadre
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: contenu,
          )
        : ScreenScaffold(title: 'Tableau de bord', children: contenu);
  }
}
