import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sig_ensoa/core/erreurs.dart';
import 'package:sig_ensoa/core/theme.dart' hide AlertLevel, AlertLevelColor;
import '../../models/apprenant.dart';
import '../../models/classe.dart';
import '../../models/division.dart';
import '../../models/promotion.dart';
import 'package:sig_ensoa/modules/scolarite/compat.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/filtres_scolarite.dart';
import '../../shared/widgets/pdf_preview_dialog.dart';
import '../matieres/providers/matieres_providers.dart';
import 'entity_tabs.dart';
import 'import_apprenants_dialog.dart';
import 'liste_apprenants_pdf.dart';
import 'pdf_fonts.dart';
import 'providers/apprenants_providers.dart';
import 'register_apprenant_dialog.dart';

class ApprenantsListScreen extends ConsumerStatefulWidget {
  const ApprenantsListScreen({super.key});

  @override
  ConsumerState<ApprenantsListScreen> createState() =>
      _ApprenantsListScreenState();
}

class _ApprenantsListScreenState extends ConsumerState<ApprenantsListScreen> {
  String? _divisionFilter;
  String? _classeFilter;
  String? _promotionFilter;
  String? _stageFilter;
  final _nomSearchCtrl = TextEditingController();
  final _matriculeSearchCtrl = TextEditingController();
  final Set<String> _selectedIds = {};
  bool _selectionMode = false;

  @override
  void dispose() {
    _nomSearchCtrl.dispose();
    _matriculeSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _deleteOne(Apprenant apprenant) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(
          apprenant.suppressionDemandee
              ? 'Confirmer la suppression'
              : 'Supprimer cet apprenant',
        ),
        content: Text(
          apprenant.suppressionDemandee
              ? 'Une suppression a été demandée pour la fiche de ${apprenant.nomComplet}. Confirmer la suppression définitive ?'
              : 'Voulez-vous vraiment supprimer la fiche de ${apprenant.nomComplet} ? Cette action est irréversible.',
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
    if (confirmed != true) return;

    try {
      await ref
          .read(apprenantsRepositoryProvider)
          .deleteApprenant(apprenant.id);
      ref.invalidate(apprenantsListProvider);
      setState(() => _selectedIds.remove(apprenant.id));
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Apprenant supprimé.'),
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

  /// Un non-administrateur ne peut pas supprimer directement (RLS) : il
  /// déclenche une demande, qui notifie tous les administrateurs.
  Future<void> _requestDeletion(Apprenant apprenant) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Demander la suppression'),
        content: const Text(
          'La suppression de cette fiche sera soumise à un administrateur pour validation. Continuer ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Demander'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref
          .read(apprenantsRepositoryProvider)
          .requestApprenantDeletion(apprenant.id);
      ref.invalidate(apprenantsListProvider);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Demande de suppression envoyée à l\'administrateur.'),
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

  /// L'administrateur rejette une demande de suppression : la fiche est
  /// conservée, la demande annulée.
  Future<void> _rejectDeletion(Apprenant apprenant) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Rejeter la demande'),
        content: const Text(
          'La fiche sera conservée et la demande de suppression annulée. Continuer ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Rejeter'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref
          .read(apprenantsRepositoryProvider)
          .rejectApprenantDeletion(apprenant.id);
      ref.invalidate(apprenantsListProvider);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Demande de suppression rejetée.'),
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

  Future<void> _deleteSelected(List<Apprenant> apprenants) async {
    final messenger = ScaffoldMessenger.of(context);
    final toDelete = apprenants
        .where((a) => _selectedIds.contains(a.id))
        .toList();
    if (toDelete.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Supprimer les apprenants sélectionnés'),
        content: Text(
          'Voulez-vous vraiment supprimer ${toDelete.length} fiche(s) apprenant ? Cette action est irréversible.',
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
    if (confirmed != true) return;
    if (!mounted) return;

    final progress = ValueNotifier<int>(0);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          scrollable: true,
          title: const Text('Suppression en cours'),
          content: ValueListenableBuilder<int>(
            valueListenable: progress,
            builder: (context, value, _) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(value: value / toDelete.length),
                const SizedBox(height: 12),
                Text('$value / ${toDelete.length} fiche(s) supprimée(s)'),
              ],
            ),
          ),
        ),
      ),
    );

    var failures = 0;
    for (final apprenant in toDelete) {
      try {
        await ref
            .read(apprenantsRepositoryProvider)
            .deleteApprenant(apprenant.id);
      } catch (_) {
        failures++;
      }
      progress.value++;
    }
    progress.dispose();
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    ref.invalidate(apprenantsListProvider);
    setState(() {
      _selectedIds.clear();
      _selectionMode = false;
    });
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          failures == 0
              ? '${toDelete.length} apprenant(s) supprimé(s).'
              : '${toDelete.length - failures} apprenant(s) supprimé(s), $failures échec(s).',
        ),
        backgroundColor: failures == 0 ? AppColors.success : AppColors.danger,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final apprenantsAsync = ref.watch(apprenantsListProvider);
    final divisionsAsync = ref.watch(divisionsProvider);
    final classesAsync = ref.watch(classesListProvider);
    final isAdmin =
        ref.watch(currentProfileProvider).value?.role == AppRole.admin;

    final divisions = divisionsAsync.value ?? const <Division>[];
    // Une seule division visible — c'est le cas d'un commandant de division
    // ou d'un commandant de promotion, cloisonnés sur la leur : il n'y a rien
    // à choisir,
    // on entre directement dans cette division et l'écran s'ouvre sur ses
    // classes et stages.
    final divisionUnique = divisions.length == 1 ? divisions.first : null;
    final divisionFilter = divisionUnique?.id ?? _divisionFilter;

    // Sous une division viennent, au même niveau, ses promotions et ses
    // stages — la Division de Formation des Spécialistes a les deux. Une
    // promotion mène ensuite à ses phases ; un stage se suffit à lui-même.
    final promotionsDeLaDivision = divisionFilter == null
        ? const <Promotion>[]
        : ref.watch(promotionsParDivisionProvider(divisionFilter));

    final classesDeLaDivision = divisionFilter == null
        ? const <Classe>[]
        : (classesAsync.value ?? const <Classe>[])
              .where((c) => c.divisionId == divisionFilter)
              .toList();

    final stagesDeLaDivision = classesDeLaDivision
        .where((c) => c.type == ClasseType.stage)
        .toList();

    // Les phases ne se montrent que sous une promotion retenue : sous
    // « toutes », il n'y a pas de rang intermédiaire à afficher.
    final phasesDeLaPromotion = _promotionFilter == null
        ? const <Classe>[]
        : classesDeLaDivision
              .where(
                (c) =>
                    c.type == ClasseType.phase &&
                    c.promotionId == _promotionFilter,
              )
              .toList();

    // Ce sur quoi porte l'écran : la phase choisie, le stage choisi, ou
    // toutes les phases de la promotion retenue.
    final classesForDivision = _stageFilter != null
        ? classesDeLaDivision.where((c) => c.id == _stageFilter).toList()
        : _promotionFilter != null
        ? phasesDeLaPromotion
        : classesDeLaDivision;

    final selectedDivision =
        divisionUnique ??
        (divisionFilter == null
            ? null
            : _findById(divisions, divisionFilter, (d) => d.id));
    // Un stage retenu vaut sélection directe : il n'a pas de phase où
    // descendre.
    final selectedClasse = _stageFilter != null
        ? _findById(classesDeLaDivision, _stageFilter, (c) => c.id)
        : _classeFilter == null
        ? null
        : _findById(classesForDivision, _classeFilter, (c) => c.id);

    // Ce sur quoi porte l'écran. Un élève entre dans une promotion et suit
    // toutes ses phases : choisir une phase ne restreint donc pas
    // l'effectif, c'est la promotion qui le délimite. Un stage a le sien.
    // Nul sous « toutes » — la division entière est alors la portée.
    final promotionInscription = _promotionFilter == null
        ? null
        : promotionsDeLaDivision
              .where((p) => p.id == _promotionFilter)
              .firstOrNull;
    // La phase où l'élève commence : celle qu'on regarde, sinon la
    // première du cursus — les phases arrivent dans l'ordre où elles ont
    // été créées, donc dans celui où elles se suivent.
    final classeInscription =
        selectedClasse ??
        (phasesDeLaPromotion.isEmpty ? null : phasesDeLaPromotion.first);

    final classesRetenues = _stageFilter != null
        ? {_stageFilter!}
        : _promotionFilter == null
        ? null
        : {for (final c in phasesDeLaPromotion) c.id};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Élèves & Stagiaires'),
        const SizedBox(height: 16),
        if (divisionUnique == null)
          divisionsAsync.when(
            data: (divisions) => _DivisionFilters(
              divisions: divisions,
              selected: _divisionFilter,
              onSelect: (id) => setState(() {
                _divisionFilter = id;
                _promotionFilter = null;
                _stageFilter = null;
                _classeFilter = null;
              }),
            ),
            loading: () => const SizedBox(height: 40),
            error: (_, _) => const SizedBox.shrink(),
          ),
        if (promotionsDeLaDivision.isNotEmpty ||
            stagesDeLaDivision.isNotEmpty) ...[
          if (divisionUnique == null) const SizedBox(height: 12),
          PromotionsEtStagesFilters(
            promotions: promotionsDeLaDivision,
            stages: stagesDeLaDivision,
            choix: ChoixScolarite(
              promotionId: _promotionFilter,
              stageId: _stageFilter,
            ),
            onChoix: (choix) => setState(() {
              _promotionFilter = choix.promotionId;
              _stageFilter = choix.stageId;
              _classeFilter = null;
            }),
          ),
        ],
        if (phasesDeLaPromotion.isNotEmpty) ...[
          const SizedBox(height: 12),
          _ClasseFilters(
            classes: phasesDeLaPromotion,
            selected: _classeFilter,
            onSelect: (id) => setState(() => _classeFilter = id),
          ),
        ],
        const SizedBox(height: 16),
        // « Toutes » n'est pas l'absence de portée mais la portée la plus
        // large : l'école entière, ou ce que la RLS en laisse voir. Elle
        // ouvre donc les mêmes onglets qu'une division — situation de prise
        // d'armes, consultations, permissions, absences —, cumulés. Seule la
        // saisie y est fermée : on n'enregistre pas une permission sans dire
        // dans quelle phase.
        Expanded(
          child: EntityTabsView(
            division: selectedDivision,
            classe: selectedClasse,
            classesRetenues: classesRetenues,
            sousPromotion: promotionInscription != null,
            elevesStagiairesTab: _apprenantsList(
              apprenantsAsync,
              divisionsAsync,
              classesAsync,
              selectedDivision,
              selectedClasse,
              isAdmin,
              classesRetenues,
              classeInscription,
              promotionInscription,
            ),
          ),
        ),
      ],
    );
  }

  Widget _apprenantsList(
    AsyncValue<List<Apprenant>> apprenantsAsync,
    AsyncValue<List<Division>> divisionsAsync,
    AsyncValue<List<Classe>> classesAsync,
    Division? selectedDivision,
    Classe? selectedClasse,
    bool isAdmin,
    Set<String>? classesRetenues,
    Classe? classeInscription,
    Promotion? promotionInscription,
  ) {
    // Sur tablette l'écran est large mais bas : les boutons, la recherche et
    // la sélection prenaient la moitié de la hauteur, et il ne restait à la
    // liste qu'une fente de trois lignes où l'on peinait à faire défiler.
    // Tout tient maintenant dans un seul défilement — l'en-tête s'efface vers
    // le haut et rend sa place aux élèves.
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // On enregistre dans une promotion, pas dans une phase : il suffit
              // donc qu'une promotion soit retenue. La phase transmise est celle
              // où l'élève commence — la première du cursus à défaut de choix.
              if (selectedDivision != null && classeInscription != null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _imprimerListe(
                        apprenants: _filtrer(
                          apprenantsAsync.value ?? const [],
                          classesRetenues,
                        ),
                        division: selectedDivision,
                        promotion: promotionInscription,
                        stage: selectedClasse?.type == ClasseType.stage
                            ? selectedClasse
                            : null,
                      ),
                      icon: const Icon(Icons.print_outlined, size: 18),
                      label: const Text('Imprimer la liste'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () => showImportApprenantsDialog(
                        context,
                        division: selectedDivision,
                        classe: classeInscription,
                      ),
                      icon: const Icon(Icons.upload_file_outlined, size: 18),
                      label: const Text('Importer un fichier Excel'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: () => showRegisterApprenantDialog(
                        context,
                        division: selectedDivision,
                        classe: classeInscription,
                        promotion: promotionInscription,
                      ),
                      icon: const Icon(Icons.person_add_alt, size: 18),
                      label: const Text('Enregistrement individuel'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nomSearchCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Rechercher par nom',
                        prefixIcon: Icon(Icons.search, size: 20),
                        isDense: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _matriculeSearchCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Rechercher par matricule',
                        prefixIcon: Icon(Icons.search, size: 20),
                        isDense: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              if (isAdmin) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: _selectionMode
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton(
                              onPressed: () => setState(() {
                                _selectionMode = false;
                                _selectedIds.clear();
                              }),
                              child: const Text('Annuler'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: _selectedIds.isEmpty
                                  ? null
                                  : () => _deleteSelected(
                                      apprenantsAsync.value ?? const [],
                                    ),
                              icon: const Icon(
                                Icons.delete_outline,
                                size: 18,
                                color: AppColors.danger,
                              ),
                              label: Text(
                                'Supprimer la sélection (${_selectedIds.length})',
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.danger,
                                side: const BorderSide(color: AppColors.danger),
                              ),
                            ),
                          ],
                        )
                      : OutlinedButton.icon(
                          onPressed: () =>
                              setState(() => _selectionMode = true),
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: AppColors.danger,
                          ),
                          label: const Text('Supprimer'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.danger,
                            side: const BorderSide(color: AppColors.danger),
                          ),
                        ),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
        apprenantsAsync.when(
          data: (apprenants) {
            final divisionsById = {
              for (final d in divisionsAsync.value ?? <Division>[]) d.id: d,
            };
            final classesById = {
              for (final c in classesAsync.value ?? <Classe>[]) c.id: c,
            };
            final filtered = _filtrer(apprenants, classesRetenues);

            if (filtered.isEmpty) {
              return const SliverToBoxAdapter(
                child: EmptyState(
                  message: 'Aucun apprenant trouvé.',
                  icon: Icons.groups_outlined,
                ),
              );
            }

            final filteredIds = filtered.map((a) => a.id).toSet();
            final allSelected = filteredIds.every(_selectedIds.contains);

            return SliverMainAxisGroup(
              slivers: [
                if (isAdmin && _selectionMode)
                  SliverToBoxAdapter(
                    child: InkWell(
                      onTap: () => setState(() {
                        if (allSelected) {
                          _selectedIds.removeAll(filteredIds);
                        } else {
                          _selectedIds.addAll(filteredIds);
                        }
                      }),
                      child: Row(
                        children: [
                          Checkbox(
                            value: allSelected,
                            onChanged: (value) => setState(() {
                              if (value ?? false) {
                                _selectedIds.addAll(filteredIds);
                              } else {
                                _selectedIds.removeAll(filteredIds);
                              }
                            }),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            allSelected
                                ? 'Tout désélectionner'
                                : 'Tout sélectionner',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                SliverList.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final apprenant = filtered[index];
                    final division = divisionsById[apprenant.divisionId];
                    final classe = classesById[apprenant.classeId];
                    return _ApprenantTile(
                      apprenant: apprenant,
                      divisionNom: division?.nom ?? '—',
                      classeNom: classe?.nom,
                      isAdmin: isAdmin,
                      showCheckbox: _selectionMode,
                      selected: _selectedIds.contains(apprenant.id),
                      onSelectedChanged: (value) => setState(() {
                        if (value ?? false) {
                          _selectedIds.add(apprenant.id);
                        } else {
                          _selectedIds.remove(apprenant.id);
                        }
                      }),
                      onDelete: () => _deleteOne(apprenant),
                      onRequestDeletion: () => _requestDeletion(apprenant),
                      onRejectDeletion: () => _rejectDeletion(apprenant),
                    );
                  },
                ),
              ],
            );
          },
          loading: () => const SliverToBoxAdapter(
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => SliverToBoxAdapter(
            child: EmptyState(
              message: 'Erreur de chargement : ${messageErreur(error)}',
              icon: Icons.error_outline,
            ),
          ),
        ),
      ],
    );
  }
}

T? _findById<T>(List<T> items, String? id, String Function(T) idOf) {
  for (final item in items) {
    if (idOf(item) == id) return item;
  }
  return null;
}

class _DivisionFilters extends StatelessWidget {
  const _DivisionFilters({
    required this.divisions,
    required this.selected,
    required this.onSelect,
  });

  final List<Division> divisions;
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilterChipPill(
          label: 'Toutes',
          selected: selected == null,
          onTap: () => onSelect(null),
        ),
        for (final division in divisions)
          FilterChipPill(
            label: division.nom,
            selected: selected == division.id,
            onTap: () => onSelect(division.id),
          ),
      ],
    );
  }
}

/// Les phases d'une promotion retenue — ce rang n'existe que sous une
/// promotion, un stage n'ayant pas de phase où descendre.
class _ClasseFilters extends StatelessWidget {
  const _ClasseFilters({
    required this.classes,
    required this.selected,
    required this.onSelect,
  });

  final List<Classe> classes;
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilterChipPill(
          label: 'Toutes les phases',
          selected: selected == null,
          onTap: () => onSelect(null),
        ),
        for (final classe in classes)
          FilterChipPill(
            label: classe.nom,
            selected: selected == classe.id,
            onTap: () => onSelect(classe.id),
          ),
      ],
    );
  }
}

class _ApprenantTile extends ConsumerWidget {
  const _ApprenantTile({
    required this.apprenant,
    required this.divisionNom,
    this.classeNom,
    this.isAdmin = false,
    this.showCheckbox = false,
    this.selected = false,
    this.onSelectedChanged,
    this.onDelete,
    this.onRequestDeletion,
    this.onRejectDeletion,
  });

  final Apprenant apprenant;
  final String divisionNom;
  final String? classeNom;
  final bool isAdmin;
  final bool showCheckbox;
  final bool selected;
  final ValueChanged<bool?>? onSelectedChanged;
  final VoidCallback? onDelete;
  final VoidCallback? onRequestDeletion;
  final VoidCallback? onRejectDeletion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = apprenant.suppressionDemandee;
    final photoPath = apprenant.photoPath;
    final photoUrl = photoPath == null
        ? null
        : ref.watch(apprenantPhotoUrlProvider(photoPath)).value;
    // Container + InkWell plutôt que Card/ListTile : aucun widget élevé
    // (Material type=card, PhysicalModel) dans l'arbre, donc aucune ombre
    // possible ici, y compris au survol.
    return Material(
      color: AppColors.blueMist,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/scolarite/apprenants/${apprenant.id}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              if (showCheckbox) ...[
                Checkbox(value: selected, onChanged: onSelectedChanged),
                const SizedBox(width: 4),
              ],
              CircleAvatar(
                backgroundColor: AppColors.cardBg,
                backgroundImage: photoUrl != null
                    ? NetworkImage(photoUrl)
                    : null,
                child: photoUrl != null
                    ? null
                    : Text(
                        // La même lettre que celle qui ouvre la ligne : le
                        // nom, puisque c'est par lui qu'on lit la liste.
                        apprenant.nom.isNotEmpty
                            ? apprenant.nom[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.blueDeep,
                        ),
                      ),
              ),
              const SizedBox(width: 16),
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
                      '${apprenant.matricule ?? "Sans matricule"} · $divisionNom${classeNom != null ? ' · $classeNom' : ''}',
                      style: const TextStyle(
                        color: AppColors.inkMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              StatusChip(
                label: apprenant.statut.label,
                level: apprenant.statut == ApprenantStatut.actif
                    ? AlertLevel.success
                    : AlertLevel.warning,
              ),
              if (pending) ...[
                const SizedBox(width: 8),
                Tooltip(
                  message:
                      'Suppression demandée le '
                      '${apprenant.deletionRequestedAt!.day.toString().padLeft(2, '0')}/'
                      '${apprenant.deletionRequestedAt!.month.toString().padLeft(2, '0')}/'
                      '${apprenant.deletionRequestedAt!.year}',
                  child: const StatusChip(
                    label: 'Suppression demandée',
                    level: AlertLevel.critical,
                  ),
                ),
              ],
              if (isAdmin && pending)
                IconButton(
                  icon: const Icon(
                    Icons.close,
                    size: 20,
                    color: AppColors.inkMuted,
                  ),
                  onPressed: onRejectDeletion,
                  tooltip: 'Rejeter la demande',
                ),
              IconButton(
                icon: Icon(
                  pending && !isAdmin
                      ? Icons.hourglass_empty
                      : Icons.delete_outline,
                  color: pending && !isAdmin
                      ? AppColors.inkMuted
                      : AppColors.danger,
                ),
                onPressed: pending && !isAdmin
                    ? null
                    : (isAdmin ? onDelete : onRequestDeletion),
                tooltip: pending && !isAdmin
                    ? 'Suppression déjà demandée'
                    : (isAdmin ? 'Supprimer' : 'Demander la suppression'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Extension d'écran : le filtre appliqué à la liste, et son impression.
extension _ListeApprenants on _ApprenantsListScreenState {
  /// Ce que l'écran montre : la division, la portée retenue (promotion ou
  /// stage) et les deux recherches. La même règle sert à l'affichage et à
  /// l'impression — imprimer autre chose que ce qu'on voit serait une
  /// surprise.
  List<Apprenant> _filtrer(
    List<Apprenant> apprenants,
    Set<String>? classesRetenues,
  ) {
    final nomQuery = _nomSearchCtrl.text.trim().toLowerCase();
    final matriculeQuery = _matriculeSearchCtrl.text.trim().toLowerCase();
    return apprenants.where((a) {
      if (_divisionFilter != null && a.divisionId != _divisionFilter) {
        return false;
      }
      if (classesRetenues != null && !classesRetenues.contains(a.classeId)) {
        return false;
      }
      if (nomQuery.isNotEmpty &&
          !a.nomComplet.toLowerCase().contains(nomQuery)) {
        return false;
      }
      if (matriculeQuery.isNotEmpty &&
          !(a.matricule ?? '').toLowerCase().contains(matriculeQuery)) {
        return false;
      }
      return true;
    }).toList();
  }
}

extension _ImpressionListe on _ApprenantsListScreenState {
  /// Imprime la liste telle qu'elle est affichée. Le titre nomme la portée
  /// pour que la feuille se suffise à elle-même une fois détachée de
  /// l'écran.
  Future<void> _imprimerListe({
    required List<Apprenant> apprenants,
    required Division? division,
    required Promotion? promotion,
    required Classe? stage,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    if (apprenants.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Aucun apprenant à imprimer dans cette liste.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }
    try {
      final armoiries = (await rootBundle.load(
        'assets/images/armoiries_ci.png',
      )).buffer.asUint8List();

      final portee = stage != null
          ? 'Stage ${stage.nom}'
          : promotion != null
          ? promotion.intitule
          : 'Toutes promotions et stages';

      final doc = buildListeApprenantsPdf(
        apprenants,
        titre: stage != null
            ? 'Liste des stagiaires'
            : 'Liste des élèves et stagiaires',
        sousTitre: '$portee · ${division?.nom ?? "Toutes divisions"}',
        armoiries: armoiries,
        theme: await chargerThemePdf(),
      );
      final bytes = await doc.save();
      if (!mounted) return;
      await showPdfPreviewDialog(context, bytes);
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
