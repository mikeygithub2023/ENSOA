import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sig_ensoa/core/theme.dart';
import '../../data/repositories/oa_providers.dart';
import 'activite_form_dialog.dart';
import 'activites_tab.dart';
import 'statistiques_tab.dart';
import 'validations_tab.dart';

class OaScreen extends ConsumerStatefulWidget {
  const OaScreen({super.key});

  @override
  ConsumerState<OaScreen> createState() => _OaScreenState();
}

class _OaScreenState extends ConsumerState<OaScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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

  void _rafraichirOnglet(int index) {
    switch (index) {
      case 0:
        ref.read(activitesProvider.notifier).refresh();
      case 1:
      case 2:
        ref.read(tachesProvider.notifier).refresh();
        ref.read(activitesProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final enAttente = ref.watch(tachesEnAttenteValidationProvider).length;
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: AppColors.navy,
              unselectedLabelColor: AppColors.inkMuted,
              indicatorColor: AppColors.navy,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700),
              tabs: [
                const Tab(text: 'Activités'),
                Tab(
                  text: enAttente > 0
                      ? 'Validations ($enAttente)'
                      : 'Validations',
                ),
                const Tab(text: 'Statistiques'),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  ActivitesTabContent(),
                  ValidationsTabContent(),
                  StatistiquesTabContent(),
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
    if (_tabController.index != 0) return null;
    return FloatingActionButton.extended(
      onPressed: () => showDialog(
        context: context,
        builder: (_) => const ActiviteFormDialog(),
      ),
      icon: const Icon(Icons.add),
      label: const Text('Nouvelle activité'),
    );
  }
}
