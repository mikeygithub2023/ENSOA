import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sig_ensoa/core/theme.dart';
import '../../data/repositories/armament_providers.dart';
import 'armes_tab.dart';
import 'bons_armes_tab.dart';
import 'dotation_form_dialog.dart';
import 'equipements_tab.dart';
import 'inventaire_tab.dart';
import 'munitions_tab.dart';
import 'nouvel_article_dialog.dart';
import 'weapon_form_dialog.dart';

class ArmamentScreen extends ConsumerStatefulWidget {
  const ArmamentScreen({super.key});

  @override
  ConsumerState<ArmamentScreen> createState() => _ArmamentScreenState();
}

class _ArmamentScreenState extends ConsumerState<ArmamentScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
        _rafraichirOnglet(_tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Un provider ne se recharge pas tout seul en changeant d'onglet (les
  /// widgets des onglets restent montés en mémoire par TabBarView) — on
  /// force donc explicitement le rafraîchissement des données de l'onglet
  /// affiché à chaque changement.
  void _rafraichirOnglet(int index) {
    switch (index) {
      case 0:
        ref.read(armesProvider.notifier).refresh();
      case 1:
        ref.read(dotationsProvider.notifier).refresh();
        ref.read(armesProvider.notifier).refresh();
      case 2:
        ref.read(munitionsProvider.notifier).refresh();
      case 3:
        ref.read(equipementsProvider.notifier).refresh();
      case 4:
        ref.read(armesProvider.notifier).refresh();
        ref.read(munitionsProvider.notifier).refresh();
        ref.read(equipementsProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Armement',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 16),
            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: AppColors.navy,
              unselectedLabelColor: AppColors.inkMuted,
              indicatorColor: AppColors.navy,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700),
              tabs: const [
                Tab(text: 'Armes'),
                Tab(text: 'Bons'),
                Tab(text: 'Munitions'),
                Tab(text: 'Équipements'),
                Tab(text: 'Inventaire'),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  ArmesTabContent(),
                  BonsArmesTabContent(),
                  MunitionsTabContent(),
                  EquipementsTabContent(),
                  InventaireTabContent(),
                ],
              ),
            ),
          ],
        ),
        Positioned(
          right: 4,
          bottom: 12,
          child: _fab() ?? const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget? _fab() {
    switch (_tabController.index) {
      case 0:
        return FloatingActionButton.extended(
          onPressed: () => showDialog(
            context: context,
            builder: (_) => const WeaponFormDialog(),
          ),
          icon: const Icon(Icons.add),
          label: const Text('Nouvelle arme'),
        );
      case 1:
        return FloatingActionButton.extended(
          onPressed: () => showDialog(
            context: context,
            builder: (_) => const DotationFormDialog(),
          ),
          icon: const Icon(Icons.assignment_outlined),
          label: const Text('Nouveau bon de sortie'),
        );
      case 2:
        return FloatingActionButton.extended(
          onPressed: () => showDialog(
            context: context,
            builder: (_) => NouvelArticleDialog(
              titre: 'Nouveau calibre',
              labelLibelle: 'Calibre (ex. 5.56x45mm)',
              onCreer:
                  ({
                    required libelle,
                    required quantiteInitiale,
                    required seuilCritique,
                  }) => ref
                      .read(munitionsProvider.notifier)
                      .creer(
                        calibre: libelle,
                        quantiteInitiale: quantiteInitiale,
                        seuilCritique: seuilCritique,
                      ),
            ),
          ),
          icon: const Icon(Icons.add),
          label: const Text('Nouveau calibre'),
        );
      case 3:
        return FloatingActionButton.extended(
          onPressed: () => showDialog(
            context: context,
            builder: (_) => NouvelArticleDialog(
              titre: 'Nouvel équipement',
              labelLibelle: 'Libellé (ex. Gilet pare-balles)',
              onCreer:
                  ({
                    required libelle,
                    required quantiteInitiale,
                    required seuilCritique,
                  }) => ref
                      .read(equipementsProvider.notifier)
                      .creer(
                        libelle: libelle,
                        quantiteInitiale: quantiteInitiale,
                        seuilCritique: seuilCritique,
                      ),
            ),
          ),
          icon: const Icon(Icons.add),
          label: const Text('Nouvel équipement'),
        );
      default:
        return null;
    }
  }
}
