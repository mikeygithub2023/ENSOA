import 'package:sig_ensoa/core/formulaire.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:sig_ensoa/modules/logistique/compat.dart';
import 'package:sig_ensoa/core/theme.dart';
import '../../data/models/mouvement_vehicule.dart';
import '../../data/models/vehicule.dart';
import '../../data/repositories/fleet_providers.dart';
import '../../data/repositories/misc_providers.dart';
import '../../shared/widgets/widgets.dart';

/// Formulaire de création d'un mouvement (mission/déplacement) pour le
/// véhicule dont on vient de la fiche détail — le véhicule est fixé à
/// l'ouverture (id conservé côté état, jamais ressaisi).
class MouvementFormDialog extends ConsumerStatefulWidget {
  final Vehicule vehicule;
  const MouvementFormDialog({super.key, required this.vehicule});

  @override
  ConsumerState<MouvementFormDialog> createState() =>
      _MouvementFormDialogState();
}

class _MouvementFormDialogState extends ConsumerState<MouvementFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _gradeCtrl = TextEditingController();
  final _nomCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _objetCtrl = TextEditingController();
  final _destinationCtrl = TextEditingController();

  bool _envoi = false;

  @override
  void dispose() {
    _gradeCtrl.dispose();
    _nomCtrl.dispose();
    _contactCtrl.dispose();
    _objetCtrl.dispose();
    _destinationCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vehicule = widget.vehicule;
    return AlertDialog(
      scrollable: true,
      title: Text('Nouvel ordre de mission — ${vehicule.immatriculation}'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.blueMist,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${vehicule.marque} ${vehicule.modele} — ${vehicule.kilometrage} km',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _gradeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Grade (ou "Civil")',
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Requis' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _nomCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nom du conducteur',
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Requis' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contactCtrl,
                decoration: const InputDecoration(
                  labelText: 'Contact téléphonique',
                ),
                keyboardType: TextInputType.phone,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Requis' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _objetCtrl,
                decoration: const InputDecoration(
                  labelText: 'Objet de la mission',
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Requis' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _destinationCtrl,
                decoration: const InputDecoration(labelText: 'Destination'),
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
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!validerFormulaire(context, _formKey)) return;
    final vehicule = widget.vehicule;
    if (vehicule.etat != EtatVehicule.disponible) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ce véhicule n\'est plus disponible.')),
      );
      return;
    }
    setState(() => _envoi = true);
    final user = ref.read(sessionProvider)!.user;
    try {
      await ref
          .read(mouvementsVehiculeProvider.notifier)
          .add(
            MouvementVehicule(
              id: const Uuid().v4(),
              objet: _objetCtrl.text.trim(),
              dateDepart: DateTime.now(),
              vehiculeId: vehicule.id,
              utilisateurId: user.id,
              kmDepart: vehicule.kilometrage,
              destination: _destinationCtrl.text.trim(),
              gradeChefBord: _gradeCtrl.text.trim(),
              nomChefBord: _nomCtrl.text.trim(),
              contactChefBord: _contactCtrl.text.trim(),
            ),
          );
      await ref
          .read(vehiculesProvider.notifier)
          .updateEtat(vehicule.id, EtatVehicule.enMission);
      ref
          .read(auditProvider.notifier)
          .log(
            auteurId: user.id,
            action: 'MOUVEMENT_CREE',
            cible: vehicule.immatriculation,
            detail:
                '${_objetCtrl.text.trim()} vers ${_destinationCtrl.text.trim()}',
          );
      if (mounted) {
        showSuccessSnackBar(context, 'Mouvement enregistré avec succès.');
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
