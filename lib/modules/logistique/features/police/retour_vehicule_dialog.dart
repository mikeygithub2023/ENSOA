import 'package:sig_ensoa/core/formulaire.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sig_ensoa/modules/logistique/compat.dart';
import '../../data/models/police.dart';
import '../../data/models/vehicule.dart';
import '../../data/repositories/fleet_providers.dart';
import '../../data/repositories/misc_providers.dart';
import '../../data/repositories/police_providers.dart';
import '../../shared/widgets/widgets.dart';

/// Contrôle d'entrée d'un véhicule au camp — seul le kilométrage est saisi,
/// la date/heure de retour est horodatée automatiquement à l'envoi.
class RetourVehiculeDialog extends ConsumerStatefulWidget {
  final PassageVehicule passage;
  final Vehicule vehicule;
  const RetourVehiculeDialog({
    super.key,
    required this.passage,
    required this.vehicule,
  });

  @override
  ConsumerState<RetourVehiculeDialog> createState() =>
      _RetourVehiculeDialogState();
}

class _RetourVehiculeDialogState extends ConsumerState<RetourVehiculeDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _kmCtrl = TextEditingController(
    text: '${widget.vehicule.kilometrage}',
  );
  bool _envoi = false;

  @override
  void dispose() {
    _kmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: const Text('Retour de véhicule'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 320,
          child: TextFormField(
            controller: _kmCtrl,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Kilométrage à l\'arrivée',
            ),
            keyboardType: TextInputType.number,
            validator: (v) {
              final km = int.tryParse(v ?? '');
              if (km == null) return 'Kilométrage invalide';
              if (km < widget.vehicule.kilometrage) {
                return 'Inférieur au kilométrage actuel (${widget.vehicule.kilometrage} km)';
              }
              return null;
            },
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
          child: const Text('Enregistrer le retour'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!validerFormulaire(context, _formKey)) return;
    setState(() => _envoi = true);
    final user = ref.read(sessionProvider)!.user;
    try {
      final km = int.parse(_kmCtrl.text);
      await ref
          .read(passagesVehiculesProvider.notifier)
          .enregistrerRetour(
            widget.passage.id,
            vehiculeId: widget.vehicule.id,
            kmRetour: km,
          );
      await ref
          .read(vehiculesProvider.notifier)
          .updateEtat(widget.vehicule.id, EtatVehicule.disponible);
      final mouvementId = widget.passage.mouvementId;
      if (mouvementId != null) {
        await ref
            .read(mouvementsVehiculeProvider.notifier)
            .cloturer(mouvementId, kmArrivee: km);
      }
      ref
          .read(auditProvider.notifier)
          .log(
            auteurId: user.id,
            action: 'VEHICULE_RETOUR_CAMP',
            cible: widget.vehicule.immatriculation,
            detail: '$km km',
          );
      // CST et Garage sont prévenus par le déclencheur
      // `notifier_retour_au_camp`, qui écrit une notification par personne.
      // L'application en écrivait une seule pour tout un rôle, que le
      // premier lecteur éteignait pour ses collègues.
      if (mounted) {
        showSuccessSnackBar(context, 'Retour enregistré avec succès.');
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
