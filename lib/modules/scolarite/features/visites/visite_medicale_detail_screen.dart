import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:sig_ensoa/core/erreurs.dart';
import 'package:sig_ensoa/core/theme.dart' hide AlertLevel, AlertLevelColor;
import '../../models/apprenant.dart';
import '../../models/classe.dart';
import '../../models/visite_medicale.dart';
import '../../shared/widgets/common.dart';
import '../apprenants/providers/apprenants_providers.dart';
import '../matieres/providers/matieres_providers.dart';
import 'providers/visites_medicales_providers.dart';
import 'register_visite_apprenant_dialog.dart';
import 'register_visite_medicale_dialog.dart';
import 'visite_apprenant_details_dialog.dart';

final _dateFmt = DateFormat('dd/MM/yyyy');

/// Fiche d'une visite médicale : son entête (titre, classe/stage, date,
/// type) puis la liste des apprenants qui l'ont passée, chacun avec le
/// résumé de son examen, un accès à ses détails et de quoi le corriger.
class VisiteMedicaleDetailScreen extends ConsumerWidget {
  const VisiteMedicaleDetailScreen({super.key, required this.visiteId});

  final String visiteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visiteAsync = ref.watch(visiteMedicaleByIdProvider(visiteId));

    return visiteAsync.when(
      data: (visite) {
        if (visite == null) {
          return const EmptyState(
            message: 'Visite médicale introuvable.',
            icon: Icons.event_available_outlined,
          );
        }
        return _VisiteMedicaleDetailView(visite: visite);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => EmptyState(
        message: 'Erreur de chargement : ${messageErreur(error)}',
        icon: Icons.error_outline,
      ),
    );
  }
}

class _VisiteMedicaleDetailView extends ConsumerWidget {
  const _VisiteMedicaleDetailView({required this.visite});

  final VisiteMedicale visite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final examensAsync = ref.watch(visiteApprenantsProvider(visite.id));
    final apprenantsAsync = ref.watch(
      apprenantsByClasseProvider(visite.classeId),
    );
    final classes = ref.watch(classesListProvider).value ?? const <Classe>[];
    final classe = classes.where((c) => c.id == visite.classeId).firstOrNull;
    final apprenants = apprenantsAsync.value ?? const <Apprenant>[];
    final apprenantsById = {for (final a in apprenants) a.id: a};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Retour',
              onPressed: () => context.canPop()
                  ? context.pop()
                  : context.go('/scolarite/visites-medicales'),
            ),
            const SizedBox(width: 8),
            const CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.blueMist,
              child: Icon(
                Icons.event_available_outlined,
                color: AppColors.blueDeep,
                size: 26,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    visite.titre,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${visite.type.label} · '
                    '${classe != null ? '${classe.nom} (${classe.type.label}) · ' : ''}'
                    '${_dateFmt.format(visite.dateVisite)}',
                    style: const TextStyle(
                      color: AppColors.inkMuted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Modifier la visite',
              onPressed: () => showRegisterVisiteMedicaleDialog(
                context,
                classes: classes,
                visite: visite,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        examensAsync.when(
          data: (examens) {
            // On ne propose que les apprenants de la classe/stage convoquée
            // qui ne sont pas encore passés : un apprenant ne peut figurer
            // qu'une fois dans une même visite.
            final dejaPasses = {for (final e in examens) e.apprenantId};
            final candidats = apprenants
                .where((a) => !dejaPasses.contains(a.id))
                .toList();
            return Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: SectionHeader(
                          title: 'Apprenants passés (${examens.length})',
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: candidats.isEmpty
                            ? null
                            : () => showRegisterVisiteApprenantDialog(
                                context,
                                visiteId: visite.id,
                                apprenants: candidats,
                              ),
                        icon: const Icon(Icons.person_add_alt, size: 18),
                        label: const Text('Ajouter un apprenant'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: examens.isEmpty
                        ? const EmptyState(
                            message:
                                'Aucun apprenant n\'a encore passé cette visite.',
                            icon: Icons.groups_outlined,
                          )
                        : ListView.separated(
                            itemCount: examens.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final examen = examens[index];
                              final apprenant =
                                  apprenantsById[examen.apprenantId];
                              return _ExamenTile(
                                examen: examen,
                                apprenant: apprenant,
                                onDetails: () =>
                                    showVisiteApprenantDetailsDialog(
                                      context,
                                      examen: examen,
                                      apprenant: apprenant,
                                    ),
                                onEdit: () => showRegisterVisiteApprenantDialog(
                                  context,
                                  visiteId: visite.id,
                                  apprenants: apprenants,
                                  examen: examen,
                                ),
                                onDelete: () =>
                                    _confirmDelete(context, ref, examen),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
          loading: () =>
              const Expanded(child: Center(child: CircularProgressIndicator())),
          error: (error, _) => Expanded(
            child: EmptyState(
              message: 'Erreur de chargement : ${messageErreur(error)}',
              icon: Icons.error_outline,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    VisiteMedicaleApprenant examen,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Retirer l\'apprenant'),
        content: const Text(
          'Voulez-vous vraiment retirer cet apprenant de la visite ? Son examen sera supprimé.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Retirer',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(visitesMedicalesRepositoryProvider)
          .deleteApprenant(examen.id);
      ref.invalidate(visiteApprenantsProvider(visite.id));
      ref.invalidate(visitesEffectifsProvider);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Apprenant retiré de la visite.'),
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
}

/// Résumé de l'examen affiché sous le nom — les valeurs du cachet les plus
/// parlantes d'un coup d'œil, le détail restant derrière le bouton
/// « Détails ».
String? _resumeExamen(VisiteMedicaleApprenant examen) {
  final parts = [
    if (examen.tailleCm != null) '${examen.tailleCm} cm',
    if (examen.poidsKg != null) '${examen.poidsKg} kg',
    if (examen.pignet != null) 'Pignet ${examen.pignet}',
    if (examen.tensionArterielle != null) 'T.A ${examen.tensionArterielle}',
    if (examen.pouls != null) 'Pouls ${examen.pouls}',
    if (examen.sigycopProfil != null) 'SIGYCOP ${examen.sigycopProfil}',
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

class _ExamenTile extends StatelessWidget {
  const _ExamenTile({
    required this.examen,
    required this.apprenant,
    required this.onDetails,
    required this.onEdit,
    required this.onDelete,
  });

  final VisiteMedicaleApprenant examen;
  final Apprenant? apprenant;
  final VoidCallback onDetails;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final level = switch (examen.resultat) {
      VisiteResultat.apte => AlertLevel.success,
      VisiteResultat.aRevoir => AlertLevel.info,
      VisiteResultat.inapteTemporaire => AlertLevel.warning,
      VisiteResultat.inapteDefinitif => AlertLevel.critical,
    };
    final resume = _resumeExamen(examen);

    return Material(
      color: AppColors.blueMist,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    apprenant?.nomComplet ?? 'Apprenant inconnu',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (resume != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      resume,
                      style: const TextStyle(
                        color: AppColors.inkMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 16),
            StatusChip(label: examen.resultat.label, level: level),
            const SizedBox(width: 8),
            OutlinedButton(onPressed: onDetails, child: const Text('Détails')),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              tooltip: 'Modifier l\'examen',
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(
                Icons.delete_outline,
                size: 20,
                color: AppColors.danger,
              ),
              tooltip: 'Retirer de la visite',
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
