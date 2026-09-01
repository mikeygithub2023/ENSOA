import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sig_ensoa/core/theme.dart';
import 'package:sig_ensoa/core/chargement.dart';
import '../../data/models/oa.dart';
import '../../data/repositories/oa_providers.dart';
import '../../shared/widgets/dashboard_widgets.dart';
import '../../shared/widgets/skeleton.dart';
import '../../shared/widgets/widgets.dart';

class StatistiquesTabContent extends ConsumerWidget {
  const StatistiquesTabContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final charge = estCharge(ref, ['taches', 'activites']);
    final activites = ref.watch(activitesProvider);
    final taches = ref.watch(tachesProvider);

    if (!charge) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(4, 4, 4, 100),
        child: SkeletonGrid(
          itemCount: 4,
          maxCrossAxisExtent: 240,
          mainAxisExtent: 140,
        ),
      );
    }

    final validees = taches
        .where((t) => t.statut == StatutTache.validee)
        .length;
    final enAttente = taches
        .where((t) => t.statut == StatutTache.terminee)
        .length;
    final enRetard = taches.where((t) => t.enRetard).length;
    final tauxValidation = taches.isEmpty ? 0.0 : validees / taches.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 100),
      children: [
        SectionHeader(title: 'Vue d\'ensemble'),
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'Activités',
                value: '${activites.length}',
                icon: Icons.event_note_outlined,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: StatCard(
                label: 'Tâches assignées',
                value: '${taches.length}',
                icon: Icons.assignment_outlined,
                color: AppColors.blue,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: StatCard(
                label: 'En attente de validation',
                value: '$enAttente',
                icon: Icons.hourglass_top_outlined,
                color: AppColors.warning,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: StatCard(
                label: 'Tâches en retard',
                value: '$enRetard',
                icon: Icons.error_outline,
                color: AppColors.danger,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        GaugeCard(
          title: 'Taux de validation global',
          subtitle: 'Tâches validées sur l\'ensemble des tâches assignées',
          progress: tauxValidation,
          centerValue: '${(tauxValidation * 100).toStringAsFixed(0)}%',
          centerLabel: '$validees/${taches.length}',
          color: AppColors.success,
        ),
        const SizedBox(height: 24),
        const SectionHeader(title: 'Avancement par acteur'),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                for (final a in ActeurTache.values) ...[
                  Builder(
                    builder: (context) {
                      final tachesActeur = taches
                          .where((t) => t.acteur == a)
                          .toList();
                      final valideesActeur = tachesActeur
                          .where((t) => t.statut == StatutTache.validee)
                          .length;
                      return DotProgressRow(
                        icon: Icons.groups_outlined,
                        iconColor: AppColors.blueDeep,
                        title: a.label,
                        subtitle: 'Tâches validées',
                        completed: valideesActeur,
                        total: tachesActeur.length,
                      );
                    },
                  ),
                  if (a != ActeurTache.values.last) const Divider(height: 1),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
