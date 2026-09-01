import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:sig_ensoa/core/theme.dart';
import 'package:sig_ensoa/core/chargement.dart';
import 'package:sig_ensoa/core/format.dart';
import '../../data/repositories/fuel_providers.dart';
import '../../shared/widgets/skeleton.dart';
import '../../shared/widgets/widgets.dart';

/// Contenu de l'onglet "Dépotage" — journal des réceptions de carburant.
class DepotagesTabContent extends ConsumerWidget {
  const DepotagesTabContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final charge = estCharge(ref, ['depotages', 'soutes', 'soute_stocks']);
    final depotages = ref.watch(depotagesAvecLibellesProvider);
    final df = DateFormat('dd/MM/yyyy HH:mm');

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
              trailing: Text(
                '+${formatMilliers(v.depotage.quantiteRecue)} L',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.success,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}
