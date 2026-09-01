import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sig_ensoa/modules/logistique/compat.dart';
import '../../data/models/maintenance.dart';
import '../../data/models/vehicule.dart';
import '../../data/repositories/fleet_providers.dart';
import '../../data/repositories/misc_providers.dart';
import '../../shared/widgets/widgets.dart';

class CloseRepairDialog extends ConsumerStatefulWidget {
  final Reparation reparation;
  final Vehicule vehicule;
  const CloseRepairDialog({
    super.key,
    required this.reparation,
    required this.vehicule,
  });

  @override
  ConsumerState<CloseRepairDialog> createState() => _CloseRepairDialogState();
}

class _CloseRepairDialogState extends ConsumerState<CloseRepairDialog> {
  final _formKey = GlobalKey<FormState>();
  final _solutionCtrl = TextEditingController();
  EtatVehicule _etatApres = EtatVehicule.disponible;
  bool _envoi = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: Text(
        'Clôturer la réparation — ${widget.vehicule.immatriculation}',
      ),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.reparation.pannesConstatees,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _solutionCtrl,
                decoration: const InputDecoration(
                  labelText: 'Solutions apportées',
                ),
                maxLines: 2,
                validator: (v) =>
                    v == null || v.isEmpty ? 'Requis pour clôturer' : null,
              ),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('État du véhicule après réparation'),
              ),
              const SizedBox(height: 8),
              SegmentedButton<EtatVehicule>(
                segments: const [
                  ButtonSegment(
                    value: EtatVehicule.disponible,
                    label: Text('Disponible'),
                  ),
                  ButtonSegment(
                    value: EtatVehicule.horsService,
                    label: Text('Hors service'),
                  ),
                ],
                selected: {_etatApres},
                onSelectionChanged: (s) => setState(() => _etatApres = s.first),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _envoi ? null : _submit,
          child: const Text('Clôturer'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _envoi = true);
    try {
      await ref
          .read(reparationsProvider.notifier)
          .cloturer(
            widget.reparation.id,
            solutionsApportees: _solutionCtrl.text.trim(),
          );
      await ref
          .read(vehiculesProvider.notifier)
          .updateEtat(widget.vehicule.id, _etatApres);
      final user = ref.read(sessionProvider)?.user;
      if (user != null) {
        ref
            .read(auditProvider.notifier)
            .log(
              auteurId: user.id,
              action: 'REPARATION_CLOTUREE',
              cible: widget.vehicule.immatriculation,
              detail: 'Retour au statut : ${_etatApres.label}',
            );
      }
      if (mounted) {
        showSuccessSnackBar(context, 'Réparation clôturée avec succès.');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _envoi = false);
        showErrorSnackBar(context, e);
      }
    }
  }
}
