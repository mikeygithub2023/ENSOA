import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:sig_ensoa/modules/logistique/compat.dart';
import 'package:sig_ensoa/core/theme.dart';
import 'package:sig_ensoa/core/chargement.dart';
import '../../data/models/oa.dart';
import '../../data/repositories/misc_providers.dart';
import '../../data/repositories/oa_providers.dart';
import '../../shared/widgets/skeleton.dart';
import '../../shared/widgets/widgets.dart';

/// Écran partagé par tous les acteurs (ST, Garage, Armurerie, Santé) : les
/// tâches que leur a confiées l'Officier Adjoint sur une activité, avec la
/// possibilité de les marquer terminées (l'OA valide ensuite de son côté).
class MesTachesScreen extends ConsumerStatefulWidget {
  const MesTachesScreen({super.key});

  @override
  ConsumerState<MesTachesScreen> createState() => _MesTachesScreenState();
}

class _MesTachesScreenState extends ConsumerState<MesTachesScreen> {
  final Set<String> _enCours = {};

  AlertLevel _levelPour(TacheActivite t) {
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

  Future<void> _marquerTerminee(TacheActivite t) async {
    final commentaireCtrl = TextEditingController();
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Marquer la tâche comme terminée'),
        content: TextField(
          controller: commentaireCtrl,
          decoration: const InputDecoration(
            labelText: 'Commentaire (optionnel)',
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    if (confirme != true || !mounted) return;
    setState(() => _enCours.add(t.id));
    final user = ref.read(sessionProvider)?.user;
    try {
      await ref
          .read(tachesProvider.notifier)
          .marquerTerminee(
            t.id,
            commentaire: commentaireCtrl.text.trim().isEmpty
                ? null
                : commentaireCtrl.text.trim(),
          );
      if (user != null) {
        ref
            .read(auditProvider.notifier)
            .log(
              auteurId: user.id,
              action: 'TACHE_TERMINEE',
              cible: t.description,
            );
      }
      if (mounted) {
        showSuccessSnackBar(context, 'Tâche marquée comme terminée.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur Supabase : $e')));
      }
    } finally {
      if (mounted) setState(() => _enCours.remove(t.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final charge = estCharge(ref, ['taches', 'activites']);
    final mesTaches = List.of(ref.watch(mesTachesProvider))
      ..sort(
        (a, b) => (a.dateLimite ?? DateTime(2100)).compareTo(
          b.dateLimite ?? DateTime(2100),
        ),
      );
    final activites = ref.watch(activitesProvider);
    final df = DateFormat('dd/MM/yyyy HH:mm');

    String activiteTitre(String id) {
      for (final a in activites) {
        if (a.id == id) return a.titre;
      }
      return 'Activité inconnue';
    }

    return ScreenScaffold(
      title: 'Mes tâches',
      children: [
        if (!charge) const SkeletonList(itemCount: 3),
        if (charge && mesTaches.isEmpty)
          const EmptyState(message: 'Aucune tâche assignée pour le moment'),
        if (charge)
          for (final t in mesTaches) ...[
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _levelPour(
                    t,
                  ).color(context).withValues(alpha: 0.12),
                  child: Icon(
                    Icons.assignment_outlined,
                    color: _levelPour(t).color(context),
                  ),
                ),
                title: Text(t.description),
                subtitle: Text(
                  '${activiteTitre(t.activiteId)}'
                  '${t.dateLimite != null ? ' · Échéance ${df.format(t.dateLimite!)}' : ''}'
                  '${t.enRetard ? ' · EN RETARD' : ''}'
                  '${t.commentaire != null ? '\n${t.commentaire}' : ''}',
                ),
                isThreeLine: t.commentaire != null,
                trailing: t.statut == StatutTache.aFaire
                    ? OutlinedButton(
                        onPressed: _enCours.contains(t.id)
                            ? null
                            : () => _marquerTerminee(t),
                        child: _enCours.contains(t.id)
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Marquer terminée'),
                      )
                    : StatusChip(label: t.statut.label, level: _levelPour(t)),
              ),
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}
