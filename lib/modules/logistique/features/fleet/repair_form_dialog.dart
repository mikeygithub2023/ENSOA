import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:sig_ensoa/modules/logistique/compat.dart';
import '../../data/models/maintenance.dart';
import '../../data/models/vehicule.dart';
import '../../data/repositories/fleet_providers.dart';
import '../../shared/widgets/widgets.dart';

class RepairFormDialog extends ConsumerStatefulWidget {
  final Vehicule vehicule;
  const RepairFormDialog({super.key, required this.vehicule});

  @override
  ConsumerState<RepairFormDialog> createState() => _RepairFormDialogState();
}

class _RepairFormDialogState extends ConsumerState<RepairFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _pannesCtrl = TextEditingController();
  final _chefEquipeCtrl = TextEditingController();
  final _aideMecanoCtrl = TextEditingController();
  final _lieuCtrl = TextEditingController(text: 'Garage central ENSOA');
  bool _envoi = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: Text(
        'Déclarer une réparation — ${widget.vehicule.immatriculation}',
      ),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _pannesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Pannes constatées',
                ),
                maxLines: 2,
                validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _chefEquipeCtrl,
                decoration: const InputDecoration(labelText: "Chef d'équipe"),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _aideMecanoCtrl,
                decoration: const InputDecoration(labelText: 'Aide mécano'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _lieuCtrl,
                decoration: const InputDecoration(
                  labelText: 'Lieu de mise en réparation',
                ),
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
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _envoi = true);
    final user = ref.read(sessionProvider)!.user;
    try {
      await ref
          .read(reparationsProvider.notifier)
          .add(
            Reparation(
              id: const Uuid().v4(),
              dateEntree: DateTime.now(),
              pannesConstatees: _pannesCtrl.text.trim(),
              chefEquipe: _chefEquipeCtrl.text.trim().isEmpty
                  ? null
                  : _chefEquipeCtrl.text.trim(),
              aideMecano: _aideMecanoCtrl.text.trim().isEmpty
                  ? null
                  : _aideMecanoCtrl.text.trim(),
              lieu: _lieuCtrl.text.trim().isEmpty
                  ? null
                  : _lieuCtrl.text.trim(),
              vehiculeId: widget.vehicule.id,
              utilisateurId: user.id,
            ),
          );
      await ref
          .read(vehiculesProvider.notifier)
          .updateEtat(widget.vehicule.id, EtatVehicule.enReparation);
      if (mounted) {
        showSuccessSnackBar(context, 'Réparation déclarée avec succès.');
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
