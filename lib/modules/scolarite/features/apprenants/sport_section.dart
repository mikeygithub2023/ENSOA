import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sig_ensoa/core/erreurs.dart';
import 'package:sig_ensoa/core/theme.dart' hide AlertLevel, AlertLevelColor;
import '../../models/classe.dart';
import '../../models/controle.dart';
import '../../models/sous_module.dart';
import '../../shared/widgets/common.dart';
import 'providers/apprenants_providers.dart';
import 'providers/controles_providers.dart';
import 'providers/sport_providers.dart';
import 'seance_sportive_dialog.dart';

/// La rubrique Sport d'une phase : ses séances, la plus récente en tête.
///
/// Le module Sport existe d'office (migration 056) et ne se crée ni ne se
/// supprime — seul son coefficient dans la moyenne de la phase se règle.
/// Ce qu'on y ajoute, ce sont des séances : une activité du catalogue,
/// passée un jour donné. Toutes pèsent le même poids, la note du module est
/// donc la moyenne simple des séances où l'apprenant est classé.
class SportSection extends ConsumerWidget {
  const SportSection({
    super.key,
    required this.classe,
    required this.moduleSport,
  });

  final Classe classe;
  final Controle moduleSport;

  Future<void> _supprimerSeance(
    BuildContext context,
    WidgetRef ref,
    SousModule sousModule,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Supprimer la séance'),
        content: Text(
          'Voulez-vous vraiment supprimer « ${sousModule.nom} » ? Les '
          'performances saisies et les notes qu\'elles ont produites '
          'partent avec elle, et la note du module Sport est recalculée '
          'sans cette séance.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Supprimer',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (confirme != true) return;
    try {
      await ref.read(sportRepositoryProvider).deleteSeance(sousModule.id);
      ref.invalidate(seancesSportivesProvider(moduleSport.id));
      ref.invalidate(notesByControleProvider(moduleSport.id));
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Séance supprimée.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Erreur : ${messageErreur(e)}'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seancesAsync = ref.watch(seancesSportivesProvider(moduleSport.id));
    final activites =
        ref.watch(activitesSportivesProvider).value ??
        const <ActiviteSportive>[];
    final activitesById = {for (final a in activites) a.id: a};
    final apprenants =
        ref.watch(apprenantsByClasseProvider(classe.id)).value ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: SectionHeader(title: 'Sport')),
            StatusChip(
              label: 'Coefficient ${_format(moduleSport.coefficient)}',
              level: AlertLevel.info,
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: () =>
                  showSeanceDialog(context, moduleSportId: moduleSport.id),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Programmer une séance'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Chaque séance fait passer une activité du catalogue. La '
          'performance saisie devient une note par lecture du barème ; la '
          'note du module Sport est la moyenne des séances.',
          style: TextStyle(color: AppColors.inkMuted, fontSize: 13),
        ),
        const SizedBox(height: 12),
        seancesAsync.when(
          data: (seances) {
            if (seances.isEmpty) {
              return const EmptyState(
                message:
                    'Aucune séance programmée.\nProgrammez-en une pour '
                    'commencer à noter le sport de cette phase.',
                icon: Icons.directions_run_outlined,
              );
            }
            return Column(
              children: [
                for (final entree in seances) ...[
                  _SeanceTile(
                    key: ValueKey(entree.sousModule.id),
                    sousModule: entree.sousModule,
                    seance: entree.seance,
                    activite: activitesById[entree.seance.activiteId],
                    onOuvrir: () {
                      final activite = activitesById[entree.seance.activiteId];
                      if (activite == null) return;
                      showFeuilleSeanceDialog(
                        context,
                        sousModule: entree.sousModule,
                        activite: activite,
                        seance: entree.seance,
                        apprenants: apprenants,
                      );
                    },
                    onModifier: () => showSeanceDialog(
                      context,
                      moduleSportId: moduleSport.id,
                      existing: entree,
                    ),
                    onSupprimer: () =>
                        _supprimerSeance(context, ref, entree.sousModule),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => EmptyState(
            message: 'Erreur de chargement : ${messageErreur(error)}',
            icon: Icons.error_outline,
          ),
        ),
      ],
    );
  }
}

String _format(num value) =>
    value == value.roundToDouble() ? value.toStringAsFixed(0) : '$value';

class _SeanceTile extends StatelessWidget {
  const _SeanceTile({
    super.key,
    required this.sousModule,
    required this.seance,
    required this.activite,
    required this.onOuvrir,
    required this.onModifier,
    required this.onSupprimer,
  });

  final SousModule sousModule;
  final SeanceSportive seance;
  final ActiviteSportive? activite;
  final VoidCallback onOuvrir;
  final VoidCallback onModifier;
  final VoidCallback onSupprimer;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.blueMist,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: activite == null ? null : onOuvrir,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            children: [
              const Icon(
                Icons.directions_run_outlined,
                color: AppColors.blueDeep,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sousModule.nom,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${activite?.nom ?? "Activité introuvable"} · '
                      '${formatJour(seance.dateSeance)}',
                      style: const TextStyle(
                        color: AppColors.inkMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                tooltip: 'Modifier la séance',
                onPressed: onModifier,
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: AppColors.danger,
                ),
                tooltip: 'Supprimer',
                onPressed: onSupprimer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
