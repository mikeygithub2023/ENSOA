import 'package:sig_ensoa/core/formulaire.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sig_ensoa/modules/logistique/compat.dart';
import 'package:sig_ensoa/core/theme.dart';
import '../../data/models/vehicule.dart';
import '../../data/repositories/fleet_providers.dart';
import '../../data/repositories/misc_providers.dart';
import '../../shared/widgets/widgets.dart';
import 'nouveau_type_vehicule_dialog.dart';

/// Formulaire véhicule — création si [vehicule] est nul, modification sinon
/// (le kilométrage reste en lecture seule à l'édition : il est piloté par
/// les missions/le poste de police, pas saisi ici).
class VehicleFormDialog extends ConsumerStatefulWidget {
  final Vehicule? vehicule;
  const VehicleFormDialog({super.key, this.vehicule});

  @override
  ConsumerState<VehicleFormDialog> createState() => _VehicleFormDialogState();
}

class _VehicleFormDialogState extends ConsumerState<VehicleFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _chassisCtrl = TextEditingController(
    text: widget.vehicule?.chassis ?? '',
  );
  late final _immatCtrl = TextEditingController(
    text: widget.vehicule?.immatriculation ?? '',
  );
  late final _kmCtrl = TextEditingController(
    text: '${widget.vehicule?.kilometrage ?? 0}',
  );
  late final _placesCtrl = TextEditingController(
    text: '${widget.vehicule?.nbrePlaces ?? 5}',
  );
  // Un véhicule nouvellement enregistré est présumé au garage central : c'est
  // la valeur exacte requise pour que "Créer un mouvement" apparaisse ensuite
  // sur sa fiche (voir vehicle_detail_screen.dart).
  late final _positionCtrl = TextEditingController(
    text: widget.vehicule?.positionActuelle ?? 'Garage central ENSOA',
  );
  String? _typeVehiculeId;
  bool _envoi = false;

  bool get _edition => widget.vehicule != null;

  @override
  void initState() {
    super.initState();
    _typeVehiculeId = widget.vehicule?.typeVehiculeId;
  }

  @override
  void dispose() {
    _chassisCtrl.dispose();
    _immatCtrl.dispose();
    _kmCtrl.dispose();
    _placesCtrl.dispose();
    _positionCtrl.dispose();
    super.dispose();
  }

  Future<void> _nouveauType() async {
    final id = await showDialog<String>(
      context: context,
      builder: (_) => const NouveauTypeVehiculeDialog(),
    );
    if (id != null) setState(() => _typeVehiculeId = id);
  }

  @override
  Widget build(BuildContext context) {
    final typesRef = ref.watch(typesVehiculeRefProvider);
    final seuilVidange = (int.tryParse(_kmCtrl.text) ?? 0) + 5000;
    return AlertDialog(
      scrollable: true,
      title: Text(_edition ? 'Modifier le véhicule' : 'Nouveau véhicule'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _immatCtrl,
                decoration: const InputDecoration(labelText: 'Immatriculation'),
                validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _chassisCtrl,
                decoration: const InputDecoration(labelText: 'N° de châssis'),
                validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _typeVehiculeId,
                      decoration: const InputDecoration(
                        labelText: 'Marque / Modèle / Type',
                      ),
                      items: [
                        for (final t in typesRef)
                          DropdownMenuItem(value: t.id, child: Text(t.label)),
                      ],
                      onChanged: (v) => setState(() => _typeVehiculeId = v),
                      validator: (v) =>
                          v == null ? 'Requis (référentiel Supabase)' : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: 'Nouvelle marque/modèle/type',
                    onPressed: _nouveauType,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _kmCtrl,
                      enabled: !_edition,
                      decoration: InputDecoration(
                        labelText: 'Kilométrage',
                        helperText: _edition
                            ? 'Mis à jour via les missions / le poste de police'
                            : null,
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _placesCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de places',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: AppColors.blueMist,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.event_repeat_outlined,
                      size: 18,
                      color: AppColors.navy,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Prochain seuil de vidange : $seuilVidange km',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _positionCtrl,
                decoration: const InputDecoration(
                  labelText: 'Position actuelle / affectation',
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
          child: Text(_edition ? 'Enregistrer' : 'Enregistrer'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!validerFormulaire(context, _formKey)) return;
    setState(() => _envoi = true);
    final user = ref.read(sessionProvider)?.user;
    final seuilVidange = (int.tryParse(_kmCtrl.text) ?? 0) + 5000;
    try {
      if (_edition) {
        await ref
            .read(vehiculesProvider.notifier)
            .update(
              id: widget.vehicule!.id,
              chassis: _chassisCtrl.text.trim(),
              immatriculation: _immatCtrl.text.trim(),
              nbrePlaces: int.tryParse(_placesCtrl.text) ?? 5,
              positionActuelle: _positionCtrl.text.trim().isEmpty
                  ? null
                  : _positionCtrl.text.trim(),
              typeVehiculeId: _typeVehiculeId!,
              kilometrageVidangeProchaine: seuilVidange,
            );
        if (user != null) {
          ref
              .read(auditProvider.notifier)
              .log(
                auteurId: user.id,
                action: 'VEHICULE_MODIFIE',
                cible: _immatCtrl.text.trim(),
              );
        }
      } else {
        await ref
            .read(vehiculesProvider.notifier)
            .add(
              chassis: _chassisCtrl.text.trim(),
              immatriculation: _immatCtrl.text.trim(),
              kilometrage: int.tryParse(_kmCtrl.text) ?? 0,
              nbrePlaces: int.tryParse(_placesCtrl.text) ?? 5,
              positionActuelle: _positionCtrl.text.trim().isEmpty
                  ? null
                  : _positionCtrl.text.trim(),
              typeVehiculeId: _typeVehiculeId!,
              kilometrageVidangeProchaine: seuilVidange,
            );
        if (user != null) {
          ref
              .read(auditProvider.notifier)
              .log(
                auteurId: user.id,
                action: 'VEHICULE_CREE',
                cible: _immatCtrl.text.trim(),
              );
        }
      }
      if (mounted) {
        showSuccessSnackBar(
          context,
          _edition
              ? 'Véhicule modifié avec succès.'
              : 'Véhicule enregistré avec succès.',
        );
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
