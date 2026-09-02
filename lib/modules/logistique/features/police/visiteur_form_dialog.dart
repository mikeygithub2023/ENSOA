import 'package:sig_ensoa/core/formulaire.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import 'package:sig_ensoa/modules/logistique/compat.dart';
import 'package:sig_ensoa/core/theme.dart';
import '../../data/models/police.dart';
import '../../data/repositories/misc_providers.dart';
import '../../data/repositories/police_providers.dart';
import '../../shared/widgets/widgets.dart';

class VisiteurFormDialog extends ConsumerStatefulWidget {
  const VisiteurFormDialog({super.key});

  @override
  ConsumerState<VisiteurFormDialog> createState() => _VisiteurFormDialogState();
}

class _VisiteurFormDialogState extends ConsumerState<VisiteurFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _contactVisiteurCtrl = TextEditingController();
  final _nomVisiteurCtrl = TextEditingController();
  final _contactRecuCtrl = TextEditingController();
  final _nomRecuCtrl = TextEditingController();
  final _immatriculationCtrl = TextEditingController();
  final _vehiculeDescriptionCtrl = TextEditingController();
  final _accompagnantsCtrl = TextEditingController();
  CouleurBadge _badge = CouleurBadge.rouge;
  String? _photoBase64;
  bool _envoi = false;
  bool _rechercheVisiteur = false;
  bool _rechercheRecu = false;

  /// Repliés par défaut : la plupart des visiteurs viennent seuls et à pied.
  /// Les déplier n'est qu'un geste, les imposer à chaque saisie en serait un
  /// de trop au poste de garde.
  bool _avecVehicule = false;
  bool _accompagne = false;
  int _nombreAccompagnants = 1;

  @override
  void dispose() {
    _contactVisiteurCtrl.dispose();
    _nomVisiteurCtrl.dispose();
    _contactRecuCtrl.dispose();
    _nomRecuCtrl.dispose();
    _immatriculationCtrl.dispose();
    _vehiculeDescriptionCtrl.dispose();
    _accompagnantsCtrl.dispose();
    super.dispose();
  }

  Future<void> _rechercher({required bool visiteur}) async {
    final ctrl = visiteur ? _contactVisiteurCtrl : _contactRecuCtrl;
    final contact = ctrl.text.trim();
    if (contact.isEmpty) return;
    setState(
      () => visiteur ? _rechercheVisiteur = true : _rechercheRecu = true,
    );
    try {
      final nom = await ref
          .read(passagesVisiteursProvider.notifier)
          .rechercherNomParContact(contact, visiteur: visiteur);
      if (nom != null && mounted) {
        setState(
          () =>
              visiteur ? _nomVisiteurCtrl.text = nom : _nomRecuCtrl.text = nom,
        );
      }
    } finally {
      if (mounted) {
        setState(
          () => visiteur ? _rechercheVisiteur = false : _rechercheRecu = false,
        );
      }
    }
  }

  Future<void> _prendrePhoto() async {
    final photo = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 640,
      imageQuality: 60,
    );
    if (photo == null) return;
    final octets = await photo.readAsBytes();
    setState(() => _photoBase64 = base64Encode(octets));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: const Text('Nouvelle visite'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('Visiteur'),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: _prendrePhoto,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.blueMist,
                        borderRadius: BorderRadius.circular(14),
                        image: _photoBase64 == null
                            ? null
                            : DecorationImage(
                                image: MemoryImage(base64Decode(_photoBase64!)),
                                fit: BoxFit.cover,
                              ),
                      ),
                      child: _photoBase64 == null
                          ? const Icon(
                              Icons.camera_alt_outlined,
                              color: AppColors.inkMuted,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _contactVisiteurCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Contact',
                                ),
                                keyboardType: TextInputType.phone,
                                validator: (v) => v == null || v.trim().isEmpty
                                    ? 'Requis'
                                    : null,
                                onEditingComplete: () =>
                                    _rechercher(visiteur: true),
                                onTapOutside: (_) =>
                                    _rechercher(visiteur: true),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filledTonal(
                              tooltip: 'Rechercher',
                              onPressed: _rechercheVisiteur
                                  ? null
                                  : () => _rechercher(visiteur: true),
                              icon: _rechercheVisiteur
                                  ? const SizedBox(
                                      height: 16,
                                      width: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.search),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nomVisiteurCtrl,
                decoration: const InputDecoration(labelText: 'Nom du visiteur'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Requis' : null,
              ),
              const SizedBox(height: 12),
              Text(
                'Couleur du badge',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.inkMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                children: [
                  for (final c in CouleurBadge.values)
                    GestureDetector(
                      onTap: () => setState(() => _badge = c),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: c.couleur,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _badge == c
                                ? AppColors.navy
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: _badge == c
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 18,
                              )
                            : null,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              _sectionTitle('Véhicule'),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: _avecVehicule,
                onChanged: (v) => setState(() => _avecVehicule = v),
                title: const Text('Le visiteur vient avec un véhicule'),
              ),
              if (_avecVehicule) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _immatriculationCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Immatriculation',
                    hintText: 'ex. 1234 AB 01',
                  ),
                  textCapitalization: TextCapitalization.characters,
                  validator: (v) =>
                      _avecVehicule && (v == null || v.trim().isEmpty)
                      ? 'Requis'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _vehiculeDescriptionCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Marque, modèle, couleur (facultatif)',
                    hintText: 'ex. Toyota Hilux blanc',
                  ),
                ),
              ],
              const SizedBox(height: 20),
              _sectionTitle('Accompagnants'),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: _accompagne,
                onChanged: (v) => setState(() => _accompagne = v),
                title: const Text('Le visiteur est accompagné'),
              ),
              if (_accompagne) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Nombre', style: TextStyle(fontSize: 13)),
                    const Spacer(),
                    // Un compteur plutôt qu'un champ à saisir : au portail,
                    // on compte les têtes, on ne tape pas un nombre.
                    IconButton.filledTonal(
                      tooltip: 'Un de moins',
                      onPressed: _nombreAccompagnants > 1
                          ? () => setState(() => _nombreAccompagnants--)
                          : null,
                      icon: const Icon(Icons.remove),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        '$_nombreAccompagnants',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton.filledTonal(
                      tooltip: 'Un de plus',
                      onPressed: _nombreAccompagnants < 200
                          ? () => setState(() => _nombreAccompagnants++)
                          : null,
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _accompagnantsCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Noms des accompagnants (facultatif)',
                    hintText: 'un par ligne, ou séparés par des virgules',
                  ),
                  minLines: 2,
                  maxLines: 4,
                ),
              ],
              const SizedBox(height: 20),
              _sectionTitle('Personne visitée'),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _contactRecuCtrl,
                      decoration: const InputDecoration(labelText: 'Contact'),
                      keyboardType: TextInputType.phone,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Requis' : null,
                      onEditingComplete: () => _rechercher(visiteur: false),
                      onTapOutside: (_) => _rechercher(visiteur: false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: 'Rechercher',
                    onPressed: _rechercheRecu
                        ? null
                        : () => _rechercher(visiteur: false),
                    icon: _rechercheRecu
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nomRecuCtrl,
                decoration: const InputDecoration(labelText: 'Nom'),
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
          child: const Text('Enregistrer l\'arrivée'),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      title,
      style: const TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 13,
        color: AppColors.inkMuted,
      ),
    ),
  );

  Future<void> _submit() async {
    if (!validerFormulaire(context, _formKey)) return;
    setState(() => _envoi = true);
    final user = ref.read(sessionProvider)!.user;
    try {
      await ref
          .read(passagesVisiteursProvider.notifier)
          .enregistrerArrivee(
            PassageVisiteur(
              id: const Uuid().v4(),
              contactVisiteur: _contactVisiteurCtrl.text.trim(),
              nomVisiteur: _nomVisiteurCtrl.text.trim(),
              photoBase64: _photoBase64,
              couleurBadge: _badge,
              contactRecu: _contactRecuCtrl.text.trim(),
              nomRecu: _nomRecuCtrl.text.trim(),
              dateArrivee: DateTime.now(),
              enregistrePar: user.id,
              vehiculeImmatriculation: _avecVehicule
                  ? _immatriculationCtrl.text.trim().toUpperCase()
                  : null,
              vehiculeDescription:
                  _avecVehicule &&
                      _vehiculeDescriptionCtrl.text.trim().isNotEmpty
                  ? _vehiculeDescriptionCtrl.text.trim()
                  : null,
              nombreAccompagnants: _accompagne ? _nombreAccompagnants : 0,
              accompagnants:
                  _accompagne && _accompagnantsCtrl.text.trim().isNotEmpty
                  ? _accompagnantsCtrl.text.trim()
                  : null,
            ),
          );
      ref
          .read(auditProvider.notifier)
          .log(
            auteurId: user.id,
            action: 'VISITEUR_ARRIVE',
            cible: _nomVisiteurCtrl.text.trim(),
            // Le véhicule et l'effectif entrent au journal : c'est ce qu'on
            // relit quand on cherche qui était dans le camp ce jour-là.
            detail: [
              'Reçu par ${_nomRecuCtrl.text.trim()}',
              'badge ${_badge.label}',
              if (_accompagne) '+$_nombreAccompagnants accompagnant(s)',
              if (_avecVehicule)
                'véhicule ${_immatriculationCtrl.text.trim().toUpperCase()}',
            ].join(' — '),
          );
      if (mounted) {
        showSuccessSnackBar(context, 'Arrivée enregistrée avec succès.');
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
