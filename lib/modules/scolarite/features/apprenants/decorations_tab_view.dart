// L'onglet « Décorations » : le registre des attributions.
//
// Celui-ci liste bien des faits, comme les absences et les permissions —
// telle décoration, à tel homme, à telle date. Les plus récentes d'abord ;
// celles dont la date ne se retrouve pas ferment la liste plutôt que de
// l'ouvrir, où elles passeraient pour les plus anciennes alors qu'on n'en
// sait rien.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:sig_ensoa/core/erreurs.dart';
import 'package:sig_ensoa/core/theme.dart' hide AlertLevel, AlertLevelColor;
import 'package:sig_ensoa/modules/scolarite/compat.dart';
import '../../models/apprenant.dart';
import '../../models/classe.dart';
import '../../models/decoration.dart';
import '../../models/division.dart';
import '../../shared/widgets/common.dart';
import 'catalogues_rh_dialog.dart';
import 'portee_promotion.dart';
import 'providers/apprenants_providers.dart';
import 'providers/decorations_providers.dart';
import 'register_decoration_dialog.dart';

class DecorationsTabView extends ConsumerWidget {
  const DecorationsTabView({
    super.key,
    required this.division,
    required this.classe,
    this.classesRetenues,
    this.apprenantsRetenus,
  });

  final Division? division;
  final Classe? classe;
  final Set<String>? classesRetenues;
  final Set<String>? apprenantsRetenus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classe = this.classe;
    final portee = classe == null ? classesRetenues : null;
    final division = this.division;

    final apprenantsAsync =
        (classe != null
                ? ref.watch(apprenantsByClasseProvider(classe.id))
                : division != null
                ? ref.watch(apprenantsByDivisionProvider(division.id))
                : ref.watch(apprenantsListProvider))
            .dansLesClasses(portee, (a) => a.classeId)
            .pourLesApprenants(apprenantsRetenus, (a) => a.id);

    final recuesAsync = ref.watch(decorationsRecuesProvider);
    final catalogueAsync = ref.watch(catalogueDecorationsProvider);
    final profil = ref.watch(currentProfileProvider).value;
    final estAdmin = profil?.role == AppRole.admin;
    final peutEcrire = estAdmin || profil?.role == AppRole.chefDivision;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: SectionHeader(title: 'Décorations')),
            if (estAdmin) ...[
              OutlinedButton.icon(
                onPressed: () => showCatalogueDecorationsDialog(context),
                icon: const Icon(Icons.playlist_add, size: 18),
                label: const Text('Catalogue'),
              ),
              const SizedBox(width: 12),
            ],
            if (peutEcrire)
              FilledButton.icon(
                onPressed: apprenantsAsync.maybeWhen(
                  data: (apprenants) => apprenants.isEmpty
                      ? null
                      : () => showRegisterDecorationDialog(
                          context,
                          apprenants: apprenants,
                        ),
                  orElse: () => null,
                ),
                icon: const Icon(Icons.military_tech_outlined, size: 18),
                label: const Text('Inscrire une décoration'),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: apprenantsAsync.when(
            data: (apprenants) {
              final parId = {for (final a in apprenants) a.id: a};
              final catalogue = {
                for (final d
                    in catalogueAsync.value ?? const <TypeDecoration>[])
                  d.id: d,
              };
              return recuesAsync.when(
                data: (toutes) {
                  // La RLS rend tout ce que l'agent peut voir ; l'onglet
                  // s'en tient à la portée affichée.
                  final recues = toutes
                      .where((r) => parId.containsKey(r.apprenantId))
                      .toList();
                  if (recues.isEmpty) {
                    return const EmptyState(
                      message: 'Aucune décoration inscrite dans cette liste.',
                      icon: Icons.military_tech_outlined,
                    );
                  }
                  return ListView.separated(
                    itemCount: recues.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final r = recues[i];
                      return _DecorationTile(
                        recue: r,
                        apprenant: parId[r.apprenantId],
                        libelle: catalogue[r.decorationId]?.libelle,
                        onModifier: peutEcrire
                            ? () => showRegisterDecorationDialog(
                                context,
                                apprenants: apprenants,
                                existante: r,
                              )
                            : null,
                        onSupprimer: peutEcrire
                            ? () => _confirmerSuppression(context, ref, r)
                            : null,
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Text(
                    'Le registre n\'a pas pu être lu : ${messageErreur(e)}',
                    style: const TextStyle(color: AppColors.danger),
                  ),
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text(
                'L\'effectif n\'a pas pu être lu : ${messageErreur(e)}',
                style: const TextStyle(color: AppColors.danger),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmerSuppression(
    BuildContext context,
    WidgetRef ref,
    DecorationRecue recue,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Retirer cette décoration'),
        content: const Text(
          'L\'inscription sera effacée du registre. À ne faire que si elle '
          'a été portée par erreur — une décoration retirée par décision '
          'se corrige plutôt en observation.',
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
    if (confirme != true) return;
    try {
      await ref.read(decorationsRepositoryProvider).supprimer(recue.id);
      ref.invalidate(decorationsRecuesProvider);
      ref.invalidate(decorationsRecuesByApprenantProvider(recue.apprenantId));
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Décoration retirée du registre.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Retrait refusé : ${messageErreur(e)}'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }
}

class _DecorationTile extends StatelessWidget {
  const _DecorationTile({
    required this.recue,
    required this.apprenant,
    required this.libelle,
    this.onModifier,
    this.onSupprimer,
  });

  final DecorationRecue recue;
  final Apprenant? apprenant;
  final String? libelle;
  final VoidCallback? onModifier;
  final VoidCallback? onSupprimer;

  @override
  Widget build(BuildContext context) {
    final a = apprenant;
    final grade = a?.grade;
    final nom = a == null
        ? 'Militaire inconnu'
        : (grade == null ? a.nomComplet : '$grade ${a.nomComplet}');
    final date = recue.dateAttribution;
    final details = [
      if (date != null)
        'Le ${DateFormat('dd/MM/yyyy').format(date)}'
      else
        'Date non renseignée',
      if (recue.echelon != null && recue.echelon!.trim().isNotEmpty)
        recue.echelon!.trim(),
      if (recue.reference != null && recue.reference!.trim().isNotEmpty)
        recue.reference!.trim(),
    ].join(' · ');

    return Card(
      child: ListTile(
        leading: const Icon(
          Icons.military_tech_outlined,
          color: AppColors.blueDeep,
        ),
        title: Text(
          libelle ?? 'Décoration retirée du catalogue',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(nom, style: const TextStyle(fontSize: 12)),
            Text(
              details,
              style: const TextStyle(fontSize: 12, color: AppColors.inkMuted),
            ),
            if (recue.observation != null &&
                recue.observation!.trim().isNotEmpty)
              Text(
                recue.observation!.trim(),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.inkMuted,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
        trailing: (onModifier == null && onSupprimer == null)
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onModifier != null)
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      tooltip: 'Corriger',
                      onPressed: onModifier,
                    ),
                  if (onSupprimer != null)
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: AppColors.danger,
                      ),
                      tooltip: 'Retirer',
                      onPressed: onSupprimer,
                    ),
                ],
              ),
      ),
    );
  }
}
