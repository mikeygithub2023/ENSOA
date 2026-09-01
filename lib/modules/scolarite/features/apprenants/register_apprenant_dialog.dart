import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:sig_ensoa/core/erreurs.dart';
import 'package:sig_ensoa/core/theme.dart' hide AlertLevel, AlertLevelColor;
import '../../models/apprenant.dart';
import '../../models/classe.dart';
import '../../models/diplome.dart';
import '../../models/division.dart';
import '../../models/promotion.dart';
import 'data/apprenants_repository.dart';
import 'grade_defaults.dart';
import 'providers/apprenants_providers.dart';

const _situationMatrimonialeOptions = [
  'Célibataire',
  'Marié(e)',
  'Divorcé(e)',
  'Veuf(ve)',
];
const _groupeSanguinOptions = [
  'A+',
  'A-',
  'B+',
  'B-',
  'AB+',
  'AB-',
  'O+',
  'O-',
];

class _StepDef {
  const _StepDef(this.label);
  final String label;
}

const _steps = <_StepDef>[
  _StepDef('Identité'),
  _StepDef('Filiation'),
  _StepDef('Urgence & santé'),
  _StepDef('Formation civile'),
  _StepDef('Récapitulatif'),
];

/// Ouvre le formulaire d'enregistrement d'un élève/stagiaire — reprend les
/// rubriques de la fiche signalétique papier (DFS), réparties en étapes. Le
/// type, la division et la classe/stage ne sont pas demandés : on est déjà
/// dans une classe/stage précis au moment d'ouvrir ce formulaire.
Future<void> showRegisterApprenantDialog(
  BuildContext context, {
  required Division division,
  required Classe classe,
  Promotion? promotion,
  Apprenant? existing,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.all(24),
      child: _RegisterApprenantDialog(
        division: division,
        classe: classe,
        promotion: promotion,
        existing: existing,
      ),
    ),
  );
}

class _RegisterApprenantDialog extends ConsumerStatefulWidget {
  const _RegisterApprenantDialog({
    required this.division,
    required this.classe,
    this.promotion,
    this.existing,
  });

  final Division division;

  /// La phase où l'élève commence — celle où il se trouve aujourd'hui.
  /// Pour un stagiaire, son stage.
  final Classe classe;

  /// La promotion dans laquelle l'élève est inscrit. C'est elle qui le
  /// rattache à l'école : il suivra toutes ses phases. Nulle pour un
  /// stagiaire.
  final Promotion? promotion;
  final Apprenant? existing;

  @override
  ConsumerState<_RegisterApprenantDialog> createState() =>
      _RegisterApprenantDialogState();
}

class _RegisterApprenantDialogState
    extends ConsumerState<_RegisterApprenantDialog> {
  final _formKey = GlobalKey<FormState>();

  final _matriculeCtrl = TextEditingController();
  final _gradeCtrl = TextEditingController();
  final _nomCtrl = TextEditingController();
  final _prenomsCtrl = TextEditingController();
  final _telephoneCtrl = TextEditingController();
  final _ethnieCtrl = TextEditingController();
  final _lieuNaissanceCtrl = TextEditingController();
  final _enfantsCtrl = TextEditingController();
  final _pereCtrl = TextEditingController();
  final _mereCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _urgenceNomCtrl = TextEditingController();
  final _urgenceLienCtrl = TextEditingController();
  final _urgenceContactCtrl = TextEditingController();
  final _tailleCtrl = TextEditingController();
  final _poidsCtrl = TextEditingController();
  final _qualificationCtrl = TextEditingController();
  final _permisCtrl = TextEditingController();

  DateTime? _dateNaissance;
  String? _situationMatrimoniale;
  String? _sexe;
  ApprenantStatut _statut = ApprenantStatut.actif;
  String? _groupeSanguin;
  int _currentStep = 0;
  bool _submitting = false;

  /// Diplômes ajoutés au catalogue pendant cette session mais pas encore
  /// confirmés en base — fusionnés avec le catalogue Supabase (`diplomesProvider`)
  /// à chaque ouverture du sélecteur.
  List<String> _diplomesDisponibles = [];
  final Set<String> _selectedDiplomes = {};

  Uint8List? _photoBytes;
  String? _photoName;
  String? _existingPhotoUrl;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing == null) {
      if (widget.classe.type == ClasseType.phase) {
        _gradeCtrl.text = defaultGradeForClasse(widget.classe.nom) ?? '';
      }
      return;
    }

    _matriculeCtrl.text = existing.matricule ?? '';
    _gradeCtrl.text = existing.grade ?? '';
    _nomCtrl.text = existing.nom;
    _prenomsCtrl.text = existing.prenom;
    _telephoneCtrl.text = existing.telephone ?? '';
    _ethnieCtrl.text = existing.ethnie ?? '';
    _lieuNaissanceCtrl.text = existing.lieuNaissance ?? '';
    _enfantsCtrl.text = existing.nombreEnfants?.toString() ?? '';
    _pereCtrl.text = existing.nomPere ?? '';
    _mereCtrl.text = existing.nomMere ?? '';
    _emailCtrl.text = existing.email ?? '';
    _urgenceNomCtrl.text = existing.urgenceNom ?? '';
    _urgenceLienCtrl.text = existing.urgenceLien ?? '';
    _urgenceContactCtrl.text = existing.urgenceContact ?? '';
    _tailleCtrl.text = existing.tailleCm?.toString() ?? '';
    _poidsCtrl.text = existing.poidsKg?.toString() ?? '';
    _qualificationCtrl.text = existing.qualification ?? '';
    _permisCtrl.text = existing.permisConduire ?? '';
    _dateNaissance = existing.dateNaissance;
    _situationMatrimoniale = existing.situationMatrimoniale;
    _sexe = existing.sexe;
    _statut = existing.statut;
    _groupeSanguin = existing.groupeSanguin;

    ref.read(apprenantsRepositoryProvider).fetchDiplomes(existing.id).then((
      diplomes,
    ) {
      if (!mounted) return;
      setState(() {
        _diplomesDisponibles = diplomes;
        _selectedDiplomes.addAll(diplomes);
      });
    });

    final photoPath = existing.photoPath;
    if (photoPath != null) {
      ref.read(apprenantsRepositoryProvider).getPhotoSignedUrl(photoPath).then((
        url,
      ) {
        if (!mounted) return;
        setState(() => _existingPhotoUrl = url);
      });
    }
  }

  bool _photoRemoved = false;

  Future<void> _pickPhoto() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null) return;
    final file = result.files.single;
    if (file.bytes == null) return;
    setState(() {
      _photoBytes = file.bytes;
      _photoName = file.name;
      _photoRemoved = false;
    });
  }

  void _clearPhoto() => setState(() {
    _photoBytes = null;
    _photoName = null;
    _existingPhotoUrl = null;
    _photoRemoved = true;
  });

  @override
  void dispose() {
    for (final c in [
      _matriculeCtrl,
      _gradeCtrl,
      _nomCtrl,
      _prenomsCtrl,
      _telephoneCtrl,
      _ethnieCtrl,
      _lieuNaissanceCtrl,
      _enfantsCtrl,
      _pereCtrl,
      _mereCtrl,
      _emailCtrl,
      _urgenceNomCtrl,
      _urgenceLienCtrl,
      _urgenceContactCtrl,
      _tailleCtrl,
      _poidsCtrl,
      _qualificationCtrl,
      _permisCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _openDiplomesPicker() async {
    final catalogue =
        ref.read(diplomesProvider).value?.map((d) => d.nom) ?? const [];
    final tempAvailable = {...catalogue, ..._diplomesDisponibles}.toList()
      ..sort();
    final tempSelected = Set<String>.from(_selectedDiplomes);
    final newDiplomeCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          scrollable: true,
          title: const Text('Diplôme(s)'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        for (final d in tempAvailable)
                          CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(d),
                            value: tempSelected.contains(d),
                            onChanged: (checked) => setDialogState(() {
                              if (checked == true) {
                                tempSelected.add(d);
                              } else {
                                tempSelected.remove(d);
                              }
                            }),
                          ),
                      ],
                    ),
                  ),
                ),
                const Divider(),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: newDiplomeCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Nouveau diplôme...',
                          isDense: true,
                        ),
                        onSubmitted: (_) => setDialogState(() {
                          final value = newDiplomeCtrl.text.trim();
                          if (value.isEmpty ||
                              tempAvailable.any(
                                (d) => d.toLowerCase() == value.toLowerCase(),
                              )) {
                            return;
                          }
                          tempAvailable.add(value);
                          tempSelected.add(value);
                          newDiplomeCtrl.clear();
                        }),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      tooltip: 'Ajouter ce diplôme à la liste',
                      onPressed: () => setDialogState(() {
                        final value = newDiplomeCtrl.text.trim();
                        if (value.isEmpty ||
                            tempAvailable.any(
                              (d) => d.toLowerCase() == value.toLowerCase(),
                            )) {
                          return;
                        }
                        tempAvailable.add(value);
                        tempSelected.add(value);
                        newDiplomeCtrl.clear();
                      }),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                setState(() {
                  _diplomesDisponibles = tempAvailable;
                  _selectedDiplomes
                    ..clear()
                    ..addAll(tempSelected);
                });
                Navigator.of(context).pop();
              },
              child: const Text('Valider'),
            ),
          ],
        ),
      ),
    );
    newDiplomeCtrl.dispose();
  }

  void _goNext() {
    if (!(_formKey.currentState?.validate() ?? true)) return;
    if (_currentStep < _steps.length - 1) {
      setState(() => _currentStep++);
    } else {
      _submit();
    }
  }

  void _goBack() => setState(() => _currentStep--);

  String? _emptyToNull(String value) =>
      value.trim().isEmpty ? null : value.trim();

  ApprenantDraft _buildDraft() {
    return ApprenantDraft(
      divisionId: widget.division.id,
      classeId: widget.classe.id,
      type: widget.classe.type == ClasseType.phase ? 'eleve' : 'stagiaire',
      matricule: _emptyToNull(_matriculeCtrl.text),
      nom: _nomCtrl.text.trim(),
      prenom: _prenomsCtrl.text.trim(),
      grade: _emptyToNull(_gradeCtrl.text),
      sexe: _sexe,
      statut: _statut,
      telephone: _emptyToNull(_telephoneCtrl.text),
      ethnie: _emptyToNull(_ethnieCtrl.text),
      dateNaissance: _dateNaissance,
      lieuNaissance: _emptyToNull(_lieuNaissanceCtrl.text),
      situationMatrimoniale: _situationMatrimoniale,
      nombreEnfants: int.tryParse(_enfantsCtrl.text.trim()),
      nomPere: _emptyToNull(_pereCtrl.text),
      nomMere: _emptyToNull(_mereCtrl.text),
      email: _emptyToNull(_emailCtrl.text),
      urgenceNom: _emptyToNull(_urgenceNomCtrl.text),
      urgenceLien: _emptyToNull(_urgenceLienCtrl.text),
      urgenceContact: _emptyToNull(_urgenceContactCtrl.text),
      tailleCm: num.tryParse(_tailleCtrl.text.trim().replaceAll(',', '.')),
      poidsKg: num.tryParse(_poidsCtrl.text.trim().replaceAll(',', '.')),
      groupeSanguin: _groupeSanguin,
      qualification: _emptyToNull(_qualificationCtrl.text),
      permisConduire: _emptyToNull(_permisCtrl.text),
      diplomes: _selectedDiplomes.toList(),
      photoBytes: _photoBytes,
      photoFileName: _photoName,
      removePhoto: _photoRemoved,
    );
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final messenger = ScaffoldMessenger.of(context);
    final draft = _buildDraft();

    try {
      final repository = ref.read(apprenantsRepositoryProvider);
      if (_isEditing) {
        await repository.updateApprenant(widget.existing!.id, draft);
      } else {
        await repository.createApprenant(draft);
      }
      ref.invalidate(apprenantsListProvider);
      if (_isEditing) {
        ref.invalidate(apprenantByIdProvider(widget.existing!.id));
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? 'Modifications enregistrées.'
                : 'Élève/stagiaire enregistré avec succès.',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Erreur lors de l\'enregistrement : ${messageErreur(e)}',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 660,
      height: 700,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _isEditing
                        ? (widget.classe.type == ClasseType.phase
                              ? 'Modifier un élève'
                              : 'Modifier un stagiaire')
                        : (widget.classe.type == ClasseType.phase
                              ? 'Enregistrer un élève'
                              : 'Enregistrer un stagiaire'),
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
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
            child: _ContextBanner(
              division: widget.division,
              classe: widget.classe,
              promotion: widget.promotion,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (_currentStep + 1) / _steps.length,
                minHeight: 6,
                backgroundColor: AppColors.border,
                valueColor: const AlwaysStoppedAnimation(AppColors.blueDeep),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    for (var i = 0; i < _steps.length; i++)
                      _buildAccordionSection(i),
                  ],
                ),
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
                      : (_currentStep == 0
                            ? () => Navigator.of(context).pop()
                            : _goBack),
                  child: Text(_currentStep == 0 ? 'Annuler' : 'Précédent'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _submitting ? null : _goNext,
                  child: _submitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _currentStep < _steps.length - 1
                              ? 'Suivant'
                              : (_isEditing
                                    ? 'Enregistrer les modifications'
                                    : 'Enregistrer'),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccordionSection(int index) {
    final isCurrent = index == _currentStep;
    final isDone = index < _currentStep;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppRadii.control),
        border: Border.all(
          color: isCurrent
              ? AppColors.blueDeep.withValues(alpha: 0.35)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(AppRadii.control),
            onTap: isDone ? () => setState(() => _currentStep = index) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCurrent || isDone
                          ? AppColors.blueDeep
                          : AppColors.blueMist,
                      border: isCurrent || isDone
                          ? null
                          : Border.all(color: AppColors.border),
                    ),
                    child: isDone
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: isCurrent
                                  ? Colors.white
                                  : AppColors.inkMuted,
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _steps[index].label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isCurrent || isDone
                          ? AppColors.navy
                          : AppColors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isCurrent)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _buildStepContent(index),
            ),
        ],
      ),
    );
  }

  Widget _buildStepContent(int step) {
    switch (step) {
      case 0:
        return Column(
          key: const ValueKey('step-identite'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FieldRow([
              TextFormField(
                controller: _matriculeCtrl,
                decoration: const InputDecoration(labelText: 'Matricule'),
                validator: widget.classe.type == ClasseType.stage
                    ? (v) => (v == null || v.trim().isEmpty)
                          ? 'Champ requis'
                          : null
                    : null,
              ),
              TextFormField(
                controller: _gradeCtrl,
                decoration: const InputDecoration(labelText: 'Grade'),
              ),
            ]),
            // Le statut ne se choisit pas à l'inscription — on n'inscrit
            // pas quelqu'un déjà radié — mais il doit pouvoir être repris
            // ensuite : c'est ici qu'on radie, suspend ou diplôme.
            if (_isEditing)
              _FieldRow([
                DropdownButtonFormField<ApprenantStatut>(
                  initialValue: _statut,
                  decoration: const InputDecoration(labelText: 'Statut'),
                  items: [
                    for (final s in ApprenantStatut.values)
                      DropdownMenuItem(value: s, child: Text(s.label)),
                  ],
                  onChanged: (value) =>
                      setState(() => _statut = value ?? _statut),
                ),
              ]),
            _FieldRow([
              // Le sexe décide du barème appliqué aux épreuves sportives :
              // sans lui, une performance reste sans note.
              DropdownButtonFormField<String>(
                initialValue: _sexe,
                decoration: const InputDecoration(labelText: 'Sexe'),
                items: const [
                  DropdownMenuItem(value: 'M', child: Text('Masculin')),
                  DropdownMenuItem(value: 'F', child: Text('Féminin')),
                ],
                onChanged: (value) => setState(() => _sexe = value),
              ),
              TextFormField(
                controller: _nomCtrl,
                decoration: const InputDecoration(labelText: 'Nom'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
              ),
              TextFormField(
                controller: _prenomsCtrl,
                decoration: const InputDecoration(labelText: 'Prénoms'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
              ),
            ]),
            _FieldRow([
              TextFormField(
                controller: _telephoneCtrl,
                decoration: const InputDecoration(labelText: 'Téléphone'),
                keyboardType: TextInputType.phone,
              ),
            ]),
            _FieldRow([
              _DatePickerField(
                label: 'Née le',
                value: _dateNaissance,
                onChanged: (date) => setState(() => _dateNaissance = date),
              ),
              TextFormField(
                controller: _lieuNaissanceCtrl,
                decoration: const InputDecoration(
                  labelText: 'Lieu de naissance',
                ),
              ),
            ]),
            TextFormField(
              controller: _emailCtrl,
              decoration: const InputDecoration(labelText: 'E-mail'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            _PhotoPicker(
              bytes: _photoBytes,
              fileName: _photoName,
              networkUrl: _existingPhotoUrl,
              onPick: _pickPhoto,
              onClear: _clearPhoto,
            ),
          ],
        );
      case 1:
        return Column(
          key: const ValueKey('step-filiation'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FieldRow([
              // L'ethnie relève de la filiation, pas de l'identité
              // administrative : elle se lit à côté des parents.
              TextFormField(
                controller: _ethnieCtrl,
                decoration: const InputDecoration(labelText: 'Ethnie'),
              ),
              DropdownButtonFormField<String>(
                initialValue: _situationMatrimoniale,
                decoration: const InputDecoration(
                  labelText: 'Situation matrimoniale',
                ),
                items: [
                  for (final s in _situationMatrimonialeOptions)
                    DropdownMenuItem(value: s, child: Text(s)),
                ],
                onChanged: (value) =>
                    setState(() => _situationMatrimoniale = value),
              ),
              TextFormField(
                controller: _enfantsCtrl,
                decoration: const InputDecoration(labelText: 'Enfant(s)'),
                keyboardType: TextInputType.number,
              ),
            ]),
            _FieldRow([
              TextFormField(
                controller: _pereCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nom et prénoms du père',
                ),
              ),
              TextFormField(
                controller: _mereCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nom et prénoms de la mère',
                ),
              ),
            ]),
          ],
        );
      case 2:
        return Column(
          key: const ValueKey('step-urgence-sante'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SubSectionLabel('Contact d\'urgence'),
            _FieldRow([
              TextFormField(
                controller: _urgenceNomCtrl,
                decoration: const InputDecoration(labelText: 'Nom et prénoms'),
              ),
              TextFormField(
                controller: _urgenceLienCtrl,
                decoration: const InputDecoration(labelText: 'Lien de parenté'),
              ),
            ]),
            TextFormField(
              controller: _urgenceContactCtrl,
              decoration: const InputDecoration(labelText: 'Contact(s)'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            const _SubSectionLabel('Données médicales'),
            _FieldRow([
              TextFormField(
                controller: _tailleCtrl,
                decoration: const InputDecoration(labelText: 'Taille (cm)'),
                keyboardType: TextInputType.number,
              ),
              TextFormField(
                controller: _poidsCtrl,
                decoration: const InputDecoration(labelText: 'Poids (kg)'),
                keyboardType: TextInputType.number,
              ),
            ]),
            DropdownButtonFormField<String>(
              initialValue: _groupeSanguin,
              decoration: const InputDecoration(labelText: 'Groupe sanguin'),
              items: [
                for (final g in _groupeSanguinOptions)
                  DropdownMenuItem(value: g, child: Text(g)),
              ],
              onChanged: (value) => setState(() => _groupeSanguin = value),
            ),
          ],
        );
      case 3:
        return Column(
          key: const ValueKey('step-formation'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SubSectionLabel('Diplôme(s)'),
            if (_selectedDiplomes.isEmpty)
              const Text(
                'Aucun diplôme sélectionné.',
                style: TextStyle(color: AppColors.inkMuted, fontSize: 13),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final d in _selectedDiplomes)
                    InputChip(
                      label: Text(d),
                      onDeleted: () =>
                          setState(() => _selectedDiplomes.remove(d)),
                    ),
                ],
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _openDiplomesPicker,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Ajouter un diplôme'),
            ),
            const SizedBox(height: 16),
            _FieldRow([
              TextFormField(
                controller: _qualificationCtrl,
                decoration: const InputDecoration(labelText: 'Qualification'),
              ),
              TextFormField(
                controller: _permisCtrl,
                decoration: const InputDecoration(
                  labelText: 'Permis de conduire',
                ),
              ),
            ]),
          ],
        );
      default:
        return _buildRecapContent();
    }
  }

  Widget _buildRecapContent() {
    final draft = _buildDraft();
    return Column(
      key: const ValueKey('step-recap'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Vérifiez les informations avant d\'enregistrer.',
          style: TextStyle(color: AppColors.inkMuted, fontSize: 13),
        ),
        const SizedBox(height: 16),
        _RecapPhotoRow(
          bytes: _photoBytes,
          networkUrl: _existingPhotoUrl,
          removed: _photoRemoved,
        ),
        const SizedBox(height: 8),
        _RecapSection(
          title: 'Identité',
          rows: {
            'Matricule': draft.matricule ?? '—',
            'Grade': draft.grade ?? '—',
            'Nom': draft.nom,
            'Prénoms': draft.prenom,
            'Téléphone': draft.telephone ?? '—',
            'Née le': draft.dateNaissance == null
                ? '—'
                : DateFormat('dd/MM/yyyy').format(draft.dateNaissance!),
            'Lieu de naissance': draft.lieuNaissance ?? '—',
            'E-mail': draft.email ?? '—',
          },
        ),
        _RecapSection(
          title: 'Filiation',
          rows: {
            'Ethnie': draft.ethnie ?? '—',
            'Situation matrimoniale': draft.situationMatrimoniale ?? '—',
            'Enfant(s)': draft.nombreEnfants?.toString() ?? '—',
            'Nom et prénoms du père': draft.nomPere ?? '—',
            'Nom et prénoms de la mère': draft.nomMere ?? '—',
          },
        ),
        _RecapSection(
          title: 'Urgence & santé',
          rows: {
            'Contact d\'urgence': draft.urgenceNom ?? '—',
            'Lien de parenté': draft.urgenceLien ?? '—',
            'Contact(s)': draft.urgenceContact ?? '—',
            'Taille': draft.tailleCm != null ? '${draft.tailleCm} cm' : '—',
            'Poids': draft.poidsKg != null ? '${draft.poidsKg} kg' : '—',
            'Groupe sanguin': draft.groupeSanguin ?? '—',
          },
        ),
        _RecapSection(
          title: 'Formation civile',
          rows: {
            'Diplôme(s)': draft.diplomes.isEmpty
                ? '—'
                : draft.diplomes.join(', '),
            'Qualification': draft.qualification ?? '—',
            'Permis de conduire': draft.permisConduire ?? '—',
          },
        ),
      ],
    );
  }
}

/// Rappelle la division et la classe/stage dans lesquels l'enregistrement se
/// fait — non modifiable, puisqu'on y est déjà avant d'ouvrir le formulaire.
/// Bloc de relecture d'une rubrique dans le récapitulatif — libellé/valeur,
/// les champs vides affichent "—" pour que l'utilisateur voie d'un coup
/// d'œil ce qui manque avant de valider.
class _RecapSection extends StatelessWidget {
  const _RecapSection({required this.title, required this.rows});

  final String title;
  final Map<String, String> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.blueMist,
        borderRadius: BorderRadius.circular(AppRadii.control),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          for (final entry in rows.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 190,
                    child: Text(
                      entry.key,
                      style: const TextStyle(
                        color: AppColors.inkMuted,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _RecapPhotoRow extends StatelessWidget {
  const _RecapPhotoRow({
    required this.bytes,
    required this.networkUrl,
    required this.removed,
  });

  final Uint8List? bytes;
  final String? networkUrl;
  final bool removed;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = bytes != null || networkUrl != null;
    return Row(
      children: [
        if (bytes != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              bytes!,
              width: 40,
              height: 40,
              fit: BoxFit.cover,
            ),
          )
        else if (networkUrl != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              networkUrl!,
              width: 40,
              height: 40,
              fit: BoxFit.cover,
            ),
          )
        else
          const Icon(Icons.person_outline, color: AppColors.inkMuted, size: 32),
        const SizedBox(width: 12),
        Text(
          hasPhoto
              ? 'Photo ajoutée'
              : (removed ? 'Photo retirée' : 'Aucune photo'),
          style: const TextStyle(color: AppColors.inkMuted, fontSize: 13),
        ),
      ],
    );
  }
}

class _ContextBanner extends StatelessWidget {
  const _ContextBanner({
    required this.division,
    required this.classe,
    this.promotion,
  });

  final Division division;
  final Classe classe;

  /// Renseignée pour un élève : c'est la promotion qui l'inscrit, la phase
  /// n'est que celle où il commence.
  final Promotion? promotion;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.blueMist,
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.groups_outlined,
            size: 18,
            color: AppColors.blueDeep,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              // La promotion prime quand elle est connue : c'est elle qui
              // inscrit l'élève. Sans elle, on nomme le rattachement pour
              // ce qu'il est — une phase ou un stage —, jamais l'un pour
              // l'autre.
              promotion != null
                  ? 'Promotion : ${promotion!.intitule} · ${division.nom}'
                  : '${classe.type == ClasseType.phase ? "Phase" : "Stage"} : '
                        '${classe.nom} · ${division.nom}',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.blueDeep,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubSectionLabel extends StatelessWidget {
  const _SubSectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: AppColors.navy,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

/// Place deux champs côte à côte, comme dans la fiche papier.
class _FieldRow extends StatelessWidget {
  const _FieldRow(this.children);

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 20),
            Expanded(child: children[i]),
          ],
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
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime(2000),
          firstDate: DateTime(1950),
          lastDate: DateTime.now(),
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

class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({
    required this.bytes,
    required this.fileName,
    required this.onPick,
    required this.onClear,
    this.networkUrl,
  });

  final Uint8List? bytes;
  final String? fileName;
  final String? networkUrl;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    if (bytes != null || networkUrl != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppRadii.control),
          color: AppColors.blueMist,
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: bytes != null
                  ? Image.memory(
                      bytes!,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                    )
                  : Image.network(
                      networkUrl!,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                fileName ?? 'Photo actuelle',
                style: const TextStyle(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(onPressed: onPick, child: const Text('Changer')),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              tooltip: 'Retirer la photo',
              onPressed: onClear,
            ),
          ],
        ),
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.control),
      onTap: onPick,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppRadii.control),
          color: AppColors.blueMist,
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_a_photo_outlined, color: AppColors.inkMuted),
            SizedBox(height: 6),
            Text(
              'Ajouter une photo',
              style: TextStyle(color: AppColors.inkMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
