import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:sig_ensoa/modules/logistique/compat.dart';
import '../../data/models/carburant.dart';
import '../../data/repositories/fuel_providers.dart';
import '../../data/repositories/misc_providers.dart';
import '../../shared/widgets/widgets.dart';

/// Enregistre un dépotage, ou corrige un dépotage déjà enregistré — la même
/// boîte pour les deux : les champs sont les mêmes, seul le verbe change.
class DepotageFormDialog extends ConsumerStatefulWidget {
  const DepotageFormDialog({super.key, this.existant});

  /// Le dépotage à corriger. Nul pour une nouvelle réception.
  final Depotage? existant;

  @override
  ConsumerState<DepotageFormDialog> createState() => _DepotageFormDialogState();
}

class _DepotageFormDialogState extends ConsumerState<DepotageFormDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _souteId;
  String? _repartitionId;
  String _typeCarburant = 'Gasoil';
  final _qteCtrl = TextEditingController();
  bool _envoi = false;

  bool get _correction => widget.existant != null;

  @override
  void initState() {
    super.initState();
    final d = widget.existant;
    if (d == null) return;
    _typeCarburant = d.typeCarburant;
    _qteCtrl.text = '${d.quantiteRecue}';
    // La ligne de dépotage ne retient que le stock visé ; la soute et la
    // répartition se relisent dessus pour repeupler les deux listes.
    final stock = ref.read(souteStocksProvider).where((s) => s.id == d.souteStockId);
    if (stock.isNotEmpty) {
      _souteId = stock.first.souteId;
      _repartitionId = stock.first.repartitionId;
    }
  }

  @override
  Widget build(BuildContext context) {
    final soutes = ref.watch(soutesProvider);
    final repartitions = ref.watch(repartitionsProvider);
    return AlertDialog(
      scrollable: true,
      title: Text(_correction ? 'Modifier le dépotage' : 'Nouveau dépotage'),
      content: SizedBox(
        width: 380,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _souteId,
                decoration: const InputDecoration(
                  labelText: 'Soute (où le carburant est déposé)',
                ),
                items: [
                  for (final s in soutes)
                    DropdownMenuItem(value: s.id, child: Text(s.libelle)),
                ],
                onChanged: (v) => setState(() => _souteId = v),
                validator: (v) => v == null ? 'Requis' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _repartitionId,
                decoration: const InputDecoration(
                  labelText: 'Répartition bénéficiaire (ex. BA1)',
                ),
                items: [
                  for (final r in repartitions)
                    DropdownMenuItem(value: r.id, child: Text(r.libelle)),
                ],
                onChanged: (v) => setState(() => _repartitionId = v),
                validator: (v) => v == null ? 'Requis' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _typeCarburant,
                decoration: const InputDecoration(
                  labelText: 'Type de carburant',
                ),
                items: const [
                  DropdownMenuItem(value: 'Gasoil', child: Text('Gasoil')),
                  DropdownMenuItem(value: 'Super', child: Text('Super')),
                ],
                onChanged: (v) =>
                    setState(() => _typeCarburant = v ?? 'Gasoil'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _qteCtrl,
                decoration: const InputDecoration(labelText: 'Quantité (L)'),
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
    final user = ref.read(sessionProvider)!.user;
    try {
      var typesStock = ref.read(typesStockProvider);
      if (typesStock.isEmpty) {
        // Le référentiel Gasoil/Super n'a pas fini de charger (ex. juste après
        // le lancement de l'app) — on force un rafraîchissement avant d'échouer.
        await ref.read(typesStockProvider.notifier).refresh();
        typesStock = ref.read(typesStockProvider);
      }
      if (typesStock.isEmpty) {
        throw Exception(
          'Référentiel des types de carburant indisponible. Vérifiez la connexion et réessayez.',
        );
      }
      final typeStockId = typesStock
          .firstWhere(
            (t) => t.libelle.toLowerCase() == _typeCarburant.toLowerCase(),
            orElse: () => typesStock.first,
          )
          .id;
      final souteStockId = await ref
          .read(souteStocksProvider.notifier)
          .souteStockIdPour(
            souteId: _souteId!,
            repartitionId: _repartitionId!,
            typeStockId: typeStockId,
          );
      final ancien = widget.existant;
      final saisi = Depotage(
        // En correction, la ligne garde son identifiant et sa date : on
        // corrige une réception, on n'en invente pas une nouvelle.
        id: ancien?.id ?? const Uuid().v4(),
        date: ancien?.date ?? DateTime.now(),
        quantiteRecue: int.parse(_qteCtrl.text),
        typeCarburant: _typeCarburant,
        utilisateurId: ancien?.utilisateurId ?? user.id,
        souteStockId: souteStockId,
      );

      if (ancien == null) {
        await ref.read(depotagesProvider.notifier).add(saisi);
      } else {
        await ref.read(depotagesProvider.notifier).modifier(ancien, saisi);
      }

      ref
          .read(auditProvider.notifier)
          .log(
            auteurId: user.id,
            action: ancien == null ? 'DEPOTAGE_CREE' : 'DEPOTAGE_MODIFIE',
            cible: souteStockId,
            detail: '+${_qteCtrl.text} L $_typeCarburant',
          );
      if (mounted) {
        showSuccessSnackBar(
          context,
          _correction ? 'Dépotage modifié.' : 'Dépotage enregistré avec succès.',
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
