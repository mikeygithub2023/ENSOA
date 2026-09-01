import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:sig_ensoa/core/theme.dart';
import 'package:sig_ensoa/core/chargement.dart';
import '../../data/models/oa.dart';
import '../../data/repositories/oa_providers.dart';
import '../../shared/widgets/skeleton.dart';
import '../../shared/widgets/widgets.dart';
import 'tache_form_dialog.dart';

class ActiviteDetailScreen extends ConsumerWidget {
  final Activite activite;
  const ActiviteDetailScreen({super.key, required this.activite});

  /// Une tâche assignée par erreur se retire ; une tâche déjà faite se
  /// valide, elle ne s'efface pas — c'est la trace du travail accompli. D'où
  /// la confirmation, qui le rappelle.
  Future<void> _confirmerSuppression(
    BuildContext context,
    WidgetRef ref,
    TacheActivite tache,
  ) async {
    final messager = ScaffoldMessenger.of(context);
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Supprimer la tâche'),
        content: Text(
          '« ${tache.description} » sera retirée de l\'activité. '
          "Si elle a déjà été faite, préférez la valider : la supprimer "
          "effacerait la trace du travail accompli.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirme != true) return;

    try {
      await ref.read(tachesProvider.notifier).supprimer(tache.id);
    } catch (e) {
      messager.showSnackBar(
        SnackBar(content: Text('Suppression impossible : $e')),
      );
    }
  }

  AlertLevel _levelPourTache(TacheActivite t) {
    if (t.enRetard) return AlertLevel.critical;
    switch (t.statut) {
      case StatutTache.aFaire:
        return AlertLevel.warning;
      case StatutTache.terminee:
        return AlertLevel.info;
      case StatutTache.validee:
        return AlertLevel.info;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activites = ref.watch(activitesProvider);
    final current = activites.firstWhere(
      (a) => a.id == activite.id,
      orElse: () => activite,
    );
    final taches = ref
        .watch(tachesProvider)
        .where((t) => t.activiteId == current.id)
        .toList();
    final charge = estCharge(ref, ['activites', 'taches']);
    final df = DateFormat('dd/MM/yyyy HH:mm');

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => context.go('/logistique/activites'),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        current.titre,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    StatusChip(
                      label: current.statut.label,
                      level: AlertLevel.info,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _infoTile(
                      context,
                      Icons.event_outlined,
                      'Date',
                      df.format(current.dateActivite),
                    ),
                    if (current.lieu != null)
                      _infoTile(
                        context,
                        Icons.place_outlined,
                        'Lieu',
                        current.lieu!,
                      ),
                  ],
                ),
                if (current.description != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    current.description!,
                    style: const TextStyle(color: AppColors.inkMuted),
                  ),
                ],
                const SizedBox(height: 20),
                Wrap(
                  spacing: 10,
                  children: [
                    if (current.statut != StatutActivite.terminee &&
                        current.statut != StatutActivite.annulee) ...[
                      OutlinedButton(
                        onPressed: () => ref
                            .read(activitesProvider.notifier)
                            .changerStatut(current.id, StatutActivite.terminee),
                        child: const Text('Marquer terminée'),
                      ),
                      OutlinedButton(
                        onPressed: () => ref
                            .read(activitesProvider.notifier)
                            .changerStatut(current.id, StatutActivite.annulee),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.danger),
                          foregroundColor: AppColors.danger,
                        ),
                        child: const Text('Annuler l\'activité'),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 32),
                SectionHeader(
                  title: 'Tâches assignées (${charge ? taches.length : '…'})',
                  // Le bouton était en flottant par-dessus la liste : il en
                  // masquait la dernière ligne. Il tient sa place ici, à
                  // hauteur du titre, avant la liste.
                  action: FilledButton.icon(
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => TacheFormDialog(activite: current),
                    ),
                    icon: const Icon(Icons.add_task_outlined, size: 18),
                    label: const Text('Assigner une tâche'),
                  ),
                ),
                if (!charge) const SkeletonList(itemCount: 2),
                if (charge && taches.isEmpty)
                  const EmptyState(
                    message: 'Aucune tâche assignée pour le moment',
                  ),
                if (charge)
                  for (final t in taches) ...[
                    Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _levelPourTache(
                            t,
                          ).color(context).withValues(alpha: 0.12),
                          child: Icon(
                            Icons.assignment_outlined,
                            color: _levelPourTache(t).color(context),
                          ),
                        ),
                        title: Text(t.description),
                        subtitle: Text(
                          '${t.acteur.label}'
                          '${t.dateLimite != null ? ' · Échéance ${df.format(t.dateLimite!)}' : ''}'
                          '${t.enRetard ? ' · EN RETARD' : ''}'
                          '${t.commentaire != null ? '\n${t.commentaire}' : ''}',
                        ),
                        isThreeLine: t.commentaire != null,
                        trailing: Wrap(
                          spacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            StatusChip(
                              label: t.statut.label,
                              level: _levelPourTache(t),
                            ),
                            IconButton(
                              tooltip: 'Modifier',
                              onPressed: () => showDialog(
                                context: context,
                                builder: (_) => TacheFormDialog(
                                  activite: current,
                                  tache: t,
                                ),
                              ),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              tooltip: 'Supprimer',
                              onPressed: () => _confirmerSuppression(
                                context,
                                ref,
                                t,
                              ),
                              icon: const Icon(
                                Icons.delete_outline,
                                color: AppColors.danger,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Sans cet écart, les cartes se collent et la liste se lit
                    // comme un bloc.
                    const SizedBox(height: 12),
                  ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoTile(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
