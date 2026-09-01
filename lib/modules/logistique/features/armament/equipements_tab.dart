import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sig_ensoa/core/theme.dart';
import 'package:sig_ensoa/core/chargement.dart';
import 'package:sig_ensoa/core/format.dart';
import '../../data/repositories/armament_providers.dart';
import '../../shared/widgets/skeleton.dart';
import '../../shared/widgets/widgets.dart';
import 'ajuster_stock_dialog.dart';
import 'menu_suppression.dart';

/// Contenu de l'onglet "Équipements" — stock d'équipements de protection
/// individuelle (gilets, casques, treillis...). Cartes à hauteur naturelle
/// (pas de hauteur fixe) : insensible à l'échelle de police de l'appareil.
class EquipementsTabContent extends ConsumerWidget {
  const EquipementsTabContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final charge = estCharge(ref, ['equipements']);
    final equipements = ref.watch(equipementsProvider);

    if (!charge) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(4, 4, 4, 100),
        child: SkeletonGrid(
          itemCount: 4,
          maxCrossAxisExtent: 280,
          mainAxisExtent: 168,
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 100),
      child: equipements.isEmpty
          ? const EmptyState(message: 'Aucun équipement enregistré')
          : Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final e in equipements)
                  SizedBox(
                    key: ValueKey(e.id),
                    width: 260,
                    child: Card(
                      child: Stack(
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => showDialog(
                              context: context,
                              builder: (_) => AjusterStockDialog(
                                titre: e.libelle,
                                libelleArticle: e.libelle,
                                quantiteActuelle: e.quantiteDisponible,
                                onAjuster: (delta) => ref
                                    .read(equipementsProvider.notifier)
                                    .ajusterStock(e.id, delta),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color:
                                          (e.seuilAtteint
                                                  ? AppColors.danger
                                                  : AppColors.navy)
                                              .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(
                                      Icons.shield_outlined,
                                      color: e.seuilAtteint
                                          ? AppColors.danger
                                          : AppColors.navy,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    formatMilliers(e.quantiteDisponible),
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    e.libelle,
                                    style: const TextStyle(
                                      color: AppColors.inkMuted,
                                      fontSize: 13,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Seuil critique : ${formatMilliers(e.seuilCritique)}',
                                    style: TextStyle(
                                      color: e.seuilAtteint
                                          ? AppColors.danger
                                          : AppColors.inkMuted,
                                      fontSize: 11,
                                      fontWeight: e.seuilAtteint
                                          ? FontWeight.w700
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: MenuSuppressionArticle(
                              titre: 'Supprimer l\'équipement',
                              designation: e.libelle,
                              avertissement: e.quantiteDisponible > 0
                                  ? 'Il reste ${formatMilliers(e.quantiteDisponible)} '
                                        'exemplaires en stock.'
                                  : null,
                              onSupprimer: () => ref
                                  .read(equipementsProvider.notifier)
                                  .supprimer(e.id),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
