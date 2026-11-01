import 'package:sig_ensoa/core/formulaire.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:sig_ensoa/core/theme.dart';
import 'package:sig_ensoa/modules/logistique/compat.dart';
import 'package:sig_ensoa/features/auth/providers/auth_providers.dart';
import '../../data/models/pannes.dart';
import '../../data/models/vehicule.dart';
import '../../data/repositories/misc_providers.dart';
import '../../data/repositories/pannes_providers.dart';
import '../../shared/widgets/widgets.dart';

/// Demande de mise en réparation d'un véhicule.
///
/// Elle se lit au vu des pannes : on les reprend par puce, on y joint une
/// observation, et la demande part à la validation d'un supérieur. Le véhicule
/// ne passe « En réparation » qu'à cette validation, pas ici.
class DemandeReparationFormDialog extends ConsumerStatefulWidget {
  final Vehicule vehicule;
  const DemandeReparationFormDialog({super.key, required this.vehicule});

  @override
  ConsumerState<DemandeReparationFormDialog> createState() =>
      _DemandeReparationFormDialogState();
}

class _DemandeReparationFormDialogState
    extends ConsumerState<DemandeReparationFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _observationsCtrl = TextEditingController();
  bool _envoi = false;

  @override
  void dispose() {
    _observationsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pannes = ref.watch(pannesOuvertesProvider(widget.vehicule.id));
    final profil = ref.watch(profilCourantProvider).value;
    final demandeur = profil == null
        ? '—'
        : '${profil.nom} ${profil.prenom}'.trim();
    final aujourdhui = DateFormat('dd/MM/yyyy').format(DateTime.now());

    return AlertDialog(
      scrollable: true,
      title: Text(
        'Demande de mise en réparation — ${widget.vehicule.immatriculation}',
      ),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _LigneInfo(libelle: 'Date de la demande', valeur: aujourdhui),
              _LigneInfo(libelle: 'Demandée par', valeur: demandeur),
              const SizedBox(height: 16),
              const Text(
                'Pannes relevées',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
              const SizedBox(height: 8),
              if (pannes.isEmpty)
                const Text(
                  'Aucune panne signalée sur ce véhicule. Signalez d\'abord une '
                  'panne avant d\'en demander la mise en réparation.',
                  style: TextStyle(color: AppColors.danger, fontSize: 13),
                )
              else
                for (final p in pannes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('•  '),
                        Expanded(
                          child: Text(
                            '[${p.gravite.label}] ${p.description}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _observationsCtrl,
                decoration: const InputDecoration(
                  labelText: 'Observations',
                  alignLabelWithHint: true,
                ),
                minLines: 2,
                maxLines: 4,
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
          onPressed: (_envoi || pannes.isEmpty) ? null : _submit,
          child: const Text('Envoyer la demande'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!validerFormulaire(context, _formKey)) return;
    final pannes = ref.read(pannesOuvertesProvider(widget.vehicule.id));
    if (pannes.isEmpty) return;

    setState(() => _envoi = true);
    final user = ref.read(sessionProvider)!.user;
    try {
      await ref
          .read(demandesReparationProvider.notifier)
          .demander(
            vehiculeId: widget.vehicule.id,
            demandeParId: user.id,
            commentaire: _observationsCtrl.text.trim().isEmpty
                ? null
                : _observationsCtrl.text.trim(),
            panneIds: pannes.map((p) => p.id).toList(),
          );
      ref
          .read(auditProvider.notifier)
          .log(
            auteurId: user.id,
            action: 'DEMANDE_REPARATION_CREEE',
            cible: widget.vehicule.immatriculation,
            detail: '${pannes.length} panne(s) — en attente de validation',
          );
      if (mounted) {
        showSuccessSnackBar(
          context,
          'Demande envoyée — en attente de validation.',
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

class _LigneInfo extends StatelessWidget {
  const _LigneInfo({required this.libelle, required this.valeur});

  final String libelle;
  final String valeur;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: Text(
              libelle,
              style: const TextStyle(
                color: AppColors.inkMuted,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              valeur,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
