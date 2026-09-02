import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:sig_ensoa/core/theme.dart';
import 'package:sig_ensoa/core/chargement.dart';
import '../../data/models/oa.dart';
import '../../data/repositories/oa_providers.dart';
import '../../shared/widgets/dashboard_widgets.dart';
import '../../shared/widgets/skeleton.dart';
import '../../shared/widgets/widgets.dart';

/// Vue d'ensemble, en lecture seule, des tâches confiées par l'Officier
/// Adjoint aux subordonnés du Chef Soutien Technique (Soutien pétrolier,
/// Garage, Armurerie) — permet de suivre leur évolution sans pouvoir agir
/// dessus (ni marquer terminée, ni valider : ça reste le rôle de l'acteur et
/// de l'OA respectivement).
class TachesEquipeScreen extends ConsumerWidget {
  const TachesEquipeScreen({super.key});

  // Tous les acteurs que l'officier adjoint peut solliciter — le service de
  // santé compris : il reçoit des tâches comme les autres.
  static const _acteursSuivis = ActeurTache.values;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final charge = estCharge(ref, ['taches', 'activites']);
    final taches = ref
        .watch(tachesProvider)
        .where((t) => _acteursSuivis.contains(t.acteur))
        .toList();
    final activites = ref.watch(activitesProvider);
    final df = DateFormat('dd/MM/yyyy HH:mm');

    String activiteTitre(String id) {
      for (final a in activites) {
        if (a.id == id) return a.titre;
      }
      return 'Activité inconnue';
    }

    AlertLevel level(TacheActivite t) {
      if (t.enRetard) return AlertLevel.critical;
      switch (t.statut) {
        case StatutTache.aFaire:
          return AlertLevel.warning;
        case StatutTache.terminee:
        case StatutTache.validee:
          return AlertLevel.info;
        case StatutTache.annulee:
          return AlertLevel.info;
      }
    }

    return ScreenScaffold(
      title: 'Tâches de l\'équipe',
      children: [
        if (!charge) const SkeletonList(itemCount: 3),
        if (charge) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  for (final a in _acteursSuivis) ...[
                    Builder(
                      builder: (context) {
                        final tachesActeur = taches
                            .where((t) => t.acteur == a)
                            .toList();
                        final validees = tachesActeur
                            .where((t) => t.statut == StatutTache.validee)
                            .length;
                        return DotProgressRow(
                          icon: Icons.groups_outlined,
                          iconColor: AppColors.blueDeep,
                          title: a.label,
                          subtitle: 'Tâches validées',
                          completed: validees,
                          total: tachesActeur.length,
                        );
                      },
                    ),
                    if (a != _acteursSuivis.last) const Divider(height: 1),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          SectionHeader(title: 'Détail des tâches (${taches.length})'),
          if (taches.isEmpty)
            const EmptyState(
              message: 'Aucune tâche assignée à l\'équipe pour le moment',
            ),
          for (final t in taches) ...[
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: level(
                    t,
                  ).color(context).withValues(alpha: 0.12),
                  child: Icon(
                    Icons.assignment_outlined,
                    color: level(t).color(context),
                  ),
                ),
                title: Text(t.description),
                subtitle: Text(
                  '${activiteTitre(t.activiteId)} · ${t.acteur.label}'
                  '${t.dateLimite != null ? ' · Échéance ${df.format(t.dateLimite!)}' : ''}'
                  '${t.enRetard ? ' · EN RETARD' : ''}',
                ),
                trailing: StatusChip(label: t.statut.label, level: level(t)),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ],
    );
  }
}
