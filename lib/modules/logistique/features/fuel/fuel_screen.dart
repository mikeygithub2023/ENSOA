import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sig_ensoa/core/roles.dart';
import 'package:sig_ensoa/modules/logistique/compat.dart';
import 'package:sig_ensoa/core/theme.dart';
import '../../data/repositories/fuel_providers.dart';
import '../dashboard/dashboard_carburant.dart';
import 'depotage_form_dialog.dart';
import 'depotage_interne_form_dialog.dart';
import 'depotages_tab.dart';
import 'distribution_form_dialog.dart';
import 'distributions_tab.dart';
import 'repartitions_screen.dart';
import 'soute_form_dialog.dart';
import 'soutes_tab.dart';

/// L'espace de travail du soutien pétrolier, à onglets.
///
/// Son tableau de bord ouvre la série, comme au Garage : on arrive sur l'état
/// des soutes, puis on descend dans le détail — la soute, les dépotages, la
/// ventilation, les répartitions, les distributions. Avant, le tableau de bord
/// se tenait ailleurs, et l'administrateur qui l'atteignait par la rubrique
/// « Soutien technique » n'avait que lui : la gestion du carburant lui était
/// fermée, son entrée de menu étant masquée au profit du regroupement.
class FuelScreen extends ConsumerStatefulWidget {
  const FuelScreen({super.key, this.sansCadre = false});

  /// Rendu nu, sans titre : la vue groupée du commandant (« Soutien
  /// technique ») porte déjà le sien et n'a pas à en empiler un second.
  final bool sansCadre;

  @override
  ConsumerState<FuelScreen> createState() => _FuelScreenState();
}

class _FuelScreenState extends ConsumerState<FuelScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
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
        // Le tableau de bord lit les niveaux et les mouvements du jour.
        ref.read(soutesProvider.notifier).refresh();
        ref.read(souteStocksProvider.notifier).refresh();
        ref.read(depotagesProvider.notifier).refresh();
        ref.read(distributionsProvider.notifier).refresh();
      case 1:
        ref.read(soutesProvider.notifier).refresh();
        ref.read(souteStocksProvider.notifier).refresh();
      case 2:
        ref.read(depotagesProvider.notifier).refresh();
      case 3:
        // La ventilation lit les trois : les transferts, les niveaux
        // qu'ils déplacent, et les répartitions qu'ils servent.
        ref.read(souteStocksProvider.notifier).refresh();
        ref.read(repartitionsProvider.notifier).refresh();
        ref.read(depotagesInternesProvider.notifier).refresh();
      case 4:
        ref.read(repartitionsProvider.notifier).refresh();
        ref.read(souteStocksProvider.notifier).refresh();
      case 5:
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
    final estSoutier = role == RoleLogistique.soutienPetrolier;

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!widget.sansCadre) ...[
              const Text(
                'Gestion du carburant',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 16),
            ],
            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: AppColors.navy,
              unselectedLabelColor: AppColors.inkMuted,
              indicatorColor: AppColors.navy,
              indicatorWeight: 3,
              dividerColor: AppColors.border,
              labelStyle: const TextStyle(fontWeight: FontWeight.w800),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
              tabs: const [
                Tab(text: 'Tableau de bord'),
                Tab(text: 'Soute'),
                Tab(text: 'Dépotage'),
                Tab(text: 'Ventilation'),
                Tab(text: 'Répartitions'),
                Tab(text: 'Distributions'),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Le tableau de bord se rend nu et défile dans son onglet.
                  // Ses alertes mènent à l'onglet « Soute », à côté, au lieu
                  // de quitter la page pour y revenir.
                  SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(4, 4, 4, 100),
                    child: DashboardCarburant(
                      sansCadre: true,
                      versGestion: () => _tabController.animateTo(1),
                    ),
                  ),
                  const SoutesTabContent(),
                  const DepotagesTabContent(),
                  const DepotagesInternesTabContent(),
                  const RepartitionsTabContent(),
                  const DistributionsTabContent(),
                ],
              ),
            ),
          ],
        ),
        Positioned(
          right: 4,
          bottom: 12,
          child: _fab(estChef, estSoutier) ?? const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget? _fab(bool estChef, bool estSoutier) {
    switch (_tabController.index) {
      // Rien à créer depuis le tableau de bord : il se lit, il ne s'écrit pas.
      case 1:
        if (!estChef) return null;
        return FloatingActionButton.extended(
          onPressed: () => showDialog(
            context: context,
            builder: (_) => const SouteFormDialog(),
          ),
          icon: const Icon(Icons.add_business_outlined),
          label: const Text('Nouvelle soute'),
        );
      case 2:
        if (!estChef) return null;
        return FloatingActionButton.extended(
          onPressed: () => showDialog(
            context: context,
            builder: (_) => const DepotageFormDialog(),
          ),
          icon: const Icon(Icons.add_circle_outline),
          label: const Text('Dépotage'),
        );
      case 3:
        // La ventilation revient au soutien pétrolier autant qu'au chef :
        // c'est lui qui tient la soute, et la base l'y autorise déjà.
        if (!estChef && !estSoutier) return null;
        return FloatingActionButton.extended(
          onPressed: () => showDialog(
            context: context,
            builder: (_) => const DepotageInterneFormDialog(),
          ),
          icon: const Icon(Icons.call_split_rounded),
          label: const Text('Ventiler'),
        );
      case 4:
        if (!estChef) return null;
        return FloatingActionButton.extended(
          onPressed: () => showDialog(
            context: context,
            builder: (_) => const NouvelleRepartitionDialog(),
          ),
          icon: const Icon(Icons.add),
          label: const Text('Nouvelle répartition'),
        );
      case 5:
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
