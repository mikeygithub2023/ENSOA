import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sig_ensoa/core/erreurs.dart';
import 'package:sig_ensoa/core/theme.dart' hide AlertLevel, AlertLevelColor;
import '../../models/controle.dart';
import '../../models/sous_module.dart';
import 'data/sous_modules_repository.dart';
import 'providers/sous_modules_providers.dart';

/// Ouvre le formulaire d'un sous-module — création si [existing] est nul,
/// modification sinon.
///
/// Le nom et le coefficient suffisent : un sous-module ordinaire reçoit sa
/// note par saisie. Le sport ne passe pas par ici — ses séances se
/// programment dans la rubrique Sport de la phase, et leur note vient du
/// barème de l'activité (voir `sport_section.dart`).
Future<void> showSousModuleDialog(
  BuildContext context, {
  required Controle module,
  SousModule? existing,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.all(24),
      child: _SousModuleDialog(module: module, existing: existing),
    ),
  );
}

class _SousModuleDialog extends ConsumerStatefulWidget {
  const _SousModuleDialog({required this.module, this.existing});

  final Controle module;
  final SousModule? existing;

  @override
  ConsumerState<_SousModuleDialog> createState() => _SousModuleDialogState();
}

class _SousModuleDialogState extends ConsumerState<_SousModuleDialog> {
  late final TextEditingController _nomCtrl;
  late final TextEditingController _coefCtrl;
  bool _submitting = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nomCtrl = TextEditingController(text: widget.existing?.nom ?? '');
    _coefCtrl = TextEditingController(
      text: widget.existing == null
          ? '1'
          : _formatCoef(widget.existing!.coefficient),
    );
    _nomCtrl.addListener(() => setState(() {}));
    _coefCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    _coefCtrl.dispose();
    super.dispose();
  }

  static String _formatCoef(num value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toString();

  /// Le coefficient est strictement positif : un sous-module de poids nul
  /// ne compterait pas, autant ne pas le créer (la base le refuse aussi).
  num? get _parsedCoef {
    final text = _coefCtrl.text.trim().replaceAll(',', '.');
    if (text.isEmpty) return null;
    final value = num.tryParse(text);
    if (value == null || value <= 0 || value > 99) return null;
    return value;
  }

  bool get _isValid => _nomCtrl.text.trim().isNotEmpty && _parsedCoef != null;

  Future<void> _submit() async {
    if (!_isValid) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final nom = _nomCtrl.text.trim();
    final coefficient = _parsedCoef!;
    try {
      final repo = ref.read(sousModulesRepositoryProvider);
      if (_isEdit) {
        await repo.updateSousModule(
          sousModuleId: widget.existing!.id,
          nom: nom,
          coefficient: coefficient,
        );
      } else {
        await repo.createSousModule(
          SousModuleDraft(
            moduleId: widget.module.id,
            nom: nom,
            coefficient: coefficient,
          ),
        );
      }
      ref.invalidate(sousModulesByModuleProvider(widget.module.id));
      ref.invalidate(sousModulesByClasseProvider(widget.module.classeId));
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _isEdit ? 'Sous-module modifié.' : 'Sous-module enregistré.',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Échec de l\'enregistrement : ${messageErreur(e)}';
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final width = screenSize.width - 48 < 480 ? screenSize.width - 48 : 480.0;

    return SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _isEdit
                        ? 'Modifier le sous-module'
                        : 'Ajouter un sous-module',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.blueMist,
                    borderRadius: BorderRadius.circular(AppRadii.control),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.grading_outlined,
                        size: 18,
                        color: AppColors.blueDeep,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.module.libelle,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.blueDeep,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _nomCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Nom du sous-module',
                    hintText: 'Ex. : Topographie',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _coefCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Coefficient',
                    helperText:
                        'Poids du sous-module dans la moyenne du module.',
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: AppColors.danger,
                      fontSize: 13,
                    ),
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
        ],
      ),
    );
  }
}
