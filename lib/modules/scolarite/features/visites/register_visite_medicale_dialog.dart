import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:sig_ensoa/core/erreurs.dart';
import 'package:sig_ensoa/core/theme.dart' hide AlertLevel, AlertLevelColor;
import '../../models/classe.dart';
import '../../models/visite_medicale.dart';
import 'data/visites_medicales_repository.dart';
import 'providers/visites_medicales_providers.dart';

/// Création (ou modification, si [visite] est fourni) d'une visite
/// médicale. On n'annonce ici que la campagne — titre, classe/stage
/// convoquée, date et type ; les apprenants y sont ajoutés ensuite, un à
/// un, depuis la fiche de la visite.
Future<void> showRegisterVisiteMedicaleDialog(
  BuildContext context, {
  required List<Classe> classes,
  VisiteMedicale? visite,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.all(24),
      child: _RegisterVisiteMedicaleDialog(classes: classes, visite: visite),
    ),
  );
}

class _RegisterVisiteMedicaleDialog extends ConsumerStatefulWidget {
  const _RegisterVisiteMedicaleDialog({
    required this.classes,
    required this.visite,
  });

  final List<Classe> classes;
  final VisiteMedicale? visite;

  @override
  ConsumerState<_RegisterVisiteMedicaleDialog> createState() =>
      _RegisterVisiteMedicaleDialogState();
}

class _RegisterVisiteMedicaleDialogState
    extends ConsumerState<_RegisterVisiteMedicaleDialog> {
  late final _titreCtrl = TextEditingController(
    text: widget.visite?.titre ?? '',
  );
  late Classe? _classe = _initialClasse();
  late DateTime? _dateVisite = widget.visite?.dateVisite ?? DateTime.now();
  late VisiteType _type = widget.visite?.type ?? VisiteType.periodique;
  bool _submitting = false;
  String? _error;

  bool get _isEdition => widget.visite != null;

  bool get _isValid =>
      _titreCtrl.text.trim().isNotEmpty &&
      _classe != null &&
      _dateVisite != null;

  Classe? _initialClasse() {
    final visite = widget.visite;
    if (visite == null) return null;
    for (final classe in widget.classes) {
      if (classe.id == visite.classeId) return classe;
    }
    return null;
  }

  @override
  void dispose() {
    _titreCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final classe = _classe;
    final dateVisite = _dateVisite;
    if (classe == null || dateVisite == null) return;

    setState(() {
      _submitting = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(visitesMedicalesRepositoryProvider);
    final draft = VisiteMedicaleDraft(
      titre: _titreCtrl.text.trim(),
      divisionId: classe.divisionId,
      classeId: classe.id,
      dateVisite: dateVisite,
      type: _type,
    );
    try {
      final visite = widget.visite;
      if (visite == null) {
        await repository.createVisite(draft);
      } else {
        await repository.updateVisite(visite.id, draft);
        ref.invalidate(visiteMedicaleByIdProvider(visite.id));
      }
      ref.invalidate(visitesMedicalesProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _isEdition ? 'Visite médicale modifiée.' : 'Visite médicale créée.',
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
    final screenSize = MediaQuery.of(context).size;
    final width = screenSize.width - 48 < 560 ? screenSize.width - 48 : 560.0;

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
                    _isEdition
                        ? 'Modifier la visite médicale'
                        : 'Nouvelle visite médicale',
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
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _titreCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Titre de la visite',
                      hintText: 'Ex. Visite d\'incorporation FCB 2026',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<Classe>(
                    initialValue: _classe,
                    decoration: const InputDecoration(
                      labelText: 'Classe / Stage concerné(e)',
                    ),
                    isExpanded: true,
                    items: [
                      for (final classe in widget.classes)
                        DropdownMenuItem(
                          value: classe,
                          child: Text('${classe.nom} (${classe.type.label})'),
                        ),
                    ],
                    onChanged: (value) => setState(() => _classe = value),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _DatePickerField(
                          label: 'Date de la visite',
                          value: _dateVisite,
                          onChanged: (v) => setState(() => _dateVisite = v),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<VisiteType>(
                          initialValue: _type,
                          decoration: const InputDecoration(
                            labelText: 'Type de visite',
                          ),
                          isExpanded: true,
                          items: [
                            for (final type in VisiteType.values)
                              DropdownMenuItem(
                                value: type,
                                child: Text(type.label),
                              ),
                          ],
                          onChanged: (value) =>
                              setState(() => _type = value ?? _type),
                        ),
                      ),
                    ],
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

class _DatePickerField extends StatelessWidget {
  const _DatePickerField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? now,
          firstDate: DateTime(now.year - 5),
          lastDate: now.add(const Duration(days: 730)),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
        ),
        child: Text(
          value != null ? DateFormat('dd/MM/yyyy').format(value!) : '',
        ),
      ),
    );
  }
}
