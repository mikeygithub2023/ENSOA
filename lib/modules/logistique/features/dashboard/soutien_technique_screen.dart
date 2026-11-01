import 'package:flutter/material.dart';

import 'package:sig_ensoa/core/theme.dart';
import '../fleet/garage_workspace_screen.dart';
import 'dashboard_armurerie.dart';
import 'dashboard_carburant.dart';

/// Les trois tableaux de bord du soutien technique sous une seule rubrique.
///
/// Un chef de service n'a que le sien — le garage son parc, le soutien
/// pétrolier ses soutes, l'armurier son armurerie. Le super administrateur,
/// lui, les commande tous : les lui éparpiller en trois entrées de menu
/// l'obligeait à sauter de l'une à l'autre pour se faire une idée d'ensemble.
/// Ici, les trois se tiennent côte à côte, un onglet chacun, et il bascule
/// d'un domaine à l'autre sans quitter l'écran.
///
/// Réservé à qui administre la plateforme (voir `nav_items.dart`) : pour les
/// autres, ce regroupement n'apporterait rien que leur propre tableau ne dise
/// déjà mieux.
class SoutienTechniqueScreen extends StatefulWidget {
  const SoutienTechniqueScreen({super.key});

  @override
  State<SoutienTechniqueScreen> createState() => _SoutienTechniqueScreenState();
}

class _SoutienTechniqueScreenState extends State<SoutienTechniqueScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _onglets;

  @override
  void initState() {
    super.initState();
    _onglets = TabController(length: 3, vsync: this);
    _onglets.addListener(() {
      if (!_onglets.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _onglets.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Soutien technique',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 16),
        _BarreOnglets(controller: _onglets),
        const SizedBox(height: 12),
        Expanded(
          child: TabBarView(
            controller: _onglets,
            // Le passage d'un domaine à l'autre se fait au doigt sur l'onglet :
            // les dashboards défilent eux-mêmes verticalement, et laisser le
            // glissement horizontal changer d'onglet se battrait avec ce
            // défilement.
            physics: const NeverScrollableScrollPhysics(),
            children: const [
              // Le Garage est lui-même un espace à onglets : il porte son
              // propre défilement, on ne l'emballe donc pas dans celui des
              // autres onglets (son TabBarView interne exige une hauteur bornée).
              GarageWorkspaceScreen(sansCadre: true),
              _OngletDashboard(child: DashboardCarburant(sansCadre: true)),
              _OngletDashboard(child: DashboardArmurerie(sansCadre: true)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Un onglet : son dashboard, rendu nu et porté par son propre défilement.
class _OngletDashboard extends StatelessWidget {
  const _OngletDashboard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 100),
      child: child,
    );
  }
}

/// Les trois domaines en bandeau segmenté, dans le style des grandes
/// rubriques de l'armement : indicateur plein sur fond clair.
class _BarreOnglets extends StatelessWidget {
  const _BarreOnglets({required this.controller});

  final TabController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.blueMist,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: AppColors.border),
      ),
      child: TabBar(
        controller: controller,
        indicator: BoxDecoration(
          color: AppColors.navy,
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.inkMuted,
        labelStyle: const TextStyle(fontWeight: FontWeight.w800),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
        tabs: const [
          Tab(text: 'Garage'),
          Tab(text: 'Soutien pétrolier'),
          Tab(text: 'Armurerie'),
        ],
      ),
    );
  }
}
