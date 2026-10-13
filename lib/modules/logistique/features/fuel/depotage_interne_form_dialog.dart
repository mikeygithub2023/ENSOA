import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:sig_ensoa/core/formulaire.dart';
import 'package:sig_ensoa/core/format.dart';
import 'package:sig_ensoa/core/theme.dart';
import 'package:sig_ensoa/modules/logistique/compat.dart';
import '../../data/repositories/fuel_providers.dart';
import '../../data/repositories/misc_providers.dart';
import '../../shared/widgets/widgets.dart';

/// Ventiler le carburant d'une soute : des « Activités Ordinaires » vers une
/// autre répartition de la même soute.
///
/// Le carburant reçu entre toujours dans la répartition d'accueil ; c'est
/// d'elle qu'on sert les affectations. La boîte montre donc en permanence ce
/// qui reste disponible : proposer de ventiler plus que ce qu'on a, c'est
/// faire saisir une quantité que la base refusera.
class DepotageInterneFormDialog extends ConsumerStatefulWidget {
  const DepotageInterneFormDialog({super.key});

  @override
  ConsumerState<DepotageInterneFormDialog> createState() =>
      _DepotageInterneFormDialogState();
}

class _DepotageInterneFormDialogState
    extends ConsumerState<DepotageInterneFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _qteCtrl = TextEditingController();
  final _motifCtrl = TextEditingController();

  String? _souteId;
  String? _repartitionCibleId;
  String _typeCarburant = 'Gasoil';
  bool _envoi = false;

  @override
  void dispose() {
    _qteCtrl.dispose();
    _motifCtrl.dispose();
    super.dispose();
  }

  /// Ce que contient la répartition d'accueil de la soute choisie, pour le
  /// carburant choisi.
  int get _disponible {
    if (_souteId == null) return 0;
    final d = disponibleEnAccueil(ref, _souteId!);
    return _typeCarburant == 'Gasoil' ? d.gasoil : d.superCarburant;
  }

  @override
  Widget build(BuildContext context) {
    final soutes = ref.watch(soutesProvider);
    // La répartition d'accueil ne peut pas être sa propre destination.
    final cibles = ref
        .watch(repartitionsProvider)
        .where((r) => r.libelle != SouteStocksNotifier.activitesOrdinaires)
        .toList();

    return AlertDialog(
      scrollable: true,
      title: const Text('Dépotage interne'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _souteId,
                decoration: const InputDecoration(labelText: 'Soute'),
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
                initialValue: _typeCarburant,
                decoration: const InputDecoration(
                  labelText: 'Type de carburant',
                ),
                items: const [
                  DropdownMenuItem(value: 'Gasoil', child: Text('Gasoil')),
                  DropdownMenuItem(value: 'Super', child: Text('Super')),
                ],
                onChanged: (v) =>
                    setState(() => _typeCarburant = v ?? _typeCarburant),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _repartitionCibleId,
                decoration: const InputDecoration(
                  labelText: 'Répartition servie',
                  helperText:
                      'Elle recevra le carburant prélevé sur les Activités '
                      'Ordinaires.',
                  helperMaxLines: 2,
                ),
                items: [
                  for (final r in cibles)
                    DropdownMenuItem(value: r.id, child: Text(r.libelle)),
                ],
                onChanged: (v) => setState(() => _repartitionCibleId = v),
                validator: (v) => v == null ? 'Requis' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _qteCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Quantité (L)',
                  helperText: _souteId == null
                      ? 'Choisissez d\'abord une soute.'
                      : 'Disponible en Activités Ordinaires : '
                            '${formatMilliers(_disponible)} L de '
                            '${_typeCarburant.toLowerCase()}.',
                  helperMaxLines: 2,
                ),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  if (n == null || n <= 0) return 'Quantité invalide';
                  // La base refuse de toute façon ; le dire ici évite un
                  // aller-retour et une erreur serveur à déchiffrer.
                  if (n > _disponible) {
                    return 'Il n\'y a que ${formatMilliers(_disponible)} L';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _motifCtrl,
                decoration: const InputDecoration(
                  labelText: 'Motif (facultatif)',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _envoi ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _envoi ? null : _soumettre,
          child: const Text('Ventiler'),
        ),
      ],
    );
  }

  Future<void> _soumettre() async {
    if (!validerFormulaire(context, _formKey)) return;
    setState(() => _envoi = true);
    final user = ref.read(sessionProvider)!.user;
    final quantite = int.parse(_qteCtrl.text);
    final motif = _motifCtrl.text.trim();

    try {
      await ref
          .read(depotagesInternesProvider.notifier)
          .depoter(
            souteId: _souteId!,
            repartitionCibleId: _repartitionCibleId!,
            typeCarburant: _typeCarburant,
            quantite: quantite,
            motif: motif.isEmpty ? null : motif,
          );

      final cible = ref
          .read(repartitionsProvider)
          .firstWhere((r) => r.id == _repartitionCibleId);
      ref
          .read(auditProvider.notifier)
          .log(
            auteurId: user.id,
            action: 'DEPOTAGE_INTERNE',
            cible: cible.libelle,
            detail:
                '${formatMilliers(quantite)} L de $_typeCarburant '
                'vers ${cible.libelle}',
          );

      if (mounted) {
        showSuccessSnackBar(
          context,
          '${formatMilliers(quantite)} L transférés vers ${cible.libelle}.',
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

/// Le journal des ventilations — qui a servi quelle répartition, et quand.
class DepotagesInternesTabContent extends ConsumerWidget {
  const DepotagesInternesTabContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transferts = ref.watch(depotagesInternesProvider);

    if (transferts.isEmpty) {
      return const EmptyState(
        message:
            'Aucune ventilation. Le carburant reçu reste en Activités '
            'Ordinaires jusqu\'à ce qu\'on en serve une répartition.',
        icon: Icons.call_split_rounded,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 100),
      itemCount: transferts.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final t = transferts[i];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.blue.withValues(alpha: 0.12),
              child: const Icon(
                Icons.call_split_rounded,
                color: AppColors.blue,
                size: 20,
              ),
            ),
            title: Text(
              '${formatMilliers(t.quantite)} L de ${t.typeCarburant} '
              '→ ${t.destinationLibelle}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              '${t.souteLibelle} · prélevé sur ${t.sourceLibelle}'
              '${t.motif != null ? ' · ${t.motif}' : ''}\n'
              '${DateFormat('dd/MM/yyyy HH:mm').format(t.date)}',
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }
}
