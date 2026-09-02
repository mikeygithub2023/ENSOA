import 'package:sig_ensoa/core/formulaire.dart';
import 'package:flutter/material.dart';

import '../../shared/widgets/widgets.dart';

/// Dialogue générique de création d'un nouvel article de stock (calibre de
/// munition ou équipement de protection individuelle).
class NouvelArticleDialog extends StatefulWidget {
  final String titre;
  final String labelLibelle;
  final Future<void> Function({
    required String libelle,
    required int quantiteInitiale,
    required int seuilCritique,
  })
  onCreer;

  const NouvelArticleDialog({
    super.key,
    required this.titre,
    required this.labelLibelle,
    required this.onCreer,
  });

  @override
  State<NouvelArticleDialog> createState() => _NouvelArticleDialogState();
}

class _NouvelArticleDialogState extends State<NouvelArticleDialog> {
  final _formKey = GlobalKey<FormState>();
  final _libelleCtrl = TextEditingController();
  final _quantiteCtrl = TextEditingController(text: '0');
  final _seuilCtrl = TextEditingController(text: '0');
  bool _envoi = false;

  @override
  void dispose() {
    _libelleCtrl.dispose();
    _quantiteCtrl.dispose();
    _seuilCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: Text(widget.titre),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _libelleCtrl,
                decoration: InputDecoration(labelText: widget.labelLibelle),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Requis' : null,
                autofocus: true,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _quantiteCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Quantité initiale',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) =>
                          (int.tryParse(v ?? '') ?? -1) < 0 ? 'Invalide' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _seuilCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Seuil critique',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) =>
                          (int.tryParse(v ?? '') ?? -1) < 0 ? 'Invalide' : null,
                    ),
                  ),
                ],
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
    if (!validerFormulaire(context, _formKey)) return;
    setState(() => _envoi = true);
    try {
      await widget.onCreer(
        libelle: _libelleCtrl.text.trim(),
        quantiteInitiale: int.parse(_quantiteCtrl.text),
        seuilCritique: int.parse(_seuilCtrl.text),
      );
      if (mounted) {
        showSuccessSnackBar(context, 'Créé avec succès.');
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
