import 'package:sig_ensoa/core/formulaire.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:sig_ensoa/modules/logistique/compat.dart';
import '../../data/models/pannes.dart';
import '../../data/models/vehicule.dart';
import '../../data/repositories/misc_providers.dart';
import '../../data/repositories/pannes_providers.dart';
import '../../shared/widgets/widgets.dart';

/// Signaler une panne sur un véhicule.
///
/// Un signalement, rien de plus : le véhicule garde son état — il peut porter
/// une panne et rester disponible. C'est la demande de mise en réparation, plus
/// tard, qui décidera s'il faut l'immobiliser.
class PanneFormDialog extends ConsumerStatefulWidget {
  final Vehicule vehicule;
  const PanneFormDialog({super.key, required this.vehicule});

  @override
  ConsumerState<PanneFormDialog> createState() => _PanneFormDialogState();
}

class _PanneFormDialogState extends ConsumerState<PanneFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionCtrl = TextEditingController();
  GravitePanne _gravite = GravitePanne.legere;
  bool _envoi = false;

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: Text('Signaler une panne — ${widget.vehicule.immatriculation}'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _descriptionCtrl,
                decoration: const InputDecoration(
                  labelText: 'Description de la panne',
                ),
                minLines: 2,
                maxLines: 4,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Requis' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<GravitePanne>(
                initialValue: _gravite,
                decoration: const InputDecoration(labelText: 'Gravité'),
                items: [
                  for (final g in GravitePanne.values)
                    DropdownMenuItem(value: g, child: Text(g.label)),
                ],
                onChanged: (g) =>
                    setState(() => _gravite = g ?? GravitePanne.legere),
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
          child: const Text('Signaler'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!validerFormulaire(context, _formKey)) return;
    setState(() => _envoi = true);
    final user = ref.read(sessionProvider)!.user;
    try {
      await ref
          .read(pannesProvider.notifier)
          .signaler(
            Panne(
              id: const Uuid().v4(),
              vehiculeId: widget.vehicule.id,
              description: _descriptionCtrl.text.trim(),
              gravite: _gravite,
              dateSignalement: DateTime.now(),
              signaleParId: user.id,
            ),
          );
      ref
          .read(auditProvider.notifier)
          .log(
            auteurId: user.id,
            action: 'PANNE_SIGNALEE',
            cible: widget.vehicule.immatriculation,
            detail: _descriptionCtrl.text.trim(),
          );
      if (mounted) {
        showSuccessSnackBar(context, 'Panne signalée.');
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
