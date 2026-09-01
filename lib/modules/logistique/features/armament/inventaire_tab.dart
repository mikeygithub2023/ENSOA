import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sig_ensoa/core/theme.dart';
import 'package:sig_ensoa/core/chargement.dart';
import 'package:sig_ensoa/core/format.dart';
import '../../data/models/armement.dart';
import '../../data/repositories/armament_providers.dart';
import '../../shared/widgets/dashboard_widgets.dart';
import '../../shared/widgets/skeleton.dart';
import 'package:sig_ensoa/shared/widgets/icone_arme.dart';
import '../../shared/widgets/widgets.dart';

/// Contenu de l'onglet "Inventaire" — vue de synthèse consolidée (armes,
/// munitions, équipements) et alertes du module Armement.
class InventaireTabContent extends ConsumerWidget {
  const InventaireTabContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final charge = estCharge(ref, [
      'armes',
      'dotations_armes',
      'munitions',
      'equipements',
    ]);
    final armes = ref.watch(armesProvider);
    final munitions = ref.watch(munitionsProvider);
    final equipements = ref.watch(equipementsProvider);
    final dotationsRetard = ref.watch(dotationsEnRetardProvider);
    final armesRetard = ref.watch(armesInspectionEnRetardProvider);
    final munitionsAlerte = ref.watch(munitionsEnAlerteProvider);
    final equipementsAlerte = ref.watch(equipementsEnAlerteProvider);

    if (!charge) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(4, 4, 4, 100),
        child: SkeletonGrid(
          itemCount: 4,
          maxCrossAxisExtent: 260,
          mainAxisExtent: 168,
        ),
      );
    }

    final totalMunitions = munitions.fold<int>(
      0,
      (s, m) => s + m.quantiteDisponible,
    );
    final totalEquipements = equipements.fold<int>(
      0,
      (s, e) => s + e.quantiteDisponible,
    );
    final parEtat = {
      for (final e in EtatArme.values)
        e: armes.where((a) => a.etat == e).length,
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 100),
      children: [
        SectionHeader(title: 'Vue d\'ensemble'),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(
              width: 240,
              child: StatCard(
                label: 'Armes au total',
                value: '${armes.length}',
                iconWidget: const IconeArme(size: 30),
                color: AppColors.navy,
              ),
            ),
            SizedBox(
              width: 240,
              child: StatCard(
                label: 'Munitions en stock',
                value: formatMilliers(totalMunitions),
                icon: Icons.scatter_plot_outlined,
                color: munitionsAlerte.isEmpty
                    ? AppColors.militaryGreen
                    : AppColors.danger,
                sublabel: munitionsAlerte.isEmpty
                    ? null
                    : '${munitionsAlerte.length} calibre(s) critique(s)',
              ),
            ),
            SizedBox(
              width: 240,
              child: StatCard(
                label: 'Équipements en stock',
                value: formatMilliers(totalEquipements),
                icon: Icons.shield_outlined,
                color: equipementsAlerte.isEmpty
                    ? AppColors.militaryGreen
                    : AppColors.danger,
                sublabel: equipementsAlerte.isEmpty
                    ? null
                    : '${equipementsAlerte.length} article(s) critique(s)',
              ),
            ),
            SizedBox(
              width: 240,
              child: StatCard(
                label: 'Retours en retard',
                value: '${dotationsRetard.length}',
                icon: Icons.assignment_late_outlined,
                color: dotationsRetard.isEmpty
                    ? AppColors.militaryGreen
                    : AppColors.danger,
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        SectionHeader(title: 'Répartition des armes par état'),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                for (final e in EtatArme.values) ...[
                  DotProgressRow(
                    iconWidget: const IconeArme(size: 28),
                    iconColor: AppColors.navy,
                    title: e.label,
                    subtitle: '${parEtat[e]} arme(s)',
                    completed: parEtat[e] ?? 0,
                    total: armes.isEmpty ? 1 : armes.length,
                  ),
                  if (e != EtatArme.values.last) const Divider(height: 1),
                ],
              ],
            ),
          ),
        ),
        if (armesRetard.isNotEmpty) ...[
          const SizedBox(height: 28),
          SectionHeader(title: 'Inspections en retard (${armesRetard.length})'),
          for (final a in armesRetard)
            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.danger,
                ),
                title: Text('${a.type} — ${a.modele}'),
                subtitle: Text('N° série ${a.numeroSerie}'),
              ),
            ),
        ],
      ],
    );
  }
}
