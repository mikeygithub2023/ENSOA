import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sig_ensoa/core/theme.dart';
import 'package:sig_ensoa/core/chargement.dart';
import 'package:sig_ensoa/core/format.dart';
import '../../data/models/armement.dart';
import '../../data/repositories/armament_providers.dart';
import '../../shared/widgets/skeleton.dart';
import '../../shared/widgets/widgets.dart';
import 'bon_stock_dialog.dart';
import 'menu_suppression.dart';

/// Contenu de l'onglet "Munitions" — stock par calibre. Cartes à hauteur
/// naturelle (pas de hauteur fixe) : insensible à l'échelle de police de
/// l'appareil, donc pas de risque de débordement.
class MunitionsTabContent extends ConsumerWidget {
  const MunitionsTabContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final charge = estCharge(ref, ['munitions']);
    final munitions = ref.watch(munitionsProvider);

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
      child: munitions.isEmpty
          ? const EmptyState(message: 'Aucun calibre enregistré')
          : Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final m in munitions)
                  SizedBox(
                    // Clé d'identité : sans elle, Flutter réassocie les états
                    // par position, et le sablier d'une carte supprimée
                    // retomberait sur celle qui prend sa place.
                    key: ValueKey(m.id),
                    width: 260,
                    child: Card(
                      child: Stack(
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => showDialog(
                              context: context,
                              builder: (_) => BonStockDialog(
                                famille: FamilleArticle.munition,
                                articleId: m.id,
                                libelleArticle: 'calibre ${m.calibre}',
                                quantiteActuelle: m.quantiteDisponible,
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
                                          (m.seuilAtteint
                                                  ? AppColors.danger
                                                  : AppColors.militaryGreen)
                                              .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(
                                      Icons.scatter_plot_outlined,
                                      color: m.seuilAtteint
                                          ? AppColors.danger
                                          : AppColors.militaryGreen,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    formatMilliers(m.quantiteDisponible),
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Calibre ${m.calibre}',
                                    style: const TextStyle(
                                      color: AppColors.inkMuted,
                                      fontSize: 13,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Seuil critique : ${formatMilliers(m.seuilCritique)}',
                                    style: TextStyle(
                                      color: m.seuilAtteint
                                          ? AppColors.danger
                                          : AppColors.inkMuted,
                                      fontSize: 11,
                                      fontWeight: m.seuilAtteint
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
                              titre: 'Supprimer le calibre',
                              designation: 'Le calibre ${m.calibre}',
                              // Retirer un calibre encore en stock ferait sortir
                              // ces munitions des comptes sans qu'elles aient
                              // été délivrées.
                              avertissement: m.quantiteDisponible > 0
                                  ? 'Il reste ${formatMilliers(m.quantiteDisponible)} '
                                        'munitions de ce calibre en stock.'
                                  : null,
                              onSupprimer: () => ref
                                  .read(munitionsProvider.notifier)
                                  .supprimer(m.id),
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
