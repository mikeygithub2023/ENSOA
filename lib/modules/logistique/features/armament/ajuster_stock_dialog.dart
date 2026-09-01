import 'package:flutter/material.dart';

import '../../shared/widgets/widgets.dart';

/// Dialogue générique de réapprovisionnement/retrait de stock — utilisé pour
/// les munitions comme pour les équipements de protection individuelle.
class AjusterStockDialog extends StatefulWidget {
  final String titre;
  final String libelleArticle;
  final int quantiteActuelle;
  final Future<void> Function(int delta) onAjuster;

  const AjusterStockDialog({
    super.key,
    required this.titre,
    required this.libelleArticle,
    required this.quantiteActuelle,
    required this.onAjuster,
  });

  @override
  State<AjusterStockDialog> createState() => _AjusterStockDialogState();
}

class _AjusterStockDialogState extends State<AjusterStockDialog> {
  final _formKey = GlobalKey<FormState>();
  final _qteCtrl = TextEditingController();
  bool _entree = true;
  bool _envoi = false;

  @override
  void dispose() {
    _qteCtrl.dispose();
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.libelleArticle} — stock actuel : ${widget.quantiteActuelle}',
              ),
              const SizedBox(height: 16),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: true,
                    label: Text('Entrée'),
                    icon: Icon(Icons.add),
                  ),
                  ButtonSegment(
                    value: false,
                    label: Text('Sortie'),
                    icon: Icon(Icons.remove),
                  ),
                ],
                selected: {_entree},
                onSelectionChanged: (s) => setState(() => _entree = s.first),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _qteCtrl,
                decoration: const InputDecoration(labelText: 'Quantité'),
                keyboardType: TextInputType.number,
                validator: (v) => (int.tryParse(v ?? '') ?? 0) <= 0
                    ? 'Quantité invalide'
                    : null,
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
    final qte = int.parse(_qteCtrl.text);
    try {
      await widget.onAjuster(_entree ? qte : -qte);
      if (mounted) {
        showSuccessSnackBar(context, 'Stock mis à jour avec succès.');
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
