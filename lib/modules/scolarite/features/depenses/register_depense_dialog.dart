import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:sig_ensoa/core/erreurs.dart';
import 'package:sig_ensoa/core/theme.dart' hide AlertLevel, AlertLevelColor;
import '../../models/apprenant.dart';
import '../../models/consultation_medicale.dart';
import '../../models/depense.dart';
import '../apprenants/providers/apprenants_providers.dart';
import '../apprenants/providers/consultations_medicales_providers.dart';
import 'data/depenses_repository.dart';
import 'providers/depenses_providers.dart';

final _dateFmt = DateFormat('dd/MM/yyyy');

/// Saisie d'une dépense du volet médical. À la création, la nature de la
/// dépense (service ou consultation) est choisie en premier : elle
/// commande à la fois les postes proposés et le rattachement à un patient.
/// À la modification, ce rattachement est figé — le changer reviendrait à
/// créer une autre dépense.
Future<void> showRegisterDepenseDialog(
  BuildContext context, {
  required PeriodeDepenses periode,
  Depense? depense,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.all(24),
      child: _RegisterDepenseDialog(periode: periode, depense: depense),
    ),
  );
}

class _RegisterDepenseDialog extends ConsumerStatefulWidget {
  const _RegisterDepenseDialog({required this.periode, this.depense});

  final PeriodeDepenses periode;
  final Depense? depense;

  @override
  ConsumerState<_RegisterDepenseDialog> createState() =>
      _RegisterDepenseDialogState();
}

class _RegisterDepenseDialogState
    extends ConsumerState<_RegisterDepenseDialog> {
  late TypeDepense _type;
  late CategorieDepense _categorie;
  late DateTime _date;
  late final TextEditingController _libelleController;
  late final TextEditingController _montantController;
  late final TextEditingController _observationsController;

  Apprenant? _apprenant;
  String? _consultationId;
  bool _submitting = false;
  String? _error;

  bool get _edition => widget.depense != null;

  @override
  void initState() {
    super.initState();
    final depense = widget.depense;
    _type = depense?.type ?? TypeDepense.service;
    _categorie = depense?.categorie ?? categoriesPour(_type).first;
    _date = depense?.dateDepense ?? DateTime.now();
    _consultationId = depense?.consultationId;
    _libelleController = TextEditingController(text: depense?.libelle);
    _montantController = TextEditingController(
      text: depense?.montant.toString(),
    );
    _observationsController = TextEditingController(
      text: depense?.observations,
    );
  }

  @override
  void dispose() {
    _libelleController.dispose();
    _montantController.dispose();
    _observationsController.dispose();
    super.dispose();
  }

  void _changerType(TypeDepense type) {
    setState(() {
      _type = type;
      if (!_categorie.types.contains(type)) {
        _categorie = categoriesPour(type).first;
      }
      if (type == TypeDepense.service) {
        _apprenant = null;
        _consultationId = null;
      }
    });
  }

  Future<void> _submit() async {
    final libelle = _libelleController.text.trim();
    if (libelle.isEmpty) {
      setState(() => _error = 'Renseignez le libellé de la dépense.');
      return;
    }
    final montant = int.tryParse(_montantController.text.trim());
    if (montant == null || montant <= 0) {
      setState(() => _error = 'Le montant doit être un nombre supérieur à 0.');
      return;
    }
    if (_type == TypeDepense.consultation && _consultationId == null) {
      setState(
        () => _error = 'Choisissez la consultation à l\'origine de la dépense.',
      );
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(depensesRepositoryProvider);
    final draft = DepenseDraft(
      dateDepense: _date,
      type: _type,
      categorie: _categorie,
      libelle: libelle,
      montant: montant,
      observations: _texteOuNull(_observationsController),
      consultationId: _consultationId,
    );
    try {
      final depense = widget.depense;
      if (depense == null) {
        await repository.createDepense(draft);
      } else {
        await repository.updateDepense(depense.id, draft);
      }
      ref.invalidate(depensesProvider(widget.periode));
      if (_consultationId != null) {
        ref.invalidate(depensesByConsultationProvider(_consultationId!));
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            depense == null ? 'Dépense enregistrée.' : 'Dépense modifiée.',
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

  String? _texteOuNull(TextEditingController controller) {
    final texte = controller.text.trim();
    return texte.isEmpty ? null : texte;
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final width = screenSize.width - 48 < 600 ? screenSize.width - 48 : 600.0;
    final height = screenSize.height - 48 < 720
        ? screenSize.height - 48
        : 720.0;

    return SizedBox(
      width: width,
      height: height,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _edition ? 'Modifier la dépense' : 'Nouvelle dépense',
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
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Nature de la dépense',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<TypeDepense>(
                    segments: [
                      for (final type in TypeDepense.values)
                        ButtonSegment(value: type, label: Text(type.label)),
                    ],
                    selected: {_type},
                    // Le rattachement d'une dépense déjà enregistrée n'est
                    // plus modifiable : elle serait alors une autre dépense.
                    onSelectionChanged: _edition
                        ? null
                        : (selection) => _changerType(selection.first),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _type.description,
                    style: const TextStyle(
                      color: AppColors.inkMuted,
                      fontSize: 12,
                    ),
                  ),
                  if (_type == TypeDepense.consultation) ...[
                    const SizedBox(height: 16),
                    if (_edition)
                      _RattachementFige(depense: widget.depense!)
                    else
                      ..._champsConsultation(),
                  ],
                  const SizedBox(height: 16),
                  _DatePickerField(
                    label: 'Date de la dépense',
                    value: _date,
                    onChanged: (value) => setState(() => _date = value),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<CategorieDepense>(
                    initialValue: _categorie,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Poste'),
                    items: [
                      for (final categorie in categoriesPour(_type))
                        DropdownMenuItem(
                          value: categorie,
                          child: Text(categorie.label),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _categorie = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _libelleController,
                    decoration: const InputDecoration(
                      labelText: 'Libellé',
                      hintText: 'Ex. Achat de compresses stériles',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _montantController,
                    decoration: const InputDecoration(
                      labelText: 'Montant (FCFA)',
                      suffixText: 'FCFA',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _observationsController,
                    decoration: const InputDecoration(
                      labelText: 'Observations (facultatif)',
                    ),
                    maxLines: 2,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
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
                  onPressed: _submitting ? null : _submit,
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

  /// Sélection du patient puis de la consultation qui a motivé la dépense.
  /// Les consultations sont chargées par apprenant, donc seulement une fois
  /// celui-ci choisi.
  List<Widget> _champsConsultation() {
    final apprenantsAsync = ref.watch(apprenantsListProvider);

    return [
      apprenantsAsync.when(
        data: (apprenants) => DropdownButtonFormField<Apprenant>(
          initialValue: _apprenant,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Élève / Stagiaire'),
          items: [
            for (final apprenant in apprenants)
              DropdownMenuItem(
                value: apprenant,
                child: Text(apprenant.nomComplet),
              ),
          ],
          onChanged: (value) => setState(() {
            _apprenant = value;
            _consultationId = null;
          }),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Text(
          'Erreur de chargement des apprenants : $error',
          style: const TextStyle(color: AppColors.danger),
        ),
      ),
      if (_apprenant != null) ...[
        const SizedBox(height: 16),
        ref
            .watch(consultationsMedicalesByApprenantProvider(_apprenant!.id))
            .when(
              data: (consultations) => consultations.isEmpty
                  ? const Text(
                      'Cet apprenant n\'a aucune consultation enregistrée.',
                      style: TextStyle(color: AppColors.danger),
                    )
                  : DropdownButtonFormField<String>(
                      initialValue: _consultationId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Consultation à l\'origine de la dépense',
                      ),
                      items: [
                        for (final consultation in consultations)
                          DropdownMenuItem(
                            value: consultation.id,
                            child: Text(_libelleConsultation(consultation)),
                          ),
                      ],
                      onChanged: (value) =>
                          setState(() => _consultationId = value),
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Text(
                'Erreur de chargement des consultations : $error',
                style: const TextStyle(color: AppColors.danger),
              ),
            ),
      ],
    ];
  }

  String _libelleConsultation(ConsultationMedicale consultation) {
    return '${_dateFmt.format(consultation.dateSouhaitee)} — '
        '${consultation.type.label} (${consultation.statut.label})';
  }
}

/// Rappel du patient et de la consultation d'une dépense en cours de
/// modification — affiché tel quel, sans possibilité de le changer.
class _RattachementFige extends StatelessWidget {
  const _RattachementFige({required this.depense});

  final Depense depense;

  @override
  Widget build(BuildContext context) {
    final consultation = depense.dateConsultation;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.blueMist,
        borderRadius: BorderRadius.circular(AppRadii.control),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            depense.patient ?? 'Patient inconnu',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            consultation == null
                ? 'Consultation rattachée'
                : 'Consultation du ${_dateFmt.format(consultation)}',
            style: const TextStyle(color: AppColors.inkMuted, fontSize: 12),
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
  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime(now.year - 5),
          lastDate: now.add(const Duration(days: 365)),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
        ),
        child: Text(_dateFmt.format(value)),
      ),
    );
  }
}
