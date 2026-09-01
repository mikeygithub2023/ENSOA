import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:sig_ensoa/core/erreurs.dart';
import 'package:sig_ensoa/core/theme.dart' hide AlertLevel, AlertLevelColor;
import '../../models/apprenant.dart';
import 'data/consultations_medicales_repository.dart';
import 'providers/consultations_medicales_providers.dart';

/// [apprenants] peut couvrir une classe/stage précis(e) ou toute une
/// division ("Toutes phases / stages") — la classe et la division de la
/// consultation sont dérivées de l'apprenant choisi, pas d'un filtre
/// externe, pour que ce bouton reste disponible quel que soit le filtre en
/// cours sur l'écran Consultations médicales.
Future<void> showRegisterConsultationDialog(
  BuildContext context, {
  required List<Apprenant> apprenants,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.all(24),
      child: _RegisterConsultationDialog(apprenants: apprenants),
    ),
  );
}

class _RegisterConsultationDialog extends ConsumerStatefulWidget {
  const _RegisterConsultationDialog({required this.apprenants});

  final List<Apprenant> apprenants;

  @override
  ConsumerState<_RegisterConsultationDialog> createState() =>
      _RegisterConsultationDialogState();
}

class _RegisterConsultationDialogState
    extends ConsumerState<_RegisterConsultationDialog> {
  Apprenant? _apprenant;
  DateTime? _dateSouhaitee = DateTime.now();
  bool _submitting = false;
  String? _error;

  bool get _isValid => _apprenant != null && _dateSouhaitee != null;

  Future<void> _submit() async {
    final apprenant = _apprenant;
    if (apprenant == null || _dateSouhaitee == null) return;
    final classeId = apprenant.classeId;
    if (classeId == null) {
      setState(
        () => _error =
            'Cet apprenant n\'est affecté à aucune phase ni aucun stage.',
      );
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(consultationsMedicalesRepositoryProvider)
          .createConsultation(
            ConsultationMedicaleDraft(
              apprenantId: apprenant.id,
              divisionId: apprenant.divisionId,
              classeId: classeId,
              dateSouhaitee: _dateSouhaitee!,
            ),
          );
      ref.invalidate(consultationsMedicalesByClasseProvider(classeId));
      ref.invalidate(
        consultationsMedicalesByDivisionProvider(apprenant.divisionId),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Consultation enregistrée.'),
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
                const Expanded(
                  child: Text(
                    'Enregistrer une consultation',
                    style: TextStyle(
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
                  _DatePickerField(
                    label: 'Date souhaitée',
                    value: _dateSouhaitee,
                    onChanged: (v) => setState(() => _dateSouhaitee = v),
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
          firstDate: now.subtract(const Duration(days: 30)),
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
