import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sig_ensoa/core/erreurs.dart';
import 'package:sig_ensoa/core/theme.dart' hide AlertLevel, AlertLevelColor;
import '../../models/apprenant.dart';
import '../../models/matiere.dart';
import '../../models/note.dart';
import '../../models/sous_module.dart';
import 'providers/controles_providers.dart';
import 'providers/sous_modules_providers.dart';

/// Ouvre le formulaire d'enregistrement d'une nouvelle note (apprenant au
/// choix parmi ceux qui n'en ont pas encore de note ici).
///
/// Une note se rattache à une [matiere] (contrôle continu, examen) ou à un
/// [sousModule] (module), jamais aux deux : c'est la règle posée par la
/// migration 051, et l'appelant en fournit exactement un.
Future<void> showRegisterNoteDialog(
  BuildContext context, {
  required String controleId,
  required Matiere? matiere,
  required List<Apprenant> apprenants,
  SousModule? sousModule,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.all(24),
      child: _NoteDialog(
        controleId: controleId,
        matiere: matiere,
        sousModule: sousModule,
        apprenants: apprenants,
      ),
    ),
  );
}

/// Ouvre le formulaire de modification de la note d'un apprenant déjà noté.
Future<void> showEditNoteDialog(
  BuildContext context, {
  required String controleId,
  required Matiere? matiere,
  required Apprenant apprenant,
  required Note existing,
  SousModule? sousModule,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.all(24),
      child: _NoteDialog(
        controleId: controleId,
        matiere: matiere,
        sousModule: sousModule,
        apprenants: [apprenant],
        fixedApprenant: apprenant,
        existing: existing,
      ),
    ),
  );
}

class _NoteDialog extends ConsumerStatefulWidget {
  const _NoteDialog({
    required this.controleId,
    required this.matiere,
    required this.apprenants,
    this.sousModule,
    this.fixedApprenant,
    this.existing,
  });

  final String controleId;
  final Matiere? matiere;
  final SousModule? sousModule;
  final List<Apprenant> apprenants;
  final Apprenant? fixedApprenant;
  final Note? existing;

  @override
  ConsumerState<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends ConsumerState<_NoteDialog> {
  late final TextEditingController _noteCtrl;
  Apprenant? _apprenant;
  bool _submitting = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _apprenant = widget.fixedApprenant;
    _noteCtrl = TextEditingController(
      text: widget.existing != null ? _formatNote(widget.existing!.note) : '',
    );
    _noteCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  String _formatNote(num value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toString();
  }

  num? get _parsedNote {
    final text = _noteCtrl.text.trim().replaceAll(',', '.');
    if (text.isEmpty) return null;
    final value = num.tryParse(text);
    if (value == null || value < 0 || value > 20) return null;
    return value;
  }

  bool get _isValid => _apprenant != null && _parsedNote != null;

  Future<void> _submit() async {
    if (!_isValid) return;
    final note = _parsedNote!;

    setState(() {
      _submitting = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (_isEdit) {
        await ref
            .read(controlesRepositoryProvider)
            .updateNote(
              noteId: widget.existing!.id,
              newNote: note,
              previousNote: widget.existing!.note,
            );
      } else {
        await ref
            .read(controlesRepositoryProvider)
            .createNote(
              controleId: widget.controleId,
              apprenantId: _apprenant!.id,
              matiereId: widget.matiere?.id,
              sousModuleId: widget.sousModule?.id,
              note: note,
            );
      }
      ref.invalidate(notesByControleProvider(widget.controleId));
      final sousModule = widget.sousModule;
      if (sousModule != null) {
        ref.invalidate(sousModulesByModuleProvider(sousModule.moduleId));
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(_isEdit ? 'Note modifiée.' : 'Note enregistrée.'),
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
      messenger.showSnackBar(
        SnackBar(
          content: Text('Erreur : ${messageErreur(e)}'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  /// Ce sur quoi porte la note, rappelé en tête du formulaire : la matière
  /// ou le sous-module. Nul quand la note ne se rattache à rien de nommé.
  String? get _rattachement {
    final sousModule = widget.sousModule;
    if (sousModule != null) {
      return '${sousModule.nom} · coefficient ${sousModule.coefficient}';
    }
    return widget.matiere?.nom;
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final width = screenSize.width - 48 < 480 ? screenSize.width - 48 : 480.0;
    final rattachement = _rattachement;

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
                    _isEdit ? 'Modifier la note' : 'Enregistrer une note',
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
                if (rattachement != null) ...[
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
                        Icon(
                          widget.sousModule != null
                              ? Icons.segment_outlined
                              : Icons.menu_book_outlined,
                          size: 18,
                          color: AppColors.blueDeep,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            rattachement,
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
                ],
                if (widget.fixedApprenant != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      widget.fixedApprenant!.nomComplet,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  )
                else
                  DropdownButtonFormField<Apprenant>(
                    initialValue: _apprenant,
                    decoration: const InputDecoration(
                      labelText: 'Élève / Stagiaire',
                    ),
                    isExpanded: true,
                    items: [
                      for (final a in widget.apprenants)
                        DropdownMenuItem(value: a, child: Text(a.nomComplet)),
                    ],
                    onChanged: (value) => setState(() => _apprenant = value),
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
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: const TextStyle(color: AppColors.danger),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                TextButton(
                  onPressed: _submitting
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Annuler'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: (!_isValid || _submitting) ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Enregistrer'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
