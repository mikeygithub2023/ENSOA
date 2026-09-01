import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sig_ensoa/core/erreurs.dart';
import 'package:sig_ensoa/core/theme.dart' hide AlertLevel, AlertLevelColor;
import '../../models/apprenant.dart';
import '../../models/classe.dart';
import '../../models/division.dart';
import 'package:sig_ensoa/modules/scolarite/compat.dart';
import '../../models/promotion.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/filtres_scolarite.dart';
import '../apprenants/providers/apprenants_providers.dart';
import '../matieres/providers/matieres_providers.dart';
import 'data/espaces_eleves_repository.dart';
import 'providers/admin_providers.dart';

/// Ouverture et fermeture des espaces élèves.
///
/// Un espace ne s'ouvre jamais tout seul : c'est l'administrateur qui le
/// décide, pour toute une classe/stage d'un coup ou pour quelques élèves
/// choisis. En fin de cycle, il ferme les comptes de la même façon.
///
/// L'élève se connecte avec son numéro de téléphone, qui lui sert aussi de
/// mot de passe initial. Un apprenant sans numéro ne peut donc pas avoir
/// d'espace : la liste le signale au lieu de l'ouvrir à moitié.
class EspacesElevesScreen extends ConsumerStatefulWidget {
  const EspacesElevesScreen({super.key});

  @override
  ConsumerState<EspacesElevesScreen> createState() =>
      _EspacesElevesScreenState();
}

class _EspacesElevesScreenState extends ConsumerState<EspacesElevesScreen> {
  String? _divisionFilter;
  String? _promotionFilter;
  String? _stageFilter;
  final Set<String> _selection = {};
  bool _enCours = false;

  Future<void> _agir({
    required bool creer,
    String? classeId,
    List<String>? apprenantIds,
  }) async {
    if (_enCours) return;
    setState(() => _enCours = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final repository = ref.read(espacesElevesRepositoryProvider);
      final resultats = creer
          ? await repository.creer(
              classeId: classeId,
              apprenantIds: apprenantIds,
            )
          : await repository.supprimer(
              classeId: classeId,
              apprenantIds: apprenantIds,
            );
      ref.invalidate(apprenantsListProvider);
      if (classeId != null) {
        ref.invalidate(apprenantsByClasseProvider(classeId));
      }
      ref.invalidate(profilesListProvider);
      setState(_selection.clear);
      if (!mounted) return;
      await _montrerBilan(resultats, creer: creer);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Erreur : ${messageErreur(e)}'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  /// Le bilan compte ce qui a été fait et détaille ce qui ne l'a pas été :
  /// un lot où trois élèves sur trente n'ont pas de numéro doit le dire,
  /// pas se solder par un « terminé » trompeur.
  Future<void> _montrerBilan(
    List<ResultatEspace> resultats, {
    required bool creer,
  }) {
    final traites = resultats.where((r) => r.traite).length;
    final ignores = resultats.where((r) => !r.traite).toList();

    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(creer ? 'Espaces ouverts' : 'Espaces fermés'),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$traites espace(s) ${creer ? 'ouvert(s)' : 'fermé(s)'} '
                  'sur ${resultats.length} apprenant(s).',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (ignores.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    '${ignores.length} laissé(s) de côté :',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  for (final resultat in ignores)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '${resultat.nom} — ${resultat.motif ?? 'motif inconnu'}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmerFermeture(String quoi) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Fermer les espaces élèves'),
        content: Text(
          'Voulez-vous vraiment fermer $quoi ? Les comptes seront supprimés '
          'et les élèves ne pourront plus se connecter. Leurs fiches, notes '
          'et données médicales sont conservées.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Fermer les espaces',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    return confirme == true;
  }

  @override
  Widget build(BuildContext context) {
    final divisions = ref.watch(divisionsProvider).value ?? const <Division>[];
    final classes = ref.watch(classesListProvider).value ?? const <Classe>[];

    final divisionFilter = _divisionFilter;
    final classesForDivision = divisionFilter == null
        ? const <Classe>[]
        : classes.where((c) => c.divisionId == divisionFilter).toList();

    // Un espace élève s'ouvre pour une promotion, pas pour une phase : un
    // élève entre dans la promotion et suit toutes ses phases, son compte
    // ne se rouvre pas à chaque étape. Un stage garde le sien.
    final promotionsDeLaDivision = divisionFilter == null
        ? const <Promotion>[]
        : ref.watch(promotionsParDivisionProvider(divisionFilter));
    final stagesDeLaDivision = classesForDivision
        .where((c) => c.type == ClasseType.stage)
        .toList();

    final apprenantsAsync = _promotionFilter != null
        ? ref.watch(apprenantsByPromotionProvider(_promotionFilter!))
        : _stageFilter != null
        ? ref.watch(apprenantsByClasseProvider(_stageFilter!))
        : const AsyncValue<List<Apprenant>>.data([]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _ComptesOrphelins(),
        const Text(
          'Un espace élève n\'est ouvert que par vous. L\'élève se connecte '
          'avec son numéro de téléphone, qui lui sert aussi de mot de passe '
          'à la première connexion.',
          style: TextStyle(color: AppColors.inkMuted, fontSize: 13),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final division in divisions)
              FilterChipPill(
                label: division.nom,
                selected: divisionFilter == division.id,
                onTap: () => setState(() {
                  _divisionFilter = division.id;
                  _promotionFilter = null;
                  _stageFilter = null;
                  _selection.clear();
                }),
              ),
          ],
        ),
        if (promotionsDeLaDivision.isNotEmpty ||
            stagesDeLaDivision.isNotEmpty) ...[
          const SizedBox(height: 12),
          PromotionsEtStagesFilters(
            promotions: promotionsDeLaDivision,
            stages: stagesDeLaDivision,
            avecToutes: false,
            choix: ChoixScolarite(
              promotionId: _promotionFilter,
              stageId: _stageFilter,
            ),
            onChoix: (choix) => setState(() {
              _promotionFilter = choix.promotionId;
              _stageFilter = choix.stageId;
              _selection.clear();
            }),
          ),
        ],
        const SizedBox(height: 16),
        Expanded(
          child: _promotionFilter == null && _stageFilter == null
              ? const EmptyState(
                  message:
                      'Sélectionnez une promotion ou un stage pour gérer les '
                      'espaces de ses élèves.',
                  icon: Icons.badge_outlined,
                )
              : _ListeApprenants(
                  apprenantsAsync: apprenantsAsync,
                  selection: _selection,
                  enCours: _enCours,
                  onSelection: (id, coche) => setState(() {
                    if (coche) {
                      _selection.add(id);
                    } else {
                      _selection.remove(id);
                    }
                  }),
                  // Une promotion n'est pas une classe : la fonction serveur
                  // ne sait ouvrir en lot que par classe/stage. On lui passe
                  // donc les apprenants eux-mêmes, ce qu'elle accepte aussi.
                  onOuvrirClasse: () => _agir(
                    creer: true,
                    apprenantIds: [
                      for (final a in apprenantsAsync.value ?? const []) a.id,
                    ],
                  ),
                  onFermerClasse: () async {
                    if (await _confirmerFermeture(
                      _stageFilter != null
                          ? 'tous les espaces de ce stage'
                          : 'tous les espaces de cette promotion',
                    )) {
                      await _agir(
                        creer: false,
                        apprenantIds: [
                          for (final a in apprenantsAsync.value ?? const [])
                            a.id,
                        ],
                      );
                    }
                  },
                  onOuvrirSelection: () =>
                      _agir(creer: true, apprenantIds: _selection.toList()),
                  onFermerSelection: () async {
                    if (await _confirmerFermeture(
                      'les ${_selection.length} espace(s) sélectionné(s)',
                    )) {
                      await _agir(
                        creer: false,
                        apprenantIds: _selection.toList(),
                      );
                    }
                  },
                ),
        ),
      ],
    );
  }
}

class _ListeApprenants extends ConsumerWidget {
  const _ListeApprenants({
    required this.apprenantsAsync,
    required this.selection,
    required this.enCours,
    required this.onSelection,
    required this.onOuvrirClasse,
    required this.onFermerClasse,
    required this.onOuvrirSelection,
    required this.onFermerSelection,
  });

  final AsyncValue<List<Apprenant>> apprenantsAsync;
  final Set<String> selection;
  final bool enCours;
  final void Function(String id, bool coche) onSelection;
  final VoidCallback onOuvrirClasse;
  final VoidCallback onFermerClasse;
  final VoidCallback onOuvrirSelection;
  final VoidCallback onFermerSelection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return apprenantsAsync.when(
      data: (apprenants) {
        if (apprenants.isEmpty) {
          return const EmptyState(
            message: 'Aucun apprenant dans cette promotion ou ce stage.',
            icon: Icons.groups_outlined,
          );
        }
        final ouverts = apprenants.where((a) => a.profileId != null).length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$ouverts espace(s) ouvert(s) sur ${apprenants.length} '
                    'apprenant(s)'
                    '${selection.isEmpty ? '' : ' · ${selection.length} sélectionné(s)'}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                if (selection.isEmpty) ...[
                  OutlinedButton.icon(
                    onPressed: enCours ? null : onFermerClasse,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(color: AppColors.danger),
                    ),
                    icon: const Icon(Icons.lock_outline, size: 18),
                    label: const Text('Fermer toute la classe'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: enCours ? null : onOuvrirClasse,
                    icon: const Icon(Icons.key_outlined, size: 18),
                    label: const Text('Ouvrir toute la classe'),
                  ),
                ] else ...[
                  OutlinedButton.icon(
                    onPressed: enCours ? null : onFermerSelection,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(color: AppColors.danger),
                    ),
                    icon: const Icon(Icons.lock_outline, size: 18),
                    label: const Text('Fermer la sélection'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: enCours ? null : onOuvrirSelection,
                    icon: const Icon(Icons.key_outlined, size: 18),
                    label: const Text('Ouvrir la sélection'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                itemCount: apprenants.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) => _ApprenantTile(
                  apprenant: apprenants[index],
                  coche: selection.contains(apprenants[index].id),
                  onSelection: (coche) =>
                      onSelection(apprenants[index].id, coche),
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => EmptyState(
        message: 'Erreur de chargement : ${messageErreur(error)}',
        icon: Icons.error_outline,
      ),
    );
  }
}

class _ApprenantTile extends StatelessWidget {
  const _ApprenantTile({
    required this.apprenant,
    required this.coche,
    required this.onSelection,
  });

  final Apprenant apprenant;
  final bool coche;
  final ValueChanged<bool> onSelection;

  /// Le login de l'élève : son numéro réduit à ses chiffres.
  String? get _identifiant {
    final chiffres = (apprenant.telephone ?? '').replaceAll(RegExp(r'\D'), '');
    return chiffres.length >= 6 ? chiffres : null;
  }

  @override
  Widget build(BuildContext context) {
    final ouvert = apprenant.profileId != null;
    final identifiant = _identifiant;

    return Material(
      color: AppColors.blueMist,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onSelection(!coche),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
          child: Row(
            children: [
              Checkbox(
                value: coche,
                onChanged: (value) => onSelection(value ?? false),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      apprenant.nomComplet,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      identifiant == null
                          ? 'Sans numéro de téléphone — espace impossible'
                          : 'Identifiant : $identifiant',
                      style: TextStyle(
                        color: identifiant == null
                            ? AppColors.danger
                            : AppColors.inkMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              StatusChip(
                label: ouvert ? 'Espace ouvert' : 'Aucun espace',
                level: ouvert ? AlertLevel.success : AlertLevel.warning,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Les comptes élèves que plus aucune fiche ne désigne.
///
/// Ils naissent d'une suppression de fiche antérieure à la règle qui ferme
/// le compte avec elle, ou d'un lien rompu en cours de route. Le compte
/// reste capable de se connecter alors que son titulaire n'existe plus
/// nulle part, et rien dans l'application ne le montrait : la liste des
/// utilisateurs écarte les élèves, et cet écran ne connaît que les fiches.
final comptesElevesOrphelinsProvider =
    FutureProvider.autoDispose<List<Profile>>((ref) async {
      final profils = await ref.watch(adminRepositoryProvider).fetchProfiles();
      final apprenants = await ref.watch(apprenantsListProvider.future);
      final rattaches = {
        for (final a in apprenants)
          if (a.profileId != null) a.profileId!,
      };
      return profils
          .where(
            (p) =>
                p.role == AppRole.eleveStagiaire && !rattaches.contains(p.id),
          )
          .toList();
    });

class _ComptesOrphelins extends ConsumerStatefulWidget {
  const _ComptesOrphelins();

  @override
  ConsumerState<_ComptesOrphelins> createState() => _ComptesOrphelinsState();
}

class _ComptesOrphelinsState extends ConsumerState<_ComptesOrphelins> {
  bool _enCours = false;

  Future<void> _fermerTous(List<Profile> orphelins) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Fermer les comptes sans fiche'),
        content: Text(
          '${orphelins.length} compte(s) élève ne correspondent à aucune '
          'fiche d\'apprenant. Ils peuvent encore se connecter à un espace '
          'vide.\n\nLes fermer est définitif : le compte et son accès '
          'disparaissent. Aucune fiche n\'est touchée — il n\'y en a plus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Fermer les comptes'),
          ),
        ],
      ),
    );
    if (confirme != true) return;

    setState(() => _enCours = true);
    var fermes = 0;
    final echecs = <String>[];
    try {
      for (final orphelin in orphelins) {
        try {
          await ref.read(adminRepositoryProvider).deleteUser(orphelin.id);
          fermes++;
        } catch (e) {
          // Un compte en échec ne doit pas arrêter les autres : on les
          // compte et on le dit à la fin.
          echecs.add('${orphelin.identiteComplete} : ${messageErreur(e)}');
        }
      }
    } finally {
      if (mounted) setState(() => _enCours = false);
    }

    ref.invalidate(profilesListProvider);
    ref.invalidate(comptesElevesOrphelinsProvider);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          echecs.isEmpty
              ? '$fermes compte(s) fermé(s).'
              : '$fermes fermé(s), ${echecs.length} en échec — '
                    '${echecs.first}',
        ),
        backgroundColor: echecs.isEmpty ? AppColors.success : AppColors.danger,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orphelinsAsync = ref.watch(comptesElevesOrphelinsProvider);
    final orphelins = orphelinsAsync.value ?? const <Profile>[];
    if (orphelins.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: AppColors.blueMist,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_outlined, color: AppColors.warning),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${orphelins.length} compte(s) élève sans fiche',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    orphelins.map((p) => p.identiteComplete).join(', '),
                    style: const TextStyle(
                      color: AppColors.inkMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: _enCours ? null : () => _fermerTous(orphelins),
              icon: _enCours
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.person_off_outlined, size: 18),
              label: const Text('Fermer ces comptes'),
            ),
          ],
        ),
      ),
    );
  }
}
