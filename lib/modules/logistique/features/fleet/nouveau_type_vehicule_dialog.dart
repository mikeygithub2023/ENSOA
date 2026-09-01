import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/fleet_providers.dart';
import '../../shared/widgets/widgets.dart';

/// Ajoute une marque/modèle/type de véhicule au référentiel — réutilise la
/// marque/le modèle existants s'ils correspondent déjà (insensible à la
/// casse), ne crée que ce qui manque dans la chaîne marque → modèle → type.
class NouveauTypeVehiculeDialog extends ConsumerStatefulWidget {
  const NouveauTypeVehiculeDialog({super.key});

  @override
  ConsumerState<NouveauTypeVehiculeDialog> createState() =>
      _NouveauTypeVehiculeDialogState();
}

class _NouveauTypeVehiculeDialogState
    extends ConsumerState<NouveauTypeVehiculeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _marqueCtrl = TextEditingController();
  final _modeleCtrl = TextEditingController();
  final _typeCtrl = TextEditingController();
  bool _envoi = false;

  @override
  void dispose() {
    _marqueCtrl.dispose();
    _modeleCtrl.dispose();
    _typeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: const Text('Nouvelle marque / modèle / type'),
      content: SizedBox(
        width: 380,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _marqueCtrl,
                decoration: const InputDecoration(labelText: 'Marque'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Requis' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _modeleCtrl,
                decoration: const InputDecoration(labelText: 'Modèle'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Requis' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _typeCtrl,
                decoration: const InputDecoration(labelText: 'Type'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Requis' : null,
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
          child: const Text('Créer'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _envoi = true);
    try {
      final id = await ref
          .read(typesVehiculeRefProvider.notifier)
          .creerTypeComplet(
            marque: _marqueCtrl.text.trim(),
            modele: _modeleCtrl.text.trim(),
            type: _typeCtrl.text.trim(),
          );
      if (mounted) {
        showSuccessSnackBar(context, 'Référentiel créé avec succès.');
        Navigator.of(context).pop(id);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _envoi = false);
        showErrorSnackBar(context, e);
      }
    }
  }
}
