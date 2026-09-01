import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sig_ensoa/core/theme.dart';
import 'package:sig_ensoa/core/chargement.dart';
import 'package:sig_ensoa/core/format.dart';
import '../../data/models/vehicule.dart';
import '../../data/repositories/armament_providers.dart';
import '../../data/repositories/fleet_providers.dart';
import '../../data/repositories/fuel_providers.dart';
import '../../shared/widgets/dashboard_widgets.dart';
import '../../shared/widgets/skeleton.dart';
import '../../shared/widgets/widgets.dart';

/// La hauteur commune de la jauge du parc et de la pilule des soutes. Tient
/// la plus haute des deux — la pilule, avec son titre, sa réglette et ses
/// bornes chiffrées.
const double _hauteurCartesJauge = 176;

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
    final totalNominal = soutesAvecStock.fold<int>(
      0,
      (s, x) => s + x.stock.seuilNominal,
    );
    final entreesJour = journal
        .where((j) => j.entree)
        .fold<int>(0, (s, j) => s + j.quantite);
    final sortiesJour = journal
        .where((j) => !j.entree)
        .fold<int>(0, (s, j) => s + j.quantite);

    final alertes = <_Alerte>[
      for (final s in soutesAlerte)
        _Alerte(
          '${s.soute.libelle} — stock critique',
          () => context.go('/logistique/carburant'),
        ),
      for (final v in vehiculesVidange)
        _Alerte(
          '${v.marque} ${v.modele} — vidange à prévoir',
          () => context.go('/logistique/parc'),
        ),
      for (final d in dotationsRetard)
        _Alerte(
          'Retour d\'arme en retard — ${d.beneficiaireId}',
          () => context.go('/logistique/armement'),
        ),
      for (final a in armesRetard)
        _Alerte(
          '${a.modele} — inspection en retard',
          () => context.go('/logistique/armement'),
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
            final darkCard = DarkFeatureCard(
              title: 'Alertes prioritaires',
              child: alertes.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Aucune alerte en cours — situation nominale.',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    )
                  : Column(
                      children: [
                        for (final a in alertes.take(5))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: InkWell(
                              onTap: a.onTap,
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: AppColors.blueBright,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      a.label,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    color: Colors.white38,
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
            );
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
            final pill = ProgressPillCard(
              title: 'Remplissage des soutes',
              percentLabel: totalNominal == 0
                  ? '—'
                  : '${((totalStock / totalNominal) * 100).clamp(0, 100).toStringAsFixed(0)}%',
              progress: totalNominal == 0 ? 0 : totalStock / totalNominal,
              pillLabel: '${formatMilliers(totalStock)} L',
              startLabel: '0 L',
              endLabel: '${formatMilliers(totalNominal)} L (nominal)',
            );
            if (!wide) {
              return Column(
                children: [gauge, const SizedBox(height: 16), pill],
              );
            }
            // Côte à côte, deux cartes de hauteurs différentes donnent une
            // ligne bancale. On leur impose donc une hauteur commune —
            // sans passer par `IntrinsicHeight`, qui interrogerait la
            // « pilule » sur sa hauteur naturelle : elle se dessine dans un
            // `LayoutBuilder`, qui refuse cette question par une assertion et
            // laissait la page entièrement blanche.
            return SizedBox(
              height: _hauteurCartesJauge,
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
                  icon: Icons.build_rounded,
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
                  icon: Icons.rule_rounded,
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
        ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: contenu)
        : ScreenScaffold(title: 'Tableau de bord', children: contenu);
  }
}

class _Alerte {
  final String label;
  final VoidCallback onTap;
  const _Alerte(this.label, this.onTap);
}
