import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:sig_ensoa/core/erreurs.dart';
import 'package:sig_ensoa/core/theme.dart' hide AlertLevel, AlertLevelColor;
import '../../models/classe.dart';
import '../../models/cours.dart';
import '../../models/division.dart';
import 'package:sig_ensoa/modules/scolarite/compat.dart';
import '../../models/promotion.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/filtres_scolarite.dart';
import '../matieres/providers/matieres_providers.dart';
import 'providers/cours_providers.dart';
import 'qcm_editor_dialog.dart';
import 'register_cours_dialog.dart';
import 'resultats_devoir_dialog.dart';

final _dateFmt = DateFormat('dd/MM/yyyy');

/// Cours d'une classe/stage, avec ses exercices d'application et ses
/// devoirs.
///
/// Le choix de la division est escamoté dès qu'une seule est visible —
/// c'est le cas du chef de division et de l'instructeur, cloisonnés sur la
/// leur (voir la migration 034) : il n'y a rien à choisir.
///
/// Chacun dépose ses supports — l'élève partage les siens avec sa classe —
/// mais ne modifie et ne supprime que ce qu'il a déposé, l'encadrement
/// gardant la main sur toute sa division. Les policies garantissent l'un et
/// l'autre, l'interface ne fait que les refléter.
class CoursScreen extends ConsumerStatefulWidget {
  const CoursScreen({super.key});

  @override
  ConsumerState<CoursScreen> createState() => _CoursScreenState();
}

class _CoursScreenState extends ConsumerState<CoursScreen> {
  String? _divisionFilter;
  String? _promotionFilter;
  String? _stageFilter;
  String? _classeFilter;

  @override
  Widget build(BuildContext context) {
    final divisions = ref.watch(divisionsProvider).value ?? const <Division>[];
    final classes = ref.watch(classesListProvider).value ?? const <Classe>[];
    final profil = ref.watch(currentProfileProvider).value;
    final encadrement =
        profil?.role == AppRole.admin ||
        profil?.role == AppRole.chefDivision ||
        profil?.role == AppRole.instructeur;

    final divisionUnique = divisions.length == 1 ? divisions.first : null;
    final divisionFilter = divisionUnique?.id ?? _divisionFilter;

    // Sous une division viennent, au même niveau, ses promotions et ses
    // stages. Une promotion mène ensuite à ses phases ; un stage se suffit
    // à lui-même.
    final promotionsDeLaDivision = divisionFilter == null
        ? const <Promotion>[]
        : ref.watch(promotionsParDivisionProvider(divisionFilter));

    final classesDeLaDivision = divisionFilter == null
        ? const <Classe>[]
        : classes.where((c) => c.divisionId == divisionFilter).toList();

    final stagesDeLaDivision = classesDeLaDivision
        .where((c) => c.type == ClasseType.stage)
        .toList();

    final phasesDeLaPromotion = _promotionFilter == null
        ? const <Classe>[]
        : classesDeLaDivision
              .where(
                (c) =>
                    c.type == ClasseType.phase &&
                    c.promotionId == _promotionFilter,
              )
              .toList();

    // Une phase unique se sélectionne d'elle-même, pour la même raison
    // qu'une division unique. Un stage retenu vaut sélection directe.
    final phaseUnique = phasesDeLaPromotion.length == 1
        ? phasesDeLaPromotion.first
        : null;
    final selectedClasse = _stageFilter != null
        ? classesDeLaDivision.where((c) => c.id == _stageFilter).firstOrNull
        : (phaseUnique?.id ?? _classeFilter) == null
        ? null
        : phasesDeLaPromotion
              .where((c) => c.id == (phaseUnique?.id ?? _classeFilter))
              .firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Cours'),
        const SizedBox(height: 16),
        if (divisionUnique == null && divisions.isNotEmpty) ...[
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
                    _classeFilter = null;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        if (promotionsDeLaDivision.isNotEmpty ||
            stagesDeLaDivision.isNotEmpty) ...[
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
          const SizedBox(height: 12),
        ],
        if (phaseUnique == null && phasesDeLaPromotion.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final phase in phasesDeLaPromotion)
                FilterChipPill(
                  label: phase.nom,
                  selected: _classeFilter == phase.id,
                  onTap: () => setState(() => _classeFilter = phase.id),
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        Expanded(
          child: selectedClasse == null
              ? const EmptyState(
                  message:
                      'Sélectionnez une phase ou un stage pour voir ses cours.',
                  icon: Icons.menu_book_outlined,
                )
              : _ContenuClasse(
                  classe: selectedClasse,
                  encadrement: encadrement,
                  profilId: profil?.id,
                ),
        ),
      ],
    );
  }
}

class _ContenuClasse extends ConsumerWidget {
  const _ContenuClasse({
    required this.classe,
    required this.encadrement,
    required this.profilId,
  });

  final Classe classe;
  final bool encadrement;
  final String? profilId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coursAsync = ref.watch(coursByClasseProvider(classe.id));
    final matieres = ref.watch(matieresCatalogueProvider).value ?? const [];
    final matiereNomById = {for (final m in matieres) m.id: m.nom};

    return coursAsync.when(
      data: (ressources) {
        final coursParId = {
          for (final r in ressources)
            if (r.type == TypeRessource.cours) r.id: r,
        };

        return ListView(
          children: [
            for (final type in TypeRessource.values) ...[
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          type.label.toUpperCase(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          type.description,
                          style: const TextStyle(
                            color: AppColors.inkMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (encadrement)
                    OutlinedButton.icon(
                      onPressed: () => showRegisterCoursDialog(
                        context,
                        classe: classe,
                        coursExistants: ressources,
                        typeInitial: type,
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Ajouter'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              for (final ressource in ressources.where((r) => r.type == type))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _RessourceTile(
                    ressource: ressource,
                    classe: classe,
                    ressources: ressources,
                    matiereNom: ressource.matiereId == null
                        ? null
                        : matiereNomById[ressource.matiereId],
                    coursParent: ressource.coursId == null
                        ? null
                        : coursParId[ressource.coursId],
                    encadrement: encadrement,
                    profilId: profilId,
                  ),
                ),
              if (!ressources.any((r) => r.type == type))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Aucun élément enregistré.',
                    style: TextStyle(color: AppColors.inkMuted, fontSize: 13),
                  ),
                ),
              const SizedBox(height: 20),
            ],
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

class _RessourceTile extends ConsumerStatefulWidget {
  const _RessourceTile({
    required this.ressource,
    required this.classe,
    required this.ressources,
    required this.matiereNom,
    required this.coursParent,
    required this.encadrement,
    required this.profilId,
  });

  final Cours ressource;
  final Classe classe;
  final List<Cours> ressources;
  final String? matiereNom;
  final Cours? coursParent;
  final bool encadrement;
  final String? profilId;

  @override
  ConsumerState<_RessourceTile> createState() => _RessourceTileState();
}

class _RessourceTileState extends ConsumerState<_RessourceTile> {
  bool _telechargement = false;

  /// L'encadrement a la main sur toute sa division ; chacun, sur ce qu'il a
  /// lui-même déposé. Même règle que les policies, reflétée ici pour ne pas
  /// proposer un bouton qui échouerait.
  bool get _peutModifier =>
      widget.encadrement || widget.ressource.createdBy == widget.profilId;

  /// Le bucket étant privé, le document est téléchargé puis proposé à
  /// l'enregistrement sur le poste — pas d'ouverture par URL.
  Future<void> _telecharger() async {
    final ressource = widget.ressource;
    final path = ressource.fichierPath;
    if (path == null || _telechargement) return;
    setState(() => _telechargement = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await ref
          .read(coursRepositoryProvider)
          .telechargerDocument(path);
      if (!mounted) return;
      final destination = await FilePicker.platform.saveFile(
        dialogTitle: 'Enregistrer le document',
        fileName: ressource.fichierNom ?? 'document',
        bytes: bytes,
      );
      if (destination == null) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Document enregistré : $destination'),
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
    } finally {
      if (mounted) setState(() => _telechargement = false);
    }
  }

  Future<void> _supprimer() async {
    final messenger = ScaffoldMessenger.of(context);
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text('Supprimer ce ${widget.ressource.type.singulier}'),
        content: Text(
          'Voulez-vous vraiment supprimer « ${widget.ressource.titre} » ? '
          'Cette action est irréversible.',
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
      await ref.read(coursRepositoryProvider).deleteCours(widget.ressource.id);
      ref.invalidate(coursByClasseProvider(widget.classe.id));
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Élément supprimé.'),
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
  Widget build(BuildContext context) {
    final ressource = widget.ressource;
    final details = [
      if (widget.matiereNom != null) widget.matiereNom!,
      if (ressource.dateSeance != null)
        '${ressource.type == TypeRessource.cours ? 'Séance du' : 'Remis le'} '
            '${_dateFmt.format(ressource.dateSeance!)}',
      if (widget.coursParent != null)
        'Suite de « ${widget.coursParent!.titre} »',
    ].join(' · ');

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
                    ressource.titre,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (details.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      details,
                      style: const TextStyle(
                        color: AppColors.inkMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  if (ressource.description != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      ressource.description!,
                      style: const TextStyle(
                        color: AppColors.inkMuted,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 16),
            if (ressource.dateRemise != null) ...[
              StatusChip(
                label: 'À rendre le ${_dateFmt.format(ressource.dateRemise!)}',
                level: ressource.echeanceDepassee
                    ? AlertLevel.critical
                    : AlertLevel.warning,
              ),
              const SizedBox(width: 8),
            ],
            if (ressource.aUnDocument)
              OutlinedButton.icon(
                onPressed: _telechargement ? null : _telecharger,
                icon: const Icon(Icons.download_outlined, size: 18),
                label: Text(_telechargement ? 'Téléchargement...' : 'Document'),
              )
            else
              const Text(
                'Sans document',
                style: TextStyle(color: AppColors.inkMuted, fontSize: 12),
              ),
            if (ressource.type == TypeRessource.devoir) ...[
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => showQcmEditorDialog(
                  context,
                  devoir: ressource,
                  modifiable: _peutModifier,
                ),
                icon: const Icon(Icons.quiz_outlined, size: 18),
                label: const Text('QCM'),
              ),
              if (widget.encadrement) ...[
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => showResultatsDevoirDialog(
                    context,
                    devoir: ressource,
                    classe: widget.classe,
                  ),
                  icon: const Icon(Icons.leaderboard_outlined, size: 18),
                  label: const Text('Résultats'),
                ),
              ],
            ],
            if (_peutModifier) ...[
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                tooltip: 'Modifier',
                onPressed: () => showRegisterCoursDialog(
                  context,
                  classe: widget.classe,
                  coursExistants: widget.ressources,
                  cours: ressource,
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: AppColors.danger,
                ),
                tooltip: 'Supprimer',
                onPressed: _supprimer,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
