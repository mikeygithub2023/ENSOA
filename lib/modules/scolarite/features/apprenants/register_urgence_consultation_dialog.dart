import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sig_ensoa/core/erreurs.dart';
import 'package:sig_ensoa/core/theme.dart' hide AlertLevel, AlertLevelColor;
import '../../models/apprenant.dart';
import '../../models/consultation_medicale.dart';
import '../medicaments/providers/medicaments_providers.dart';
import 'data/consultations_medicales_repository.dart';
import 'medicaments_picker_field.dart';
import 'pathologie_fields.dart';
import 'providers/consultations_medicales_providers.dart';

/// Le médecin enregistre une consultation d'urgence — contrairement à une
/// routine, aucune autorisation préalable n'est nécessaire : la consultation
/// est créée et close dans la foulée, avec ses prescriptions. [apprenants]
/// peut couvrir une classe/stage précis(e) ou toute une division ("Toutes
/// classes/stages") — la classe et la division de la consultation sont
/// dérivées de l'apprenant choisi, pas d'un filtre externe, pour que ce
/// bouton reste disponible quel que soit le filtre en cours.
Future<void> showRegisterUrgenceConsultationDialog(
  BuildContext context, {
  required List<Apprenant> apprenants,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.all(24),
      child: _RegisterUrgenceConsultationDialog(apprenants: apprenants),
    ),
  );
}

class _RegisterUrgenceConsultationDialog extends ConsumerStatefulWidget {
  const _RegisterUrgenceConsultationDialog({required this.apprenants});

  final List<Apprenant> apprenants;

  @override
  ConsumerState<_RegisterUrgenceConsultationDialog> createState() =>
      _RegisterUrgenceConsultationDialogState();
}

class _RegisterUrgenceConsultationDialogState
    extends ConsumerState<_RegisterUrgenceConsultationDialog> {
  Apprenant? _apprenant;
  Pathologie? _pathologie;
  final _pathologieDetailsController = TextEditingController();
  final _joursReposController = TextEditingController();
  final _examensController = TextEditingController();
  final _exemptionDetailsController = TextEditingController();
  final _hospitalisationInterneLieuController = TextEditingController();
  final _hospitalisationExterneLieuController = TextEditingController();
  bool _exemption = false;
  bool _hospitalisationInterne = false;
  bool _hospitalisationExterne = false;
  List<PrescriptionLigne> _medicaments = const [];
  final _medicamentsController = MedicamentsPickerController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _pathologieDetailsController.dispose();
    _joursReposController.dispose();
    _examensController.dispose();
    _exemptionDetailsController.dispose();
    _hospitalisationInterneLieuController.dispose();
    _hospitalisationExterneLieuController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final apprenant = _apprenant;
    if (apprenant == null) {
      setState(() => _error = 'Choisissez un élève / stagiaire');
      return;
    }
    final classeId = apprenant.classeId;
    if (classeId == null) {
      setState(
        () => _error =
            'Cet apprenant n\'est affecté à aucune phase ni aucun stage.',
      );
      return;
    }
    // Un médicament choisi mais pour lequel « Ajouter » n'a pas été cliqué
    // serait sinon perdu sans que le médecin s'en aperçoive.
    final erreurMedicament = _medicamentsController.validerLigneEnCours();
    if (erreurMedicament != null) {
      setState(() => _error = erreurMedicament);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(consultationsMedicalesRepositoryProvider);
    try {
      final consultationId = await repository.createConsultation(
        ConsultationMedicaleDraft(
          apprenantId: apprenant.id,
          divisionId: apprenant.divisionId,
          classeId: classeId,
          dateSouhaitee: DateTime.now(),
          type: ConsultationType.urgence,
          statut: ConsultationStatut.enCours,
        ),
      );
      await repository.completeConsultation(
        consultationId,
        pathologie: _pathologie,
        pathologieDetails: _pathologieDetailsController.text.trim().isEmpty
            ? null
            : _pathologieDetailsController.text.trim(),
        joursRepos: int.tryParse(_joursReposController.text.trim()),
        exemption: _exemption,
        hospitalisationInterne: _hospitalisationInterne,
        hospitalisationExterne: _hospitalisationExterne,
        examensDemandes: _examensController.text.trim().isEmpty
            ? null
            : _examensController.text.trim(),
        exemptionDetails: _exemptionDetailsController.text.trim().isEmpty
            ? null
            : _exemptionDetailsController.text.trim(),
        hospitalisationInterneLieu:
            _hospitalisationInterneLieuController.text.trim().isEmpty
            ? null
            : _hospitalisationInterneLieuController.text.trim(),
        hospitalisationExterneLieu:
            _hospitalisationExterneLieuController.text.trim().isEmpty
            ? null
            : _hospitalisationExterneLieuController.text.trim(),
      );
      for (final ligne in _medicaments) {
        await repository.addOrdonnanceLigne(
          consultationId: consultationId,
          medicamentId: ligne.medicament.id,
          quantite: ligne.quantite,
          posologie: ligne.posologie,
        );
      }
      ref.invalidate(consultationsMedicalesByClasseProvider(classeId));
      ref.invalidate(
        consultationsMedicalesByDivisionProvider(apprenant.divisionId),
      );
      ref.invalidate(medicamentsProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Consultation d\'urgence enregistrée.'),
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
    final width = screenSize.width - 48 < 600 ? screenSize.width - 48 : 600.0;
    final height = screenSize.height - 48 < 750
        ? screenSize.height - 48
        : 750.0;
    final medicamentsAsync = ref.watch(medicamentsProvider);

    return SizedBox(
      width: width,
      height: height,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 12, 0),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Consultation d\'urgence',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.danger,
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
                  PathologieFields(
                    pathologie: _pathologie,
                    detailsController: _pathologieDetailsController,
                    onChanged: (value) => setState(() => _pathologie = value),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _joursReposController,
                    decoration: const InputDecoration(
                      labelText: 'Jours de repos (facultatif)',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Exemption'),
                    value: _exemption,
                    onChanged: (v) => setState(() => _exemption = v),
                  ),
                  if (_exemption) ...[
                    const SizedBox(height: 4),
                    TextField(
                      controller: _exemptionDetailsController,
                      decoration: const InputDecoration(
                        labelText: 'Détails de l\'exemption',
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Hospitalisation interne'),
                    value: _hospitalisationInterne,
                    onChanged: (v) =>
                        setState(() => _hospitalisationInterne = v),
                  ),
                  if (_hospitalisationInterne) ...[
                    const SizedBox(height: 4),
                    TextField(
                      controller: _hospitalisationInterneLieuController,
                      decoration: const InputDecoration(labelText: 'Lieu'),
                    ),
                    const SizedBox(height: 8),
                  ],
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Hospitalisation externe'),
                    value: _hospitalisationExterne,
                    onChanged: (v) =>
                        setState(() => _hospitalisationExterne = v),
                  ),
                  if (_hospitalisationExterne) ...[
                    const SizedBox(height: 4),
                    TextField(
                      controller: _hospitalisationExterneLieuController,
                      decoration: const InputDecoration(labelText: 'Lieu'),
                    ),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 8),
                  TextField(
                    controller: _examensController,
                    decoration: const InputDecoration(
                      labelText: 'Examens demandés (facultatif)',
                      hintText: 'Ex. bilan sanguin, radiographie...',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 20),
                  medicamentsAsync.when(
                    data: (medicaments) => MedicamentsPickerField(
                      controller: _medicamentsController,
                      medicaments: medicaments,
                      value: _medicaments,
                      onChanged: (value) =>
                          setState(() => _medicaments = value),
                    ),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, _) => Text(
                      'Erreur de chargement des médicaments : $error',
                      style: const TextStyle(color: AppColors.danger),
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
                  onPressed: _submitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.danger,
                  ),
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
