import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sig_ensoa/core/erreurs.dart';
import 'package:sig_ensoa/core/theme.dart' hide AlertLevel, AlertLevelColor;
import '../../models/sous_module.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/saisie_performance.dart';
import '../apprenants/providers/sport_providers.dart';

/// Le catalogue des activités sportives de l'école, avec leur barème.
///
/// Il vit ici, à côté du catalogue des matières, parce qu'il en est le
/// pendant : une activité se paramètre une fois — son unité, son sens, ses
/// paliers par sexe — puis chaque phase la convoque autant de fois qu'elle
/// veut par des séances. Le barème du 3000 mètres ne se ressaisit pas à
/// chaque promotion.
class ActivitesSportivesTab extends ConsumerWidget {
  const ActivitesSportivesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activitesAsync = ref.watch(activitesSportivesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: SectionHeader(title: 'Activités sportives')),
            FilledButton.icon(
              onPressed: () => showActiviteDialog(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Ajouter une activité'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Chaque activité porte son barème, par sexe. Les séances des '
          'modules Sport y puisent : la performance saisie devient une note '
          'par lecture de ce barème.',
          style: TextStyle(color: AppColors.inkMuted, fontSize: 13),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: activitesAsync.when(
            data: (activites) {
              if (activites.isEmpty) {
                return const EmptyState(
                  message:
                      'Aucune activité sportive.\nCréez-en une pour pouvoir '
                      'programmer des séances.',
                  icon: Icons.directions_run_outlined,
                );
              }
              return ListView.separated(
                itemCount: activites.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) => _ActiviteCard(
                  key: ValueKey(activites[index].id),
                  activite: activites[index],
                ),
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
    );
  }
}

String _formatNombre(num value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(2);

/// Un palier est un seuil, et se lit comme tel : « moins de 24′00″ » pour
/// une épreuve chronométrée, « 15 rép. et plus » pour une épreuve où la
/// plus grande valeur l'emporte.
///
/// L'asymétrie est celle des barèmes eux-mêmes : « moins de 24 minutes »
/// exclut 24, « 15 tractions et plus » inclut 15.
String seuilLabel(ActiviteSportive activite, num seuil) {
  final valeur = activite.unite.formater(seuil);
  return activite.meilleur == SensEpreuve.minimum ? '< $valeur' : '≥ $valeur';
}

class _ActiviteCard extends ConsumerWidget {
  const _ActiviteCard({super.key, required this.activite});

  final ActiviteSportive activite;

  Future<void> _supprimer(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Supprimer l\'activité'),
        content: Text(
          'Voulez-vous vraiment supprimer « ${activite.nom} » ? Son barème '
          'part avec elle. Une activité déjà convoquée par une séance ne '
          'peut pas être supprimée : les notes calculées deviendraient '
          'inexplicables.',
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
      await ref.read(sportRepositoryProvider).deleteActivite(activite.id);
      ref.invalidate(activitesSportivesProvider);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Activité supprimée.'),
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
    final baremeAsync = ref.watch(baremeActiviteProvider(activite.id));

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                      activite.nom,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${activite.unite.label} · ${activite.meilleur.label}',
                      style: const TextStyle(
                        color: AppColors.inkMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                tooltip: 'Modifier',
                onPressed: () =>
                    showActiviteDialog(context, existing: activite),
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: AppColors.danger,
                ),
                tooltip: 'Supprimer',
                onPressed: () => _supprimer(context, ref),
              ),
            ],
          ),
          if ((activite.consigne ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              activite.consigne!,
              style: const TextStyle(color: AppColors.inkMuted, fontSize: 12),
            ),
          ],
          const SizedBox(height: 12),
          baremeAsync.when(
            data: (paliers) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final sexe in const ['M', 'F']) ...[
                  _BaremeLigne(
                    activite: activite,
                    sexe: sexe,
                    paliers: paliers.where((p) => p.sexe == sexe).toList(),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
            loading: () => const Padding(
              padding: EdgeInsets.all(8),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (error, _) => Text(
              'Barème illisible : ${messageErreur(error)}',
              style: const TextStyle(color: AppColors.danger, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _BaremeLigne extends ConsumerWidget {
  const _BaremeLigne({
    required this.activite,
    required this.sexe,
    required this.paliers,
  });

  final ActiviteSportive activite;
  final String sexe;
  final List<BaremePalier> paliers;

  Future<void> _supprimerPalier(
    BuildContext context,
    WidgetRef ref,
    BaremePalier palier,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(sportRepositoryProvider).supprimerPalier(palier.id);
      ref.invalidate(baremeActiviteProvider(activite.id));
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Palier supprimé.'),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 76,
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              sexe == 'M' ? 'Hommes' : 'Femmes',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: AppColors.inkMuted,
              ),
            ),
          ),
        ),
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (paliers.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    'Aucun palier — les performances de ce sexe resteront '
                    'sans note.',
                    style: TextStyle(color: AppColors.inkMuted, fontSize: 12),
                  ),
                )
              else
                for (final palier in paliers)
                  InputChip(
                    key: ValueKey(palier.id),
                    label: Text(
                      '${seuilLabel(activite, palier.performance)} → '
                      '${_formatNombre(palier.note)}/20',
                    ),
                    onPressed: () => showPalierDialog(
                      context,
                      activite: activite,
                      sexe: sexe,
                      existing: palier,
                    ),
                    onDeleted: () => _supprimerPalier(context, ref, palier),
                  ),
              ActionChip(
                avatar: const Icon(Icons.add, size: 16),
                label: const Text('Palier'),
                onPressed: () =>
                    showPalierDialog(context, activite: activite, sexe: sexe),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// --- Formulaire d'une activité ----------------------------------------------

Future<void> showActiviteDialog(
  BuildContext context, {
  ActiviteSportive? existing,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: _ActiviteDialog(existing: existing),
    ),
  );
}

class _ActiviteDialog extends ConsumerStatefulWidget {
  const _ActiviteDialog({this.existing});

  final ActiviteSportive? existing;

  @override
  ConsumerState<_ActiviteDialog> createState() => _ActiviteDialogState();
}

class _ActiviteDialogState extends ConsumerState<_ActiviteDialog> {
  late final TextEditingController _nomCtrl;
  late final TextEditingController _consigneCtrl;
  late UniteEpreuve _unite;
  late SensEpreuve _meilleur;
  bool _submitting = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nomCtrl = TextEditingController(text: widget.existing?.nom ?? '');
    _consigneCtrl = TextEditingController(
      text: widget.existing?.consigne ?? '',
    );
    _unite = widget.existing?.unite ?? UniteEpreuve.secondes;
    _meilleur = widget.existing?.meilleur ?? SensEpreuve.minimum;
    _nomCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    _consigneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nomCtrl.text.trim().isEmpty) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final repo = ref.read(sportRepositoryProvider);
      final consigne = _consigneCtrl.text.trim();
      if (_isEdit) {
        await repo.updateActivite(
          activiteId: widget.existing!.id,
          nom: _nomCtrl.text.trim(),
          unite: _unite,
          meilleur: _meilleur,
          consigne: consigne.isEmpty ? null : consigne,
        );
      } else {
        await repo.createActivite(
          nom: _nomCtrl.text.trim(),
          unite: _unite,
          meilleur: _meilleur,
          consigne: consigne.isEmpty ? null : consigne,
        );
      }
      ref.invalidate(activitesSportivesProvider);
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
    return SizedBox(
      width: 480,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEdit ? 'Modifier l\'activité' : 'Ajouter une activité',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nomCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Nom de l\'activité',
                hintText: 'Ex. : 3000 mètres',
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<UniteEpreuve>(
              isExpanded: true,
              initialValue: _unite,
              decoration: const InputDecoration(labelText: 'Unité de mesure'),
              items: [
                for (final unite in UniteEpreuve.values)
                  DropdownMenuItem(value: unite, child: Text(unite.label)),
              ],
              onChanged: (value) => setState(() => _unite = value ?? _unite),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<SensEpreuve>(
              isExpanded: true,
              initialValue: _meilleur,
              decoration: const InputDecoration(
                labelText: 'Sens de l\'activité',
              ),
              items: [
                for (final sens in SensEpreuve.values)
                  DropdownMenuItem(value: sens, child: Text(sens.label)),
              ],
              onChanged: (value) =>
                  setState(() => _meilleur = value ?? _meilleur),
            ),
            const SizedBox(height: 8),
            const Text(
              'Au 3000 mètres la meilleure performance est la plus petite ; '
              'à la traction la plus grande.',
              style: TextStyle(color: AppColors.inkMuted, fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _consigneCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Consigne (facultatif)',
                hintText:
                    'Les conditions de l\'activité, telles qu\'on les '
                    'dicte avant le départ.',
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
                  onPressed: _nomCtrl.text.trim().isNotEmpty && !_submitting
                      ? _submit
                      : null,
                  child: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_isEdit ? 'Enregistrer' : 'Ajouter'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// --- Formulaire d'un palier -------------------------------------------------

Future<void> showPalierDialog(
  BuildContext context, {
  required ActiviteSportive activite,
  required String sexe,
  BaremePalier? existing,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: _PalierDialog(activite: activite, sexe: sexe, existing: existing),
    ),
  );
}

class _PalierDialog extends ConsumerStatefulWidget {
  const _PalierDialog({
    required this.activite,
    required this.sexe,
    this.existing,
  });

  final ActiviteSportive activite;
  final String sexe;
  final BaremePalier? existing;

  @override
  ConsumerState<_PalierDialog> createState() => _PalierDialogState();
}

class _PalierDialogState extends ConsumerState<_PalierDialog> {
  late final TextEditingController _noteCtrl;

  /// Le palier se saisit dans l'unité de l'activité — donc en minutes et
  /// secondes pour une épreuve chronométrée, comme la performance qu'il
  /// sert à noter.
  num? _performance;

  bool _submitting = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _performance = widget.existing?.performance;
    _noteCtrl = TextEditingController(
      text: widget.existing == null ? '' : _formatNombre(widget.existing!.note),
    );
    _noteCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  num? get _note {
    final text = _noteCtrl.text.trim().replaceAll(',', '.');
    if (text.isEmpty) return null;
    final value = num.tryParse(text);
    return value == null || value < 0 || value > 20 ? null : value;
  }

  bool get _isValid => _performance != null && _note != null;

  Future<void> _submit() async {
    if (!_isValid) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final repo = ref.read(sportRepositoryProvider);
      if (_isEdit) {
        await repo.modifierPalier(
          palierId: widget.existing!.id,
          performance: _performance!,
          note: _note!,
        );
      } else {
        await repo.ajouterPalier(
          activiteId: widget.activite.id,
          sexe: widget.sexe,
          performance: _performance!,
          note: _note!,
        );
      }
      // Le barème changé, les notes déjà calculées ne valent plus : la base
      // les refait (migration 056), l'écran les relit.
      ref.invalidate(baremeActiviteProvider(widget.activite.id));
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
    return SizedBox(
      width: 420,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEdit ? 'Modifier le palier' : 'Ajouter un palier',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.activite.nom} · '
              '${widget.sexe == 'M' ? 'hommes' : 'femmes'}',
              style: const TextStyle(color: AppColors.inkMuted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.blueMist,
                borderRadius: BorderRadius.circular(AppRadii.control),
              ),
              child: Text(
                widget.activite.meilleur == SensEpreuve.minimum
                    ? 'Un seuil : toute performance STRICTEMENT INFÉRIEURE à '
                          'cette valeur, et qui ne passe aucun seuil plus '
                          'serré, reçoit cette note.'
                    : 'Un seuil : toute performance ÉGALE OU SUPÉRIEURE à '
                          'cette valeur, et qui n\'atteint aucun seuil plus '
                          'exigeant, reçoit cette note.',
                style: const TextStyle(color: AppColors.inkMuted, fontSize: 12),
              ),
            ),
            const SizedBox(height: 20),
            SaisiePerformance(
              unite: unite,
              initial: widget.existing?.performance,
              autofocus: true,
              onChanged: (valeur) => setState(() => _performance = valeur),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _noteCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Note sur 20'),
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
                      : Text(_isEdit ? 'Enregistrer' : 'Ajouter'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
