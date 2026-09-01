import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sig_ensoa/core/erreurs.dart';
import 'package:sig_ensoa/core/theme.dart' hide AlertLevel, AlertLevelColor;
import '../../models/classe.dart';
import '../../models/controle.dart';
import '../../models/division.dart';
import '../../models/promotion.dart';
import '../../models/sous_module.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/filtres_scolarite.dart';
import '../../shared/widgets/pdf_preview_dialog.dart';
import '../apprenants/bulletins_pdf.dart';
import '../apprenants/pdf_fonts.dart';
import '../apprenants/providers/apprenants_providers.dart';
import '../apprenants/providers/controles_providers.dart';
import '../apprenants/providers/sous_modules_providers.dart';
import '../matieres/providers/matieres_providers.dart';

/// Écran (réservé à l'administrateur) où l'on choisit, division par
/// division et classe/stage par classe/stage, quels modules, contrôles
/// continus et examens entrent dans le calcul des bulletins — voir
/// [Controle.inclusBulletin]. Seuls les contrôles cochés ici compteront,
/// même si d'autres contrôles existent avec des notes déjà saisies.
class BulletinsScreen extends ConsumerStatefulWidget {
  const BulletinsScreen({super.key});

  @override
  ConsumerState<BulletinsScreen> createState() => _BulletinsScreenState();
}

class _BulletinsScreenState extends ConsumerState<BulletinsScreen> {
  String? _divisionFilter;
  String? _promotionFilter;
  String? _stageFilter;

  @override
  Widget build(BuildContext context) {
    final divisionsAsync = ref.watch(divisionsProvider);
    final classesAsync = ref.watch(classesListProvider);

    final classesForDivision = _divisionFilter == null
        ? const <Classe>[]
        : (classesAsync.value ?? const <Classe>[])
              .where((c) => c.divisionId == _divisionFilter)
              .toList();

    final promotionsDeLaDivision = _divisionFilter == null
        ? const <Promotion>[]
        : ref.watch(promotionsParDivisionProvider(_divisionFilter!));

    final stagesDeLaDivision = classesForDivision
        .where((c) => c.type == ClasseType.stage)
        .toList();

    final phasesDeLaPromotion = _promotionFilter == null
        ? const <Classe>[]
        : classesForDivision
              .where(
                (c) =>
                    c.type == ClasseType.phase &&
                    c.promotionId == _promotionFilter,
              )
              .toList();

    final selectedDivision = _divisionFilter == null
        ? null
        : _findById(
            divisionsAsync.value ?? const <Division>[],
            _divisionFilter,
            (d) => d.id,
          );
    final selectedStage = _stageFilter == null
        ? null
        : _findById(classesForDivision, _stageFilter, (c) => c.id);
    final selectedPromotion = _promotionFilter == null
        ? null
        : _findById(promotionsDeLaDivision, _promotionFilter, (p) => p.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Bulletins'),
        const SizedBox(height: 16),
        divisionsAsync.when(
          data: (divisions) => _DivisionFilters(
            divisions: divisions,
            selected: _divisionFilter,
            onSelect: (id) => setState(() {
              _divisionFilter = id;
              _promotionFilter = null;
              _stageFilter = null;
            }),
          ),
          loading: () => const SizedBox(height: 40),
          error: (_, _) => const SizedBox.shrink(),
        ),
        if (promotionsDeLaDivision.isNotEmpty ||
            stagesDeLaDivision.isNotEmpty) ...[
          const SizedBox(height: 12),
          PromotionsEtStagesFilters(
            promotions: promotionsDeLaDivision,
            stages: stagesDeLaDivision,
            choix: ChoixScolarite(
              promotionId: _promotionFilter,
              stageId: _stageFilter,
            ),
            avecToutes: false,
            onChoix: (choix) => setState(() {
              _promotionFilter = choix.promotionId;
              _stageFilter = choix.stageId;
            }),
          ),
        ],
        const SizedBox(height: 16),
        // Le bulletin d'un stage porte sur le stage ; celui d'une promotion
        // porte sur la promotion entière, ses phases réunies — on n'imprime
        // plus phase par phase.
        Expanded(
          child: selectedDivision == null
              ? const EmptyState(
                  message:
                      'Sélectionnez une division, puis une promotion ou un '
                      'stage, pour choisir les évaluations à inclure dans les '
                      'bulletins.',
                  icon: Icons.fact_check_outlined,
                )
              : selectedStage != null
              ? _BulletinConfig(
                  division: selectedDivision,
                  classe: selectedStage,
                )
              : selectedPromotion != null
              ? _BulletinPromotionConfig(
                  division: selectedDivision,
                  promotion: selectedPromotion,
                  phases: phasesDeLaPromotion,
                )
              : const EmptyState(
                  message:
                      'Sélectionnez une promotion ou un stage pour choisir '
                      'les évaluations à inclure dans les bulletins.',
                  icon: Icons.fact_check_outlined,
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

class _BulletinConfig extends ConsumerStatefulWidget {
  const _BulletinConfig({required this.division, required this.classe});

  final Division division;
  final Classe classe;

  @override
  ConsumerState<_BulletinConfig> createState() => _BulletinConfigState();
}

class _BulletinConfigState extends ConsumerState<_BulletinConfig> {
  bool _printing = false;

  Future<void> _printBulletins(List<Controle> controles) async {
    final classe = widget.classe;
    final included = controles.where((c) => c.inclusBulletin).toList();
    if (included.isEmpty || _printing) return;
    setState(() => _printing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final apprenants = await ref.read(
        apprenantsByClasseProvider(classe.id).future,
      );
      if (apprenants.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Aucun apprenant dans cette phase ou ce stage.'),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }
      final notes = await ref
          .read(controlesRepositoryProvider)
          .fetchByControleIds([for (final c in included) c.id]);
      final matieres = await ref.read(matieresCatalogueProvider.future);
      final matiereModules = await ref.read(matiereModulesProvider.future);
      final sousModules = await ref
          .read(sousModulesRepositoryProvider)
          .fetchByClasse(classe.id);
      final armoiries = (await rootBundle.load(
        'assets/images/armoiries_ci.png',
      )).buffer.asUint8List();
      final photosById = <String, Uint8List>{};
      for (final apprenant in apprenants) {
        final path = apprenant.photoPath;
        if (path == null) continue;
        try {
          photosById[apprenant.id] = await ref
              .read(apprenantsRepositoryProvider)
              .downloadPhoto(path);
        } catch (_) {
          // Pas de photo affichable -> cadre vide dans le PDF.
        }
      }
      final items = [
        for (final apprenant in apprenants)
          BulletinPrintData(
            apprenant: apprenant,
            classe: classe,
            division: widget.division,
            controles: included,
            notes: notes.where((n) => n.apprenantId == apprenant.id).toList(),
            matieres: matieres,
            matiereModules: matiereModules,
            sousModules: sousModules,
            photo: photosById[apprenant.id],
          ),
      ];
      final doc = buildBulletinsPdf(
        items,
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
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final classe = widget.classe;
    final controlesAsync = ref.watch(controlesByClasseProvider(classe.id));
    // "Modules" et "Sport" ne concernent que les phases (élèves) — pas les
    // stages. Sans le Sport dans cette liste, son module ne pouvait pas
    // être coché, et n'apparaissait donc jamais sur un bulletin.
    final types = [
      if (classe.type == ClasseType.phase) ...[
        ControleType.module,
        ControleType.sport,
      ],
      ControleType.continu,
      ControleType.examen,
    ];

    return controlesAsync.when(
      data: (controles) {
        if (controles.isEmpty) {
          return const EmptyState(
            message:
                'Aucun module, contrôle continu ou examen enregistré pour cette phase ou ce stage.',
            icon: Icons.fact_check_outlined,
          );
        }
        final includedCount = controles.where((c) => c.inclusBulletin).length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: includedCount == 0 || _printing
                    ? null
                    : () => _printBulletins(controles),
                icon: const Icon(Icons.print_outlined, size: 18),
                label: const Text('Imprimer les bulletins'),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final type in types) ...[
                      if (controles.any((c) => c.type == type)) ...[
                        SectionHeader(title: type.sectionLabel(classe.type)),
                        const SizedBox(height: 12),
                        for (final controle in controles.where(
                          (c) => c.type == type,
                        )) ...[
                          _BulletinControleTile(controle: controle),
                          const SizedBox(height: 8),
                        ],
                        const SizedBox(height: 24),
                      ],
                    ],
                  ],
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

class _BulletinControleTile extends ConsumerWidget {
  const _BulletinControleTile({required this.controle, this.phaseNom});

  final Controle controle;

  /// La phase d'où vient l'évaluation — utile seulement quand la liste en
  /// mêle plusieurs, c'est-à-dire sur le bulletin d'une promotion.
  final String? phaseNom;

  Future<void> _toggle(BuildContext context, WidgetRef ref, bool value) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(controlesRepositoryProvider)
          .setInclusBulletin(controle.id, value);
      ref.invalidate(controlesByClasseProvider(controle.classeId));
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
    return Material(
      color: AppColors.blueMist,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _toggle(context, ref, !controle.inclusBulletin),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      controle.libelle,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (phaseNom != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        phaseNom!,
                        style: const TextStyle(
                          color: AppColors.inkMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 16),
              StatusChip(
                label: 'Coefficient ${controle.coefficient}',
                level: AlertLevel.info,
              ),
              const SizedBox(width: 16),
              const Text(
                'Inclus au bulletin',
                style: TextStyle(color: AppColors.inkMuted, fontSize: 13),
              ),
              Checkbox(
                value: controle.inclusBulletin,
                onChanged: (value) => _toggle(context, ref, value ?? false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Le bulletin d'une promotion : ses phases réunies.
///
/// Un apprenant traverse plusieurs phases au cours d'une promotion, et ses
/// notes s'y répartissent. Imprimer phase par phase donnait donc autant de
/// bulletins partiels qu'il avait traversé de phases. On rassemble ici les
/// évaluations de toutes les phases — sport, modules, contrôles continus et
/// examens — et l'administrateur retient celles qui doivent compter.
class _BulletinPromotionConfig extends ConsumerStatefulWidget {
  const _BulletinPromotionConfig({
    required this.division,
    required this.promotion,
    required this.phases,
  });

  final Division division;
  final Promotion promotion;
  final List<Classe> phases;

  @override
  ConsumerState<_BulletinPromotionConfig> createState() =>
      _BulletinPromotionConfigState();
}

class _BulletinPromotionConfigState
    extends ConsumerState<_BulletinPromotionConfig> {
  bool _printing = false;

  Future<void> _printBulletins(List<Controle> controles) async {
    final included = controles.where((c) => c.inclusBulletin).toList();
    if (included.isEmpty || _printing) return;
    setState(() => _printing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      // L'effectif se lit une fois sur la promotion : un élève suit toutes
      // ses phases, le prendre phase par phase le compterait autant de fois
      // qu'elle en contient.
      final apprenants = await ref.read(
        apprenantsByPromotionProvider(widget.promotion.id).future,
      );
      final sousModules = <SousModule>[];
      for (final phase in widget.phases) {
        sousModules.addAll(
          await ref.read(sousModulesRepositoryProvider).fetchByClasse(phase.id),
        );
      }
      if (apprenants.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Aucun apprenant dans cette promotion.'),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }

      final notes = await ref
          .read(controlesRepositoryProvider)
          .fetchByControleIds([for (final c in included) c.id]);
      final matieres = await ref.read(matieresCatalogueProvider.future);
      final matiereModules = await ref.read(matiereModulesProvider.future);
      final armoiries = (await rootBundle.load(
        'assets/images/armoiries_ci.png',
      )).buffer.asUint8List();

      final phasesById = {for (final p in widget.phases) p.id: p};

      final photosById = <String, Uint8List>{};
      for (final apprenant in apprenants) {
        final path = apprenant.photoPath;
        if (path == null) continue;
        try {
          photosById[apprenant.id] = await ref
              .read(apprenantsRepositoryProvider)
              .downloadPhoto(path);
        } catch (_) {
          // Pas de photo affichable -> cadre vide dans le PDF.
        }
      }

      final items = [
        for (final apprenant in apprenants)
          if (phasesById[apprenant.classeId] != null)
            BulletinPrintData(
              apprenant: apprenant,
              classe: phasesById[apprenant.classeId]!,
              division: widget.division,
              promotion: widget.promotion,
              phases: widget.phases,
              controles: included,
              notes: notes.where((n) => n.apprenantId == apprenant.id).toList(),
              matieres: matieres,
              matiereModules: matiereModules,
              sousModules: sousModules,
              photo: photosById[apprenant.id],
            ),
      ];
      final doc = buildBulletinsPdf(
        items,
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
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.phases.isEmpty) {
      return const EmptyState(
        message:
            'Cette promotion n\'a aucune phase.\nCréez-en dans Matières › '
            'Phases / Stages avant d\'imprimer des bulletins.',
        icon: Icons.fact_check_outlined,
      );
    }

    // Les évaluations de toutes les phases, chacune gardant la sienne pour
    // qu'on sache d'où elle vient.
    final controles = <Controle>[];
    var enChargement = false;
    for (final phase in widget.phases) {
      final async = ref.watch(controlesByClasseProvider(phase.id));
      if (async.isLoading) enChargement = true;
      controles.addAll(async.value ?? const []);
    }
    if (enChargement && controles.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (controles.isEmpty) {
      return const EmptyState(
        message:
            'Aucune évaluation enregistrée dans les phases de cette '
            'promotion.',
        icon: Icons.fact_check_outlined,
      );
    }

    final nomsDesPhases = {for (final p in widget.phases) p.id: p.nom};
    final types = const [
      ControleType.sport,
      ControleType.module,
      ControleType.continu,
      ControleType.examen,
    ];
    final includedCount = controles.where((c) => c.inclusBulletin).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${widget.promotion.intitule} · ${widget.phases.length} '
                'phase(s) · $includedCount évaluation(s) retenue(s)',
                style: const TextStyle(color: AppColors.inkMuted, fontSize: 13),
              ),
            ),
            OutlinedButton.icon(
              onPressed: includedCount == 0 || _printing
                  ? null
                  : () => _printBulletins(controles),
              icon: const Icon(Icons.print_outlined, size: 18),
              label: const Text('Imprimer les bulletins'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final type in types)
                  if (controles.any((c) => c.type == type)) ...[
                    SectionHeader(title: type.sectionLabel(ClasseType.phase)),
                    const SizedBox(height: 12),
                    for (final controle in controles.where(
                      (c) => c.type == type,
                    )) ...[
                      _BulletinControleTile(
                        controle: controle,
                        phaseNom: nomsDesPhases[controle.classeId],
                      ),
                      const SizedBox(height: 8),
                    ],
                    const SizedBox(height: 24),
                  ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
