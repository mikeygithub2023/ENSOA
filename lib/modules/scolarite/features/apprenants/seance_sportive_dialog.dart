import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sig_ensoa/core/erreurs.dart';
import 'package:sig_ensoa/core/theme.dart' hide AlertLevel, AlertLevelColor;
import '../../models/apprenant.dart';
import 'package:sig_ensoa/modules/scolarite/compat.dart';
import '../../models/sous_module.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/saisie_performance.dart';
import 'providers/controles_providers.dart';
import 'providers/sport_providers.dart';

String _formatNote(num value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(2);

String formatJour(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/${date.year}';

// --- Programmer une séance --------------------------------------------------

/// Ouvre le formulaire d'une séance : l'activité qu'elle fait passer et le
/// jour où elle a lieu.
///
/// Le nom est libre — « Cross de rentrée », « Test final » — pour distinguer
/// deux séances de la même activité. À défaut, le nom de l'activité suffit.
Future<void> showSeanceDialog(
  BuildContext context, {
  required String moduleSportId,
  ({SousModule sousModule, SeanceSportive seance})? existing,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: _SeanceDialog(moduleSportId: moduleSportId, existing: existing),
    ),
  );
}

class _SeanceDialog extends ConsumerStatefulWidget {
  const _SeanceDialog({required this.moduleSportId, this.existing});

  final String moduleSportId;
  final ({SousModule sousModule, SeanceSportive seance})? existing;

  @override
  ConsumerState<_SeanceDialog> createState() => _SeanceDialogState();
}

class _SeanceDialogState extends ConsumerState<_SeanceDialog> {
  late final TextEditingController _nomCtrl;
  String? _activiteId;
  late DateTime _date;
  bool _submitting = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nomCtrl = TextEditingController(
      text: widget.existing?.sousModule.nom ?? '',
    );
    _activiteId = widget.existing?.seance.activiteId;
    _date = widget.existing?.seance.dateSeance ?? DateTime.now();
    _nomCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    super.dispose();
  }

  bool get _isValid => _activiteId != null && _nomCtrl.text.trim().isNotEmpty;

  Future<void> _submit() async {
    if (!_isValid) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final repo = ref.read(sportRepositoryProvider);
      if (_isEdit) {
        await repo.updateSeance(
          sousModuleId: widget.existing!.sousModule.id,
          activiteId: _activiteId!,
          nom: _nomCtrl.text.trim(),
          dateSeance: _date,
        );
      } else {
        await repo.createSeance(
          moduleSportId: widget.moduleSportId,
          activiteId: _activiteId!,
          nom: _nomCtrl.text.trim(),
          dateSeance: _date,
        );
      }
      ref.invalidate(seancesSportivesProvider(widget.moduleSportId));
      ref.invalidate(notesByControleProvider(widget.moduleSportId));
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = messageErreur(e);
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activitesAsync = ref.watch(activitesSportivesProvider);

    return SizedBox(
      width: 460,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEdit ? 'Modifier la séance' : 'Programmer une séance',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 20),
            activitesAsync.when(
              data: (activites) {
                if (activites.isEmpty) {
                  return const Text(
                    'Aucune activité sportive au catalogue. Créez-en une '
                    'dans Matières › Activités sportives, avec son barème, '
                    'avant de programmer une séance.',
                    style: TextStyle(color: AppColors.inkMuted, fontSize: 13),
                  );
                }
                return DropdownButtonFormField<String>(
                  initialValue: activites.any((a) => a.id == _activiteId)
                      ? _activiteId
                      : null,
                  decoration: const InputDecoration(labelText: 'Activité'),
                  isExpanded: true,
                  items: [
                    for (final activite in activites)
                      DropdownMenuItem(
                        value: activite.id,
                        child: Text(activite.nom),
                      ),
                  ],
                  onChanged: (value) => setState(() {
                    _activiteId = value;
                    // Le nom de la séance suit l'activité tant qu'on ne l'a
                    // pas écrit soi-même : le cas courant est « une séance,
                    // une activité ».
                    if (_nomCtrl.text.trim().isEmpty && value != null) {
                      _nomCtrl.text = activites
                          .firstWhere((a) => a.id == value)
                          .nom;
                    }
                  }),
                );
              },
              loading: () => const Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              error: (error, _) => Text(
                'Activités illisibles : ${messageErreur(error)}',
                style: const TextStyle(color: AppColors.danger, fontSize: 13),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nomCtrl,
              decoration: const InputDecoration(
                labelText: 'Nom de la séance',
                hintText: 'Ex. : Cross de rentrée',
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () async {
                final choisie = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (choisie != null) setState(() => _date = choisie);
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date de la séance',
                ),
                child: Text(formatJour(_date)),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.danger, fontSize: 13),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _submitting
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Annuler'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _isValid && !_submitting ? _submit : null,
                  child: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_isEdit ? 'Enregistrer' : 'Programmer'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// --- Saisir les performances d'une séance -----------------------------------

/// Ouvre la feuille de séance : un apprenant par ligne, sa performance et
/// la note que le barème de l'activité lui donne.
Future<void> showFeuilleSeanceDialog(
  BuildContext context, {
  required SousModule sousModule,
  required ActiviteSportive activite,
  required SeanceSportive seance,
  required List<Apprenant> apprenants,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.all(24),
      child: _FeuilleSeance(
        sousModule: sousModule,
        activite: activite,
        seance: seance,
        apprenants: apprenants,
      ),
    ),
  );
}

class _FeuilleSeance extends ConsumerWidget {
  const _FeuilleSeance({
    required this.sousModule,
    required this.activite,
    required this.seance,
    required this.apprenants,
  });

  final SousModule sousModule;
  final ActiviteSportive activite;
  final SeanceSportive seance;
  final List<Apprenant> apprenants;

  void _rafraichir(WidgetRef ref) {
    ref.invalidate(performancesSeanceProvider(sousModule.id));
    ref.invalidate(notesByControleProvider(sousModule.moduleId));
  }

  /// Suppression directe — réservée à l'administrateur. Sert aussi à
  /// confirmer une demande faite par un autre profil.
  Future<void> _supprimer(
    BuildContext context,
    WidgetRef ref,
    PerformanceSportive performance,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(
          performance.suppressionDemandee
              ? 'Confirmer la suppression'
              : 'Supprimer la performance',
        ),
        content: Text(
          performance.suppressionDemandee
              ? 'Une suppression a été demandée pour cette performance. '
                    'Confirmer la suppression définitive ? La note qu\'elle a '
                    'produite part avec elle.'
              : 'Voulez-vous vraiment supprimer cette performance ? La note '
                    'qu\'elle a produite part avec elle.',
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
      await ref
          .read(sportRepositoryProvider)
          .supprimerPerformance(performance.id);
      _rafraichir(ref);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Performance supprimée.'),
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

  /// Un profil non-administrateur ne supprime pas : il demande, et tous
  /// les administrateurs en sont notifiés.
  Future<void> _demanderSuppression(
    BuildContext context,
    WidgetRef ref,
    PerformanceSportive performance,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Demander la suppression'),
        content: const Text(
          'La suppression de cette performance sera soumise à un '
          'administrateur pour validation. Continuer ?',
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
    if (confirme != true) return;
    try {
      await ref
          .read(sportRepositoryProvider)
          .demanderSuppressionPerformance(
            sousModuleId: sousModule.id,
            apprenantId: performance.apprenantId,
          );
      _rafraichir(ref);
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

  /// L'administrateur rejette une demande : la performance est conservée.
  Future<void> _rejeterDemande(
    BuildContext context,
    WidgetRef ref,
    PerformanceSportive performance,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(sportRepositoryProvider)
          .annulerDemandeSuppression(
            sousModuleId: sousModule.id,
            apprenantId: performance.apprenantId,
          );
      _rafraichir(ref);
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taille = MediaQuery.of(context).size;
    final isAdmin =
        ref.watch(currentProfileProvider).value?.role == AppRole.admin;
    final performancesAsync = ref.watch(
      performancesSeanceProvider(sousModule.id),
    );

    return SizedBox(
      width: taille.width - 96 < 820 ? taille.width - 96 : 820,
      height: taille.height - 140,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 12, 0),
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
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      Text(
                        '${activite.nom} · ${formatJour(seance.dateSeance)} · '
                        '${activite.unite.label}',
                        style: const TextStyle(
                          color: AppColors.inkMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          if ((activite.consigne ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.blueMist,
                  borderRadius: BorderRadius.circular(AppRadii.control),
                ),
                child: Text(
                  activite.consigne!,
                  style: const TextStyle(
                    color: AppColors.inkMuted,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          Expanded(
            child: performancesAsync.when(
              data: (performances) {
                final parApprenant = {
                  for (final p in performances) p.apprenantId: p,
                };
                final tries = [...apprenants]
                  ..sort((a, b) {
                    final nom = a.nom.toLowerCase().compareTo(
                      b.nom.toLowerCase(),
                    );
                    return nom != 0
                        ? nom
                        : a.prenom.toLowerCase().compareTo(
                            b.prenom.toLowerCase(),
                          );
                  });

                if (tries.isEmpty) {
                  return const EmptyState(
                    message: 'Aucun apprenant dans cette phase.',
                    icon: Icons.groups_outlined,
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(24),
                  itemCount: tries.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final apprenant = tries[index];
                    final performance = parApprenant[apprenant.id];
                    return _LigneApprenant(
                      key: ValueKey(apprenant.id),
                      apprenant: apprenant,
                      activite: activite,
                      performance: performance,
                      onSaisir: () => showPerformanceDialog(
                        context,
                        sousModule: sousModule,
                        activite: activite,
                        apprenant: apprenant,
                        existing: performance,
                      ),
                      isAdmin: isAdmin,
                      onSupprimer: performance == null
                          ? null
                          : isAdmin
                          ? () => _supprimer(context, ref, performance)
                          : () =>
                                _demanderSuppression(context, ref, performance),
                      onRejeterDemande:
                          performance != null &&
                              isAdmin &&
                              performance.suppressionDemandee
                          ? () => _rejeterDemande(context, ref, performance)
                          : null,
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => EmptyState(
                message: 'Erreur de chargement : ${messageErreur(error)}',
                icon: Icons.error_outline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LigneApprenant extends StatelessWidget {
  const _LigneApprenant({
    super.key,
    required this.apprenant,
    required this.activite,
    required this.performance,
    required this.onSaisir,
    required this.onSupprimer,
    required this.isAdmin,
    required this.onRejeterDemande,
  });

  final Apprenant apprenant;
  final ActiviteSportive activite;

  final PerformanceSportive? performance;
  final VoidCallback onSaisir;

  /// Supprime pour un administrateur, demande la suppression pour les
  /// autres — comme partout ailleurs pour une note.
  final VoidCallback? onSupprimer;

  final bool isAdmin;

  /// Renseigné pour un administrateur devant une demande en attente.
  final VoidCallback? onRejeterDemande;

  @override
  Widget build(BuildContext context) {
    final perf = performance;
    final sexeConnu = (apprenant.sexe ?? '').isNotEmpty;

    return Material(
      color: AppColors.blueMist,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        apprenant.nomComplet,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if (perf != null && perf.noteModifiee) ...[
                        const SizedBox(width: 8),
                        Tooltip(
                          message:
                              'Note précédente : '
                              '${_formatNote(perf.notePrecedente!)} / 20',
                          child: const StatusChip(
                            label: 'Note modifiée',
                            level: AlertLevel.warning,
                          ),
                        ),
                      ],
                      if (perf != null && perf.suppressionDemandee) ...[
                        const SizedBox(width: 8),
                        Tooltip(
                          message:
                              'Suppression demandée le '
                              '${formatJour(perf.suppressionDemandeeLe!)}',
                          child: const StatusChip(
                            label: 'Suppression demandée',
                            level: AlertLevel.critical,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    perf == null
                        ? 'Aucune performance enregistrée.'
                        : activite.unite.formater(perf.valeur),
                    style: const TextStyle(
                      color: AppColors.inkMuted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (!sexeConnu)
              const Tooltip(
                message:
                    'Sexe non renseigné : aucun barème ne peut s\'appliquer.',
                child: StatusChip(
                  label: 'Sexe manquant',
                  level: AlertLevel.warning,
                ),
              )
            else if (perf != null)
              // Une performance en deçà du dernier palier vaut zéro, pas
              // une absence de note (migration 061). Il ne reste donc qu'un
              // cas sans note : l'activité n'a aucun palier pour ce sexe.
              Tooltip(
                message: perf.noteConnue
                    ? ''
                    : 'Aucun palier n\'est défini pour ce sexe dans '
                          '${activite.nom} : la performance ne peut pas être '
                          'notée.',
                child: StatusChip(
                  label: perf.noteConnue
                      ? '${_formatNote(perf.note!)} / 20'
                      : 'Sans barème',
                  level: perf.noteConnue ? AlertLevel.info : AlertLevel.warning,
                ),
              ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(
                perf == null ? Icons.add : Icons.edit_outlined,
                size: 18,
              ),
              tooltip: perf == null
                  ? 'Saisir la performance'
                  : 'Modifier la performance',
              onPressed: onSaisir,
            ),
            if (onRejeterDemande != null)
              IconButton(
                icon: const Icon(Icons.undo, size: 18),
                tooltip: 'Rejeter la demande de suppression',
                onPressed: onRejeterDemande,
              ),
            IconButton(
              icon: Icon(
                isAdmin ? Icons.delete_outline : Icons.delete_sweep_outlined,
                size: 18,
                color: AppColors.danger,
              ),
              tooltip: isAdmin
                  ? (perf != null && perf.suppressionDemandee
                        ? 'Confirmer la suppression'
                        : 'Supprimer')
                  : 'Demander la suppression',
              onPressed: onSupprimer,
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showPerformanceDialog(
  BuildContext context, {
  required SousModule sousModule,
  required ActiviteSportive activite,
  required Apprenant apprenant,
  PerformanceSportive? existing,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: _PerformanceDialog(
        sousModule: sousModule,
        activite: activite,
        apprenant: apprenant,
        existing: existing,
      ),
    ),
  );
}

class _PerformanceDialog extends ConsumerStatefulWidget {
  const _PerformanceDialog({
    required this.sousModule,
    required this.activite,
    required this.apprenant,
    this.existing,
  });

  final SousModule sousModule;
  final ActiviteSportive activite;
  final Apprenant apprenant;
  final PerformanceSportive? existing;

  @override
  ConsumerState<_PerformanceDialog> createState() => _PerformanceDialogState();
}

class _PerformanceDialogState extends ConsumerState<_PerformanceDialog> {
  late final TextEditingController _observationsCtrl;

  /// La performance en unité de base — c'est [SaisiePerformance] qui la
  /// compose, à partir des minutes et des secondes pour une épreuve
  /// chronométrée.
  num? _valeur;

  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _valeur = widget.existing?.valeur;
    _observationsCtrl = TextEditingController(
      text: widget.existing?.observations ?? '',
    );
  }

  @override
  void dispose() {
    _observationsCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final valeur = _valeur;
    if (valeur == null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final observations = _observationsCtrl.text.trim();
      await ref
          .read(sportRepositoryProvider)
          .enregistrerPerformance(
            sousModuleId: widget.sousModule.id,
            apprenantId: widget.apprenant.id,
            valeur: valeur,
            observations: observations.isEmpty ? null : observations,
          );
      ref.invalidate(performancesSeanceProvider(widget.sousModule.id));
      ref.invalidate(notesByControleProvider(widget.sousModule.moduleId));
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = messageErreur(e);
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final unite = widget.activite.unite;
    final sexeConnu = (widget.apprenant.sexe ?? '').isNotEmpty;

    return SizedBox(
      width: 460,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.apprenant.nomComplet,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.sousModule.nom} · ${widget.activite.nom}',
              style: const TextStyle(color: AppColors.inkMuted, fontSize: 13),
            ),
            // Sans sexe renseigné, aucun barème ne s'applique : la
            // performance sera enregistrée mais ne donnera pas de note.
            if (!sexeConnu) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.blueMist,
                  borderRadius: BorderRadius.circular(AppRadii.control),
                ),
                child: const Text(
                  'Le sexe de cet apprenant n\'est pas renseigné : aucun '
                  'barème ne peut s\'appliquer, la performance restera sans '
                  'note tant que sa fiche ne le précise pas.',
                  style: TextStyle(color: AppColors.inkMuted, fontSize: 12),
                ),
              ),
            ],
            const SizedBox(height: 20),
            SaisiePerformance(
              unite: unite,
              initial: widget.existing?.valeur,
              autofocus: true,
              onChanged: (valeur) => setState(() => _valeur = valeur),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _observationsCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Observations (facultatif)',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.danger, fontSize: 13),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _submitting
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Annuler'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _valeur != null && !_submitting ? _submit : null,
                  child: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Enregistrer'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
