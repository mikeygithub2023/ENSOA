import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:sig_ensoa/core/chargement.dart';
import 'package:sig_ensoa/core/roles.dart';
import 'package:sig_ensoa/core/theme.dart';
import 'package:sig_ensoa/features/auth/providers/auth_providers.dart';
import '../../data/models/oa.dart';
import '../../data/repositories/oa_providers.dart';
import '../../shared/widgets/skeleton.dart';
import '../../shared/widgets/widgets.dart';

/// Une activité qui compte encore : ni terminée, ni annulée.
bool activiteVivante(Activite a) =>
    a.statut == StatutActivite.planifiee || a.statut == StatutActivite.enCours;

/// Ce qu'une cellule voit : les activités ni terminées ni annulées dont la
/// date est aujourd'hui ou plus tard, de la plus proche à la plus lointaine.
/// Une activité d'aujourd'hui reste, même si son heure est passée.
List<Activite> activitesDeLaCellule(
  List<Activite> activites,
  DateTime maintenant,
) {
  final aujourdhui = DateTime(
    maintenant.year,
    maintenant.month,
    maintenant.day,
  );
  return activites.where((a) {
    final d = a.dateActivite.toLocal();
    return activiteVivante(a) &&
        !DateTime(d.year, d.month, d.day).isBefore(aujourdhui);
  }).toList()..sort((a, b) => a.dateActivite.compareTo(b.dateActivite));
}

/// Les tâches qu'une cellule a à faire dans une activité : celles confiées à
/// son service, et celles où l'on est nommément désigné. Une tâche annulée
/// n'attend plus rien.
List<TacheActivite> tachesDeLaCellule(
  List<TacheActivite> taches, {
  required String activiteId,
  ActeurTache? acteur,
  required Set<String> mesTaches,
}) => taches
    .where(
      (t) =>
          t.activiteId == activiteId &&
          t.statut != StatutTache.annulee &&
          ((acteur != null && t.acteur == acteur) || mesTaches.contains(t.id)),
    )
    .toList();

/// L'onglet « Activités » d'une cellule : les activités de l'école datées
/// d'aujourd'hui ou plus tard, par date croissante, et sous chacune ce que la
/// cellule doit y faire.
///
/// Toutes les activités paraissent, même celles où la cellule n'a rien : elle
/// sait ainsi ce qui se prépare à l'école. Celles où elle a du travail le
/// disent en tête de carte.
class ActivitesCelluleTab extends ConsumerWidget {
  const ActivitesCelluleTab({super.key, this.acteur, required this.cellule});

  /// Le service dont on montre les tâches. Nul pour une cellule qui ne reçoit
  /// pas de tâche en tant que service (le Poste de Police) : on n'y voit
  /// alors que celles où l'on est nommément désigné.
  final ActeurTache? acteur;

  /// Le nom de la cellule, tel qu'on l'écrit à l'écran.
  final String cellule;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final charge = estCharge(ref, ['activites', 'taches']);
    if (!charge) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(4, 4, 4, 100),
        child: SkeletonList(itemCount: 3),
      );
    }

    final activites = activitesDeLaCellule(
      ref.watch(activitesProvider),
      DateTime.now(),
    );
    final taches = ref.watch(tachesProvider);
    final mes = {for (final t in ref.watch(mesTachesProvider)) t.id};

    Widget carte(Activite a) => _CarteActivite(
      activite: a,
      taches: tachesDeLaCellule(
        taches,
        activiteId: a.id,
        acteur: acteur,
        mesTaches: mes,
      ),
      mesTaches: mes,
      cellule: cellule,
    );

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(activitesProvider.notifier).refresh();
        await ref.read(tachesProvider.notifier).refresh();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 100),
        children: [
          SectionHeader(title: 'Activités à venir (${activites.length})'),
          if (activites.isEmpty)
            const EmptyState(message: 'Aucune activité à venir'),
          for (final a in activites) carte(a),
        ],
      ),
    );
  }
}

class _CarteActivite extends ConsumerWidget {
  const _CarteActivite({
    required this.activite,
    required this.taches,
    required this.mesTaches,
    required this.cellule,
  });

  final Activite activite;
  final List<TacheActivite> taches;
  final Set<String> mesTaches;
  final String cellule;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final df = DateFormat('dd/MM/yyyy HH:mm');
    final aFaire = taches.where((t) => t.statut == StatutTache.aFaire).length;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => context.push(
                  '/logistique/activites/detail',
                  extra: activite,
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.blueMist,
                      child: Icon(
                        Icons.event_note_outlined,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activite.titre,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${df.format(activite.dateActivite.toLocal())}'
                            '${activite.lieu != null ? ' · ${activite.lieu}' : ''}',
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                          // Sous le titre plutôt qu'à côté : sur un téléphone,
                          // le titre garde toute la largeur.
                          const SizedBox(height: 6),
                          StatusChip(
                            label: aFaire > 0
                                ? '$aFaire à faire'
                                : taches.isEmpty
                                ? 'Rien pour $cellule'
                                : 'Tout est fait',
                            level: aFaire > 0
                                ? AlertLevel.warning
                                : AlertLevel.info,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (activite.description != null &&
                  activite.description!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  activite.description!,
                  style: const TextStyle(color: AppColors.inkMuted),
                ),
              ],
              if (taches.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Divider(height: 1),
                for (final t in taches)
                  _LigneTache(tache: t, aMoi: mesTaches.contains(t.id)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LigneTache extends ConsumerStatefulWidget {
  const _LigneTache({required this.tache, required this.aMoi});

  final TacheActivite tache;
  final bool aMoi;

  @override
  ConsumerState<_LigneTache> createState() => _LigneTacheState();
}

class _LigneTacheState extends ConsumerState<_LigneTache> {
  bool _envoi = false;

  AlertLevel get _niveau {
    final t = widget.tache;
    if (t.enRetard) return AlertLevel.critical;
    return t.statut == StatutTache.aFaire
        ? AlertLevel.warning
        : AlertLevel.info;
  }

  Future<void> _terminer() async {
    final commentaire = TextEditingController();
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Marquer la tâche comme terminée'),
        content: TextField(
          controller: commentaire,
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
    final texte = commentaire.text.trim();
    commentaire.dispose();
    if (confirme != true || !mounted) return;
    setState(() => _envoi = true);
    try {
      await ref
          .read(tachesProvider.notifier)
          .marquerTerminee(
            widget.tache.id,
            commentaire: texte.isEmpty ? null : texte,
          );
      if (mounted) showSuccessSnackBar(context, 'Tâche marquée terminée.');
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tache;
    final df = DateFormat('dd/MM/yyyy');
    // Celui à qui la tâche revient la déclare faite, et qui organise les
    // activités peut le faire pour lui. Les autres la lisent.
    final peutTerminer =
        t.statut == StatutTache.aFaire &&
        (widget.aMoi ||
            (ref
                    .watch(profilCourantProvider)
                    .value
                    ?.peut(Permission.gererActivites) ??
                false));

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              t.statut == StatutTache.aFaire
                  ? Icons.radio_button_unchecked
                  : Icons.check_circle_outline,
              size: 20,
              color: _niveau.color(context),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.description,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  [
                    t.destinataire,
                    if (t.dateLimite != null)
                      'Échéance ${df.format(t.dateLimite!.toLocal())}',
                    if (t.enRetard) 'EN RETARD',
                  ].join(' · '),
                  style: TextStyle(
                    fontSize: 12,
                    color: t.enRetard
                        ? AppColors.danger
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                if (t.commentaire != null)
                  Text(
                    t.commentaire!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: AppColors.inkMuted,
                    ),
                  ),
                // Sous la tâche plutôt qu'à côté : « En attente de
                // validation » ne tient pas en bout de ligne sur un téléphone.
                const SizedBox(height: 6),
                if (peutTerminer)
                  OutlinedButton.icon(
                    onPressed: _envoi ? null : _terminer,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Terminée'),
                  )
                else
                  StatusChip(label: t.statut.label, level: _niveau),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
