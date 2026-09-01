import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:sig_ensoa/core/roles.dart';
import 'package:sig_ensoa/core/theme.dart';
import 'package:sig_ensoa/modules/logistique/compat.dart';
import 'package:sig_ensoa/core/chargement.dart';
import 'package:sig_ensoa/core/format.dart';
import '../../data/models/carburant.dart';
import '../../data/repositories/fuel_providers.dart';
import '../../shared/widgets/skeleton.dart';
import '../../shared/widgets/widgets.dart';
import 'depotage_form_dialog.dart';

/// Contenu de l'onglet "Dépotage" — journal des réceptions de carburant.
class DepotagesTabContent extends ConsumerWidget {
  const DepotagesTabContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final charge = estCharge(ref, ['depotages', 'soutes', 'soute_stocks']);
    final depotages = ref.watch(depotagesAvecLibellesProvider);
    final df = DateFormat('dd/MM/yyyy HH:mm');

    final role = ref.watch(sessionProvider)?.user.role;
    final peutCorriger =
        role == RoleLogistique.chefSoutienTechnique ||
        role == RoleLogistique.administrateur;

    if (!charge) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(4, 4, 4, 100),
        child: SkeletonList(itemCount: 4),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 100),
      children: [
        if (depotages.isEmpty)
          const EmptyState(message: 'Aucun dépotage enregistré'),
        for (final v in depotages) ...[
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0x1F2E7D32),
                child: Icon(Icons.arrow_downward, color: AppColors.success),
              ),
              title: Text('${v.souteLibelle} — ${v.repartitionLibelle}'),
              subtitle: Text(
                '${df.format(v.depotage.date)} · ${v.depotage.typeCarburant}',
              ),
              trailing: Wrap(
                spacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '+${formatMilliers(v.depotage.quantiteRecue)} L',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                    ),
                  ),
                  // Corriger ou annuler une réception touche au stock : c'est
                  // la main du chef de service, pas celle de qui consulte.
                  if (peutCorriger) ...[
                    IconButton(
                      tooltip: 'Modifier',
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) =>
                            DepotageFormDialog(existant: v.depotage),
                      ),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: 'Annuler ce dépotage',
                      onPressed: () =>
                          _confirmerSuppression(context, ref, v.depotage),
                      icon: const Icon(
                        Icons.delete_outline,
                        color: AppColors.danger,
                      ),
                    ),
                  ],
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

/// Annuler une réception fait ressortir son carburant du stock : on le dit
/// avant, chiffre à l'appui.
Future<void> _confirmerSuppression(
  BuildContext context,
  WidgetRef ref,
  Depotage depotage,
) async {
  final confirme = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      scrollable: true,
      title: const Text('Annuler ce dépotage'),
      content: Text(
        'Les ${formatMilliers(depotage.quantiteRecue)} L de '
        '${depotage.typeCarburant} que cette réception avait fait entrer '
        'seront retirés du stock de la répartition.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Garder'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Annuler le dépotage'),
        ),
      ],
    ),
  );
  if (confirme != true) return;

  try {
    await ref.read(depotagesProvider.notifier).supprimer(depotage);
  } catch (e) {
    if (!context.mounted) return;
    showErrorSnackBar(context, e, action: 'Suppression impossible');
  }
}
