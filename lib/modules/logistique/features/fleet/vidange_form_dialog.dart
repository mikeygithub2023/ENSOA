import 'package:sig_ensoa/core/formulaire.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import 'package:sig_ensoa/core/erreurs.dart';
import 'package:sig_ensoa/core/theme.dart';
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
  final _huileCtrl = TextEditingController();
  final _filtreCtrl = TextEditingController();
  final _qteCtrl = TextEditingController();
  final _seuilCtrl = TextEditingController();

  bool _envoi = false;
  String? _erreur;

  /// La vidange précédente de ce véhicule, s'il y en a une.
  Vidange? _precedente;

  @override
  void initState() {
    super.initState();

    // Un véhicule revient au garage avec la même huile, le même filtre et la
    // même contenance qu'à sa dernière vidange : les reproposer évite de
    // ressaisir trois fois la même chose, et surtout d'inventer une valeur
    // différente d'une fois sur l'autre.
    final vidanges = ref
        .read(vidangesProvider)
        .where((v) => v.vehiculeId == widget.vehicule.id)
        .toList();
    _precedente = vidanges.isEmpty ? null : vidanges.first;

    _huileCtrl.text = _precedente?.typeHuile ?? '15W40';
    _filtreCtrl.text = _precedente?.filtreVidange ?? 'Filtre standard';
    _qteCtrl.text = '${_precedente?.qteHuile ?? 8}';

    // L'intervalle aussi se reconduit : celui qu'on avait retenu la dernière
    // fois, plutôt qu'un 5 000 km de convention.
    final v = widget.vehicule;
    final intervallePrecedent = v.kilometrageVidangePrecedente == null
        ? null
        : v.kilometrageVidangeProchaine - v.kilometrageVidangePrecedente!;
    final intervalle = (intervallePrecedent != null && intervallePrecedent > 0)
        ? intervallePrecedent
        : 5000;
    _seuilCtrl.text = '${v.kilometrage + intervalle}';
  }

  @override
  void dispose() {
    _huileCtrl.dispose();
    _filtreCtrl.dispose();
    _qteCtrl.dispose();
    _seuilCtrl.dispose();
    super.dispose();
  }

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
              if (_precedente != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Repris de la vidange du '
                  '${DateFormat('dd/MM/yyyy').format(_precedente!.date)} — '
                  'corrigez ce qui a changé.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.inkMuted,
                  ),
                ),
              ],
              if (_erreur != null) ...[
                const SizedBox(height: 12),
                Text(
                  _erreur!,
                  style: const TextStyle(color: AppColors.danger, fontSize: 13),
                ),
              ],
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
      // Le message reste dans la boîte : un bandeau en bas d'écran passe
      // derrière le clavier de la tablette, et l'on ne sait plus pourquoi
      // l'enregistrement a échoué.
      if (mounted) {
        setState(() {
          _envoi = false;
          _erreur = messageErreur(e);
        });
      }
    }
  }
}
