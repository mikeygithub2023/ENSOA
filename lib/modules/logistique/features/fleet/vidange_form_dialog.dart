import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:sig_ensoa/modules/logistique/compat.dart';
import '../../data/models/maintenance.dart';
import '../../data/models/vehicule.dart';
import '../../data/repositories/fleet_providers.dart';
import '../../shared/widgets/widgets.dart';

class VidangeFormDialog extends ConsumerStatefulWidget {
  final Vehicule vehicule;
  const VidangeFormDialog({super.key, required this.vehicule});

  @override
  ConsumerState<VidangeFormDialog> createState() => _VidangeFormDialogState();
}

class _VidangeFormDialogState extends ConsumerState<VidangeFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _huileCtrl = TextEditingController(text: '15W40');
  final _filtreCtrl = TextEditingController(text: 'Filtre standard');
  final _qteCtrl = TextEditingController(text: '8');
  late final _seuilCtrl = TextEditingController(
    text: '${widget.vehicule.kilometrage + 5000}',
  );
  bool _envoi = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: Text('Nouvelle vidange — ${widget.vehicule.immatriculation}'),
      content: SizedBox(
        width: 380,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _huileCtrl,
                decoration: const InputDecoration(labelText: "Type d'huile"),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _filtreCtrl,
                decoration: const InputDecoration(labelText: 'Filtre'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _qteCtrl,
                decoration: const InputDecoration(
                  labelText: "Quantité d'huile (L)",
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _seuilCtrl,
                decoration: const InputDecoration(
                  labelText: 'Prochain seuil de vidange (km)',
                ),
                keyboardType: TextInputType.number,
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
          .read(vidangesProvider.notifier)
          .add(
            Vidange(
              id: const Uuid().v4(),
              date: DateTime.now(),
              filtreVidange: _filtreCtrl.text.trim(),
              typeHuile: _huileCtrl.text.trim(),
              qteHuile: int.tryParse(_qteCtrl.text) ?? 8,
              vehiculeId: widget.vehicule.id,
              utilisateurId: user.id,
            ),
          );
      final nouveauSeuil =
          int.tryParse(_seuilCtrl.text) ?? (widget.vehicule.kilometrage + 5000);
      await ref
          .read(vehiculesProvider.notifier)
          .updateApresVidange(
            widget.vehicule.id,
            nouveauSeuil,
            widget.vehicule.kilometrage,
          );
      if (mounted) {
        showSuccessSnackBar(context, 'Vidange enregistrée avec succès.');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _envoi = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur Supabase : $e')));
      }
    }
  }
}
