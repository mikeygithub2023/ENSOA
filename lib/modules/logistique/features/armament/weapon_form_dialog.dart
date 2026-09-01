import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:sig_ensoa/modules/logistique/compat.dart';
import '../../data/models/armement.dart';
import '../../data/repositories/armament_providers.dart';
import '../../data/repositories/misc_providers.dart';
import '../../shared/widgets/widgets.dart';

/// Formulaire arme — création si [arme] est nul, modification sinon (état,
/// dates d'inspection et acquisition restent pilotés par les autres écrans,
/// pas modifiables ici).
class WeaponFormDialog extends ConsumerStatefulWidget {
  final Arme? arme;
  const WeaponFormDialog({super.key, this.arme});

  @override
  ConsumerState<WeaponFormDialog> createState() => _WeaponFormDialogState();
}

class _WeaponFormDialogState extends ConsumerState<WeaponFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _serieCtrl = TextEditingController(
    text: widget.arme?.numeroSerie ?? '',
  );
  late final _modeleCtrl = TextEditingController(
    text: widget.arme?.modele ?? '',
  );
  String? _typeArmeLibelle;
  bool _envoi = false;

  bool get _edition => widget.arme != null;

  @override
  void initState() {
    super.initState();
    _typeArmeLibelle = widget.arme?.type;
  }

  @override
  void dispose() {
    _serieCtrl.dispose();
    _modeleCtrl.dispose();
    super.dispose();
  }

  Future<void> _nouveauType() async {
    final ctrl = TextEditingController();
    final libelle = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Nouveau type d\'arme'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Libellé'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(ctrl.text.trim()),
            child: const Text('Créer'),
          ),
        ],
      ),
    );
    if (libelle == null || libelle.isEmpty) return;
    await ref.read(typesArmeProvider.notifier).creer(libelle);
    setState(() => _typeArmeLibelle = libelle);
  }

  @override
  Widget build(BuildContext context) {
    final types = ref.watch(typesArmeProvider);
    return AlertDialog(
      scrollable: true,
      title: Text(_edition ? 'Modifier l\'arme' : 'Enregistrer une arme'),
      content: SizedBox(
        width: 380,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _serieCtrl,
                decoration: const InputDecoration(labelText: 'Numéro de série'),
                validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _typeArmeLibelle,
                      decoration: const InputDecoration(
                        labelText: "Type d'arme",
                      ),
                      items: [
                        for (final t in types)
                          DropdownMenuItem(
                            value: t.libelle,
                            child: Text(t.libelle),
                          ),
                      ],
                      onChanged: (v) => setState(() => _typeArmeLibelle = v),
                      validator: (v) => v == null ? 'Requis' : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: 'Nouveau type',
                    onPressed: _nouveauType,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _modeleCtrl,
                decoration: const InputDecoration(labelText: 'Modèle'),
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
    if (!_formKey.currentState!.validate()) return;
    setState(() => _envoi = true);
    final user = ref.read(sessionProvider)!.user;
    try {
      if (_edition) {
        await ref
            .read(armesProvider.notifier)
            .update(
              id: widget.arme!.id,
              numeroSerie: _serieCtrl.text.trim(),
              type: _typeArmeLibelle!,
              modele: _modeleCtrl.text.trim(),
            );
        ref
            .read(auditProvider.notifier)
            .log(
              auteurId: user.id,
              action: 'ARME_MODIFIEE',
              cible: _serieCtrl.text.trim(),
              detail: '$_typeArmeLibelle — ${_modeleCtrl.text.trim()}',
            );
      } else {
        final now = DateTime.now();
        final arme = Arme(
          id: const Uuid().v4(),
          numeroSerie: _serieCtrl.text.trim(),
          type: _typeArmeLibelle!,
          modele: _modeleCtrl.text.trim(),
          etat: EtatArme.enArmurerie,
          dateAcquisition: now,
          prochaineInspection: now.add(const Duration(days: 90)),
        );
        await ref.read(armesProvider.notifier).add(arme);
        ref
            .read(auditProvider.notifier)
            .log(
              auteurId: user.id,
              action: 'ARME_ENREGISTREE',
              cible: arme.numeroSerie,
              detail: '${arme.type} — ${arme.modele}',
            );
      }
      if (mounted) {
        showSuccessSnackBar(
          context,
          _edition
              ? 'Arme modifiée avec succès.'
              : 'Arme enregistrée avec succès.',
        );
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
