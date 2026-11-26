// L'onglet « Dossier pension » : où en est chacun.
//
// Les autres registres de ce bureau listent des faits — une absence, une
// permission, un séjour aux arrêts. Celui-ci liste des gens, parce que la
// question qu'il sert à poser n'est pas « qu'est-il arrivé ? » mais
// « lesquels sont prêts ? ».
//
// L'ORDRE N'EST PAS ALPHABÉTIQUE. Il suit la date de retraite : celui qui
// part dans six mois passe devant celui qui part dans douze ans, parce que
// c'est son dossier qu'il faut avoir réuni. Ceux dont la date de retraite
// n'est pas connue ferment la liste — l'ignorance n'est pas une urgence.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:sig_ensoa/core/erreurs.dart';
import 'package:sig_ensoa/core/theme.dart' hide AlertLevel, AlertLevelColor;
import 'package:sig_ensoa/modules/scolarite/compat.dart';
import '../../models/apprenant.dart';
import '../../models/classe.dart';
import '../../models/division.dart';
import '../../models/pension.dart';
import '../../shared/widgets/common.dart';
import 'catalogues_rh_dialog.dart';
import 'pension_bilan.dart';
import 'portee_promotion.dart';
import 'providers/apprenants_providers.dart';
import 'providers/pension_providers.dart';
import 'verifier_dossier_pension_dialog.dart';

class DossierPensionTabView extends ConsumerWidget {
  const DossierPensionTabView({
    super.key,
    required this.division,
    required this.classe,
    this.classesRetenues,
    this.apprenantsRetenus,
  });

  /// Nulle sous « Toutes » : la vue cumule alors ce que l'utilisateur a le
  /// droit de voir, divisions confondues.
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

    final piecesAsync = ref.watch(piecesPensionProvider);
    final lignesAsync = ref.watch(lignesPensionProvider);
    final profil = ref.watch(currentProfileProvider).value;
    final estAdmin = profil?.role == AppRole.admin;

    // Écrire relève de l'administrateur et du chef de division — c'est ce
    // que dit la base. L'écran s'aligne plutôt que de proposer un geste
    // que la RLS refusera.
    final peutEcrire = estAdmin || profil?.role == AppRole.chefDivision;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: SectionHeader(title: 'Dossier pension')),
            if (estAdmin)
              OutlinedButton.icon(
                onPressed: () => showPiecesPensionDialog(context),
                icon: const Icon(Icons.playlist_add, size: 18),
                label: const Text('Pièces du dossier'),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: apprenantsAsync.when(
            data: (apprenants) {
              if (apprenants.isEmpty) {
                return const EmptyState(
                  message: 'Aucun militaire dans cette liste.',
                  icon: Icons.folder_shared_outlined,
                );
              }
              final pieces = piecesAsync.value ?? const <PiecePension>[];
              final lignes = lignesAsync.value ?? const <LignePension>[];
              final lignesParApprenant = <String, List<LignePension>>{};
              for (final l in lignes) {
                lignesParApprenant.putIfAbsent(l.apprenantId, () => []).add(l);
              }

              final ranges = [...apprenants]
                ..sort(
                  (a, b) =>
                      compareUrgenceRetraite(a.dateRetraite, b.dateRetraite),
                );

              final bilans = {
                for (final a in ranges)
                  a.id: bilanDuDossier(
                    pieces: piecesPour(
                      pieces,
                      situationMatrimoniale: a.situationMatrimoniale,
                      nombreEnfants: a.nombreEnfants,
                    ),
                    lignes: lignesParApprenant[a.id] ?? const [],
                  ),
              };

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Entete(bilans: bilans.values.toList(), pieces: pieces),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      itemCount: ranges.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final a = ranges[i];
                        return _DossierTile(
                          apprenant: a,
                          bilan: bilans[a.id]!,
                          onOuvrir: () => showVerifierDossierPensionDialog(
                            context,
                            apprenant: a,
                            peutEcrire: peutEcrire,
                          ),
                        );
                      },
                    ),
                  ),
                ],
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
}

/// Le compte d'un coup d'œil : combien de dossiers prêts, combien restent.
class _Entete extends StatelessWidget {
  const _Entete({required this.bilans, required this.pieces});

  final List<BilanDossierPension> bilans;
  final List<PiecePension> pieces;

  @override
  Widget build(BuildContext context) {
    if (pieces.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.blueMist.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: const Text(
          'Aucune pièce au catalogue : il n\'y a rien à vérifier. La liste '
          'des pièces exigées par la Direction des Ressources Humaines se '
          'saisit une fois, par l\'administrateur, et sert à tous les '
          'dossiers.',
          style: TextStyle(color: AppColors.inkMuted, fontSize: 13),
        ),
      );
    }
    final complets = bilans.where((b) => b.etat == EtatDossier.complet).length;
    final incomplets = bilans
        .where((b) => b.etat == EtatDossier.incomplet)
        .length;
    final nonVerifies = bilans
        .where((b) => b.etat == EtatDossier.nonVerifie)
        .length;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        StatusChip(label: '$complets complet(s)', level: AlertLevel.success),
        StatusChip(label: '$incomplets à réunir', level: AlertLevel.critical),
        StatusChip(
          label: '$nonVerifies non vérifié(s)',
          level: AlertLevel.warning,
        ),
        StatusChip(
          label: '${pieces.length} pièce(s) au catalogue',
          level: AlertLevel.info,
        ),
      ],
    );
  }
}

class _DossierTile extends StatelessWidget {
  const _DossierTile({
    required this.apprenant,
    required this.bilan,
    required this.onOuvrir,
  });

  final Apprenant apprenant;
  final BilanDossierPension bilan;
  final VoidCallback onOuvrir;

  @override
  Widget build(BuildContext context) {
    final grade = apprenant.grade;
    final retraite = apprenant.dateRetraite;
    return Card(
      child: ListTile(
        onTap: onOuvrir,
        leading: const Icon(
          Icons.folder_shared_outlined,
          color: AppColors.blueDeep,
        ),
        title: Text(
          grade == null
              ? apprenant.nomComplet
              : '$grade ${apprenant.nomComplet}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          [
            apprenant.matricule ?? 'Sans matricule',
            retraite == null
                ? 'Retraite non renseignée'
                : 'Retraite le ${DateFormat('dd/MM/yyyy').format(retraite)}',
            if (bilan.verifiees > 0) '${bilan.verifiees} pièce(s) vérifiée(s)',
          ].join(' · '),
          style: const TextStyle(fontSize: 12),
        ),
        trailing: StatusChip(
          label: bilan.libelle,
          level: switch (bilan.etat) {
            EtatDossier.complet => AlertLevel.success,
            EtatDossier.incomplet => AlertLevel.critical,
            EtatDossier.nonVerifie => AlertLevel.warning,
            EtatDossier.sansCatalogue => AlertLevel.info,
          },
        ),
      ),
    );
  }
}
