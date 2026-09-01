import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:sig_ensoa/core/erreurs.dart';
import 'package:sig_ensoa/core/theme.dart' hide AlertLevel, AlertLevelColor;
import '../../models/apprenant.dart';
import 'providers/antecedents_medicaux_providers.dart';

/// Fiche des antécédents médicaux de l'apprenant (allergies, maladies
/// chroniques, chirurgies, antécédents familiaux, traitement en cours) —
/// réservée à l'administrateur et au médecin. Accessible depuis la fiche de
/// l'apprenant et depuis l'écran Consultations médicales, pour que le
/// médecin puisse la consulter sans avoir à parcourir l'effectif.
Future<void> showAntecedentsMedicauxDialog(
  BuildContext context, {
  required Apprenant apprenant,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.all(24),
      child: _AntecedentsMedicauxDialog(apprenant: apprenant),
    ),
  );
}

class _AntecedentsMedicauxDialog extends ConsumerStatefulWidget {
  const _AntecedentsMedicauxDialog({required this.apprenant});

  final Apprenant apprenant;

  @override
  ConsumerState<_AntecedentsMedicauxDialog> createState() =>
      _AntecedentsMedicauxDialogState();
}

class _AntecedentsMedicauxDialogState
    extends ConsumerState<_AntecedentsMedicauxDialog> {
  final _allergiesController = TextEditingController();
  final _pathologiquesController = TextEditingController();
  final _chirurgicauxController = TextEditingController();
  final _familiauxController = TextEditingController();
  final _traitementController = TextEditingController();
  final _observationsController = TextEditingController();
  bool _submitting = false;
  bool _initialized = false;

  @override
  void dispose() {
    _allergiesController.dispose();
    _pathologiquesController.dispose();
    _chirurgicauxController.dispose();
    _familiauxController.dispose();
    _traitementController.dispose();
    _observationsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(antecedentsMedicauxRepositoryProvider)
          .upsert(
            apprenantId: widget.apprenant.id,
            allergies: _allergiesController.text.trim().isEmpty
                ? null
                : _allergiesController.text.trim(),
            antecedentsPathologiques:
                _pathologiquesController.text.trim().isEmpty
                ? null
                : _pathologiquesController.text.trim(),
            antecedentsChirurgicaux: _chirurgicauxController.text.trim().isEmpty
                ? null
                : _chirurgicauxController.text.trim(),
            antecedentsFamiliaux: _familiauxController.text.trim().isEmpty
                ? null
                : _familiauxController.text.trim(),
            traitementEnCours: _traitementController.text.trim().isEmpty
                ? null
                : _traitementController.text.trim(),
            observations: _observationsController.text.trim().isEmpty
                ? null
                : _observationsController.text.trim(),
          );
      ref.invalidate(antecedentsMedicauxProvider(widget.apprenant.id));
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Antécédents médicaux enregistrés.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _submitting = false);
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
    final height = screenSize.height - 48 < 680
        ? screenSize.height - 48
        : 680.0;
    final antecedentsAsync = ref.watch(
      antecedentsMedicauxProvider(widget.apprenant.id),
    );

    antecedentsAsync.whenData((antecedents) {
      if (!_initialized && antecedents != null) {
        _allergiesController.text = antecedents.allergies ?? '';
        _pathologiquesController.text =
            antecedents.antecedentsPathologiques ?? '';
        _chirurgicauxController.text =
            antecedents.antecedentsChirurgicaux ?? '';
        _familiauxController.text = antecedents.antecedentsFamiliaux ?? '';
        _traitementController.text = antecedents.traitementEnCours ?? '';
        _observationsController.text = antecedents.observations ?? '';
        _initialized = true;
      }
    });

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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Antécédents médicaux',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      Text(
                        widget.apprenant.nomComplet,
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
          Expanded(
            child: antecedentsAsync.when(
              data: (antecedents) => SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (antecedents != null) ...[
                      Text(
                        'Dernière mise à jour : '
                        '${DateFormat('dd/MM/yyyy à HH:mm').format(antecedents.updatedAt)}',
                        style: const TextStyle(
                          color: AppColors.inkMuted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: _allergiesController,
                      decoration: const InputDecoration(labelText: 'Allergies'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _pathologiquesController,
                      decoration: const InputDecoration(
                        labelText:
                            'Antécédents pathologiques (maladies chroniques...)',
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _chirurgicauxController,
                      decoration: const InputDecoration(
                        labelText: 'Antécédents chirurgicaux',
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _familiauxController,
                      decoration: const InputDecoration(
                        labelText: 'Antécédents familiaux',
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _traitementController,
                      decoration: const InputDecoration(
                        labelText: 'Traitement en cours',
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _observationsController,
                      decoration: const InputDecoration(
                        labelText: 'Observations',
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Text(
                  'Erreur de chargement : ${messageErreur(error)}',
                  style: const TextStyle(color: AppColors.danger),
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
}
