import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sig_ensoa/core/roles.dart';
import 'package:sig_ensoa/modules/logistique/compat.dart';
import 'package:sig_ensoa/core/theme.dart';
import '../../data/repositories/fuel_providers.dart';
import 'depotage_form_dialog.dart';
import 'depotages_tab.dart';
import 'distribution_form_dialog.dart';
import 'distributions_tab.dart';
import 'repartitions_screen.dart';
import 'soute_form_dialog.dart';
import 'soutes_tab.dart';

class FuelScreen extends ConsumerStatefulWidget {
  const FuelScreen({super.key});

  @override
  ConsumerState<FuelScreen> createState() => _FuelScreenState();
}

class _FuelScreenState extends ConsumerState<FuelScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
        ref.read(soutesProvider.notifier).refresh();
        ref.read(souteStocksProvider.notifier).refresh();
      case 1:
        ref.read(depotagesProvider.notifier).refresh();
      case 2:
        ref.read(repartitionsProvider.notifier).refresh();
        ref.read(souteStocksProvider.notifier).refresh();
      case 3:
        ref.read(distributionsProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    // L'administrateur de l'école a la même main que le chef du service
    // depuis la migration qui lui a ouvert l'écriture : il doit voir les
    // mêmes boutons, sans quoi il a le droit sans le moyen.
    final role = ref.watch(sessionProvider)?.user.role;
    final estChef =
        role == RoleLogistique.chefSoutienTechnique ||
        role == RoleLogistique.administrateur;

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Gestion du carburant',
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
                Tab(text: 'Soute'),
                Tab(text: 'Dépotage'),
                Tab(text: 'Répartitions'),
                Tab(text: 'Distributions'),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  SoutesTabContent(),
                  DepotagesTabContent(),
                  RepartitionsTabContent(),
                  DistributionsTabContent(),
                ],
              ),
            ),
          ],
        ),
        Positioned(
          right: 4,
          bottom: 12,
          child: _fab(estChef) ?? const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget? _fab(bool estChef) {
    switch (_tabController.index) {
      case 0:
        if (!estChef) return null;
        return FloatingActionButton.extended(
          onPressed: () => showDialog(
            context: context,
            builder: (_) => const SouteFormDialog(),
          ),
          icon: const Icon(Icons.add_business_outlined),
          label: const Text('Nouvelle soute'),
        );
      case 1:
        if (!estChef) return null;
        return FloatingActionButton.extended(
          onPressed: () => showDialog(
            context: context,
            builder: (_) => const DepotageFormDialog(),
          ),
          icon: const Icon(Icons.add_circle_outline),
          label: const Text('Dépotage'),
        );
      case 2:
        if (!estChef) return null;
        return FloatingActionButton.extended(
          onPressed: () => showDialog(
            context: context,
            builder: (_) => const NouvelleRepartitionDialog(),
          ),
          icon: const Icon(Icons.add),
          label: const Text('Nouvelle répartition'),
        );
      case 3:
        return FloatingActionButton.extended(
          onPressed: () => showDialog(
            context: context,
            builder: (_) => const DistributionFormDialog(),
          ),
          icon: const Icon(Icons.local_gas_station_outlined),
          label: const Text('Distribution'),
        );
      default:
        return null;
    }
  }
}
