import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sig_ensoa/core/theme.dart';
import '../../data/repositories/fleet_providers.dart';
import '../../data/repositories/police_providers.dart';
import 'vehicules_tab.dart';
import 'visiteur_form_dialog.dart';
import 'visiteurs_tab.dart';

class PoliceScreen extends ConsumerStatefulWidget {
  const PoliceScreen({super.key});

  @override
  ConsumerState<PoliceScreen> createState() => _PoliceScreenState();
}

class _PoliceScreenState extends ConsumerState<PoliceScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
        ref.read(passagesVisiteursProvider.notifier).refresh();
      case 1:
        ref.read(passagesVehiculesProvider.notifier).refresh();
        ref.read(vehiculesProvider.notifier).refresh();
        ref.read(mouvementsVehiculeProvider.notifier).refresh();
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
              'Poste de Police',
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
                Tab(text: 'Visiteurs'),
                Tab(text: 'Véhicules'),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [VisiteursTabContent(), VehiculesTabContent()],
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
            builder: (_) => const VisiteurFormDialog(),
          ),
          icon: const Icon(Icons.person_add_alt_1_outlined),
          label: const Text('Nouvelle visite'),
        );
      default:
        return null;
    }
  }
}
