import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:sig_ensoa/core/erreurs.dart';
import 'package:sig_ensoa/core/theme.dart' hide AlertLevel, AlertLevelColor;
import '../../models/apprenant.dart';
import '../../models/classe.dart';
import '../../models/division.dart';
import 'data/locaux_disciplinaires_repository.dart';
import 'providers/locaux_disciplinaires_providers.dart';

/// Met quelqu'un aux locaux disciplinaires.
///
/// [classe] est nulle pour le personnel de l'école : il va aux arrêts comme
/// un élève, sans suivre de phase.
Future<void> showRegisterLocalDisciplinaireDialog(
  BuildContext context, {
  required Division division,
  required Classe? classe,
  required List<Apprenant> apprenants,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.all(24),
      child: _RegisterLocalDisciplinaireDialog(
        division: division,
        classe: classe,
        apprenants: apprenants,
      ),
    ),
  );
}

class _RegisterLocalDisciplinaireDialog extends ConsumerStatefulWidget {
  const _RegisterLocalDisciplinaireDialog({
    required this.division,
    required this.classe,
    required this.apprenants,
  });

  final Division division;
  final Classe? classe;
  final List<Apprenant> apprenants;

  @override
  ConsumerState<_RegisterLocalDisciplinaireDialog> createState() =>
      _RegisterLocalDisciplinaireDialogState();
}

class _RegisterLocalDisciplinaireDialogState
    extends ConsumerState<_RegisterLocalDisciplinaireDialog> {
  final _joursCtrl = TextEditingController(text: '1');
  final _motifCtrl = TextEditingController();
  final _autoriteCtrl = TextEditingController();

  Apprenant? _apprenant;
  DateTime? _dateDebut = DateTime.now();
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _joursCtrl.addListener(() => setState(() {}));
    _motifCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _joursCtrl.dispose();
    _motifCtrl.dispose();
    _autoriteCtrl.dispose();
    super.dispose();
  }

  int? get _jours {
    final n = int.tryParse(_joursCtrl.text.trim());
    return (n != null && n > 0) ? n : null;
  }

  bool get _isValid =>
      _apprenant != null &&
      _dateDebut != null &&
      _jours != null &&
      _motifCtrl.text.trim().isNotEmpty;

  /// Le dernier jour de punition, pour que celui qui saisit voie tout de
  /// suite jusqu'à quand il met l'intéressé aux arrêts.
  String get _sortiePrevue {
    final debut = _dateDebut;
    final jours = _jours;
    if (debut == null || jours == null) return '—';
    final fin = DateTime(debut.year, debut.month, debut.day + jours - 1);
    return DateFormat('dd/MM/yyyy').format(fin);
  }

  Future<void> _submit() async {
    if (!_isValid) return;

    setState(() {
      _submitting = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(locauxDisciplinairesRepositoryProvider)
          .creer(
            LocalDisciplinaireDraft(
              apprenantId: _apprenant!.id,
              divisionId: widget.division.id,
              classeId: widget.classe?.id,
              dateDebut: _dateDebut!,
              jours: _jours!,
              motif: _motifCtrl.text.trim(),
              autorite: _autoriteCtrl.text.trim().isEmpty
                  ? null
                  : _autoriteCtrl.text.trim(),
            ),
          );
      final classe = widget.classe;
      if (classe != null) {
        ref.invalidate(locauxDisciplinairesByClasseProvider(classe.id));
      }
      ref.invalidate(
        locauxDisciplinairesByDivisionProvider(widget.division.id),
      );
      ref.invalidate(locauxDisciplinairesTousProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Mise aux arrêts enregistrée.'),
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
    final classe = widget.classe;

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
                    'Mettre aux locaux disciplinaires',
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
                          Icons.gavel_outlined,
                          size: 18,
                          color: AppColors.blueDeep,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            classe == null
                                ? 'Personnel · ${widget.division.nom}'
                                : '${classe.type == ClasseType.phase ? "Classe" : "Stage"} : '
                                      '${classe.nom} · ${widget.division.nom}',
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
                  DropdownButtonFormField<Apprenant>(
                    initialValue: _apprenant,
                    decoration: InputDecoration(
                      labelText: classe == null
                          ? 'Militaire'
                          : 'Élève / Stagiaire',
                    ),
                    isExpanded: true,
                    items: [
                      for (final a in widget.apprenants)
                        DropdownMenuItem(value: a, child: Text(a.nomComplet)),
                    ],
                    onChanged: (value) => setState(() => _apprenant = value),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _DatePickerField(
                          label: 'Date d\'entrée',
                          value: _dateDebut,
                          onChanged: (v) => setState(() => _dateDebut = v),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _joursCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Jours infligés',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Le premier jour compte : sortie prévue le $_sortiePrevue.',
                    style: const TextStyle(
                      color: AppColors.inkMuted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _motifCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Motif',
                      hintText: 'Ce qui est reproché',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _autoriteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Autorité ayant puni (facultatif)',
                      hintText: 'Grade et nom, ou fonction',
                    ),
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
          firstDate: now.subtract(const Duration(days: 365)),
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
