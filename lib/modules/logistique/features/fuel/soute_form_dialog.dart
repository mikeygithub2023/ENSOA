import 'package:sig_ensoa/core/formulaire.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/carburant.dart';
import '../../data/repositories/fuel_providers.dart';
import '../../shared/widgets/widgets.dart';

/// Création d'une soute, ou modification de son libellé.
///
/// Un seul formulaire pour les deux : une soute ne porte que son libellé, et
/// deux boîtes de dialogue pour un champ unique ne se justifieraient pas.
/// [soute] renseignée bascule en modification.
class SouteFormDialog extends ConsumerStatefulWidget {
  const SouteFormDialog({super.key, this.soute});

  final Soute? soute;

  @override
  ConsumerState<SouteFormDialog> createState() => _SouteFormDialogState();
}

class _SouteFormDialogState extends ConsumerState<SouteFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _libelleCtrl;
  bool _envoi = false;

  bool get _modification => widget.soute != null;

  @override
  void initState() {
    super.initState();
    _libelleCtrl = TextEditingController(text: widget.soute?.libelle);
  }

  @override
  void dispose() {
    _libelleCtrl.dispose();
    super.dispose();
  }

  Future<void> _valider() async {
    if (!validerFormulaire(context, _formKey)) return;
    setState(() => _envoi = true);
    final libelle = _libelleCtrl.text.trim();
    try {
      final notifier = ref.read(soutesProvider.notifier);
      if (_modification) {
        await notifier.modifier(widget.soute!.id, libelle);
      } else {
        await notifier.creer(libelle);
      }
      if (mounted) {
        showSuccessSnackBar(
          context,
          _modification
              ? 'Soute modifiée avec succès.'
              : 'Soute créée avec succès.',
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: Text(_modification ? 'Modifier la soute' : 'Nouvelle soute'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _libelleCtrl,
          decoration: const InputDecoration(
            labelText: 'Libellé (ex. Soute Bouaké)',
          ),
          validator: (v) => v == null || v.trim().isEmpty ? 'Requis' : null,
          autofocus: true,
          onFieldSubmitted: (_) => _envoi ? null : _valider(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _envoi ? null : _valider,
          child: Text(_modification ? 'Enregistrer' : 'Créer'),
        ),
      ],
    );
  }
}
