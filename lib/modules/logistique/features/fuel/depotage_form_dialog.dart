import 'package:sig_ensoa/core/formulaire.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:sig_ensoa/core/theme.dart';
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
    // La ligne de dépotage ne retient que le stock visé ; la soute se
    // relit dessus pour repeupler la liste.
    final stock = ref
        .read(souteStocksProvider)
        .where((s) => s.id == d.souteStockId);
    if (stock.isNotEmpty) _souteId = stock.first.souteId;
  }

  @override
  Widget build(BuildContext context) {
    final soutes = ref.watch(soutesProvider);
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
              // Plus de choix de répartition : le carburant reçu entre dans
              // « Activités Ordinaires », la répartition d'accueil que
              // chaque soute reçoit à sa création. Un camion-citerne livre
              // dans la soute, pas dans une affectation ; la ventilation
              // est une décision qui vient après la réception.
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Le carburant entre dans « Activités Ordinaires ».',
                    style: TextStyle(fontSize: 12, color: AppColors.inkMuted),
                  ),
                ),
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
    if (!validerFormulaire(context, _formKey)) return;
    setState(() => _envoi = true);
    final user = ref.read(sessionProvider)!.user;
    try {
      // Le référentiel des types de carburant ne sert plus à viser la ligne
      // de stock : une ligne porte le gasoil et le super dans deux colonnes,
      // et c'est `type_carburant` sur le dépotage qui dit laquelle créditer.
      //
      // La ligne d'accueil, elle, existe toujours : la base la crée avec la
      // soute. Si elle manque, c'est que la soute a été posée hors de
      // l'application avant cette règle — on le dit plutôt que d'enregistrer
      // ailleurs sans prévenir.
      final souteStockId = await ref
          .read(souteStocksProvider.notifier)
          .ligneDAccueil(_souteId!, ref.read(repartitionsProvider));
      if (!mounted) return;
      if (souteStockId == null) {
        setState(() => _envoi = false);
        showErrorSnackBar(
          context,
          Exception(
            'Cette soute n\'a pas de répartition « Activités Ordinaires ». '
            'Signalez-le au chef du soutien technique.',
          ),
        );
        return;
      }
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
          _correction
              ? 'Dépotage modifié.'
              : 'Dépotage enregistré avec succès.',
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
