import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sig_ensoa/core/theme.dart';
import 'package:sig_ensoa/core/chargement.dart';
import 'package:sig_ensoa/core/format.dart';
import '../../data/repositories/fuel_providers.dart';
import '../../shared/widgets/skeleton.dart';
import '../../shared/widgets/widgets.dart';

/// Contenu de l'onglet "Répartitions" — liste des répartitions avec, pour
/// chacune, le détail des soutes où elle a du carburant.
class RepartitionsTabContent extends ConsumerWidget {
  const RepartitionsTabContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final charge = estCharge(ref, ['repartitions', 'soutes', 'soute_stocks']);
    final repartitions = ref.watch(repartitionsAvecSoutesProvider);

    if (!charge) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(4, 4, 4, 100),
        child: SkeletonList(itemCount: 4),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 100),
      children: [
        if (repartitions.isEmpty)
          const EmptyState(message: 'Aucune répartition créée'),
        for (final r in repartitions) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        r.repartition.libelle,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${formatMilliers(r.quantiteTotale)} L au total',
                        style: const TextStyle(
                          color: AppColors.inkMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (r.lignes.isEmpty)
                    const Text(
                      'Pas encore de stock dans une soute.',
                      style: TextStyle(color: AppColors.inkMuted, fontSize: 13),
                    )
                  else
                    for (final l in r.lignes)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.local_gas_station_outlined,
                              size: 16,
                              color: AppColors.blue,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(l.soute.libelle),
                                  Text(
                                    _detail(
                                      l.stock.qteGasoil,
                                      l.stock.qteSuper,
                                    ),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.inkMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${formatMilliers(l.stock.quantiteTotale)} L',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (l.stock.seuilAtteint) ...[
                              const SizedBox(width: 8),
                              const StatusChip(
                                label: 'Seuil critique',
                                level: AlertLevel.critical,
                              ),
                            ],
                          ],
                        ),
                      ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

/// "1000 L Gasoil + 1500 L Super" — n'affiche que les types réellement présents.
String _detail(int qteGasoil, int qteSuper) {
  final parts = [
    if (qteGasoil > 0) '${formatMilliers(qteGasoil)} L Gasoil',
    if (qteSuper > 0) '${formatMilliers(qteSuper)} L Super',
  ];
  return parts.isEmpty ? '—' : parts.join(' + ');
}

class NouvelleRepartitionDialog extends ConsumerStatefulWidget {
  const NouvelleRepartitionDialog({super.key});

  @override
  ConsumerState<NouvelleRepartitionDialog> createState() =>
      _NouvelleRepartitionDialogState();
}

class _NouvelleRepartitionDialogState
    extends ConsumerState<NouvelleRepartitionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _libelleCtrl = TextEditingController();
  bool _envoi = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: const Text('Nouvelle répartition'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _libelleCtrl,
          decoration: const InputDecoration(
            labelText: 'Libellé (ex. BA1, CA3…)',
          ),
          validator: (v) => v == null || v.trim().isEmpty ? 'Requis' : null,
          autofocus: true,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _envoi
              ? null
              : () async {
                  if (!_formKey.currentState!.validate()) return;
                  setState(() => _envoi = true);
                  // `mounted` porte sur l'état de l'écran, pas sur le contexte
                  // du dialogue : celui-ci peut être fermé alors que l'écran
                  // vit toujours. C'est `context.mounted` qui répond à la
                  // bonne question.
                  final navigateur = Navigator.of(context);
                  final messager = ScaffoldMessenger.of(context);
                  try {
                    await ref
                        .read(repartitionsProvider.notifier)
                        .creer(_libelleCtrl.text.trim());
                    if (!context.mounted) return;
                    showSuccessSnackBar(
                      context,
                      'Répartition créée avec succès.',
                    );
                    navigateur.pop();
                  } catch (e) {
                    if (!context.mounted) return;
                    setState(() => _envoi = false);
                    messager.showSnackBar(
                      SnackBar(content: Text('Erreur Supabase : $e')),
                    );
                  }
                },
          child: const Text('Créer'),
        ),
      ],
    );
  }
}
