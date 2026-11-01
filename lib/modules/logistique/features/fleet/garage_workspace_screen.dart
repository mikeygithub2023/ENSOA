import 'package:flutter/material.dart';

import 'package:sig_ensoa/core/theme.dart';
import '../dashboard/dashboard_garage.dart';
import 'demandes_reparation_tab.dart';
import 'fleet_screen.dart';
import 'ordres_mission_tab.dart';

/// L'espace de travail du Garage, à onglets.
///
/// Le parc, son tableau de bord et ses ordres de mission tenaient chacun leur
/// écran, atteints par des entrées de menu séparées — et l'on quittait l'un
/// pour l'autre, sans retour une fois le menu masqué. Ils se réunissent ici en
/// un seul espace : on passe d'un onglet à l'autre sans jamais quitter la page.
///
/// Les onglets « Ordres de mission » et autres viendront s'ajouter à la suite.
class GarageWorkspaceScreen extends StatefulWidget {
  const GarageWorkspaceScreen({super.key, this.sansCadre = false});

  /// Rendu nu, sans titre : la vue groupée du commandant (« Soutien
  /// technique ») porte déjà le sien et n'a pas à en empiler un second.
  final bool sansCadre;

  @override
  State<GarageWorkspaceScreen> createState() => _GarageWorkspaceScreenState();
}

class _GarageWorkspaceScreenState extends State<GarageWorkspaceScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _onglets;

  @override
  void initState() {
    super.initState();
    _onglets = TabController(length: 4, vsync: this);
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
        if (!widget.sansCadre) ...[
          const Text(
            'Garage',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 16),
        ],
        _BarreOnglets(controller: _onglets),
        const SizedBox(height: 12),
        Expanded(
          child: TabBarView(
            controller: _onglets,
            physics: const NeverScrollableScrollPhysics(),
            children: const [
              // Le tableau de bord se rend nu et défile dans son onglet.
              SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(4, 4, 4, 100),
                child: DashboardGarage(sansCadre: true),
              ),
              // La liste porte son propre défilement et son bouton « Nouveau
              // véhicule » : on la laisse se rendre seule.
              FleetScreen(sansCadre: true),
              // Les ordres de mission, de même, portent leur liste et leur
              // bouton « Nouvel ordre de mission ».
              OrdresMissionTab(),
              // Les demandes de mise en réparation, et leur validation.
              DemandesReparationTab(),
            ],
          ),
        ),
      ],
    );
  }
}

/// Les onglets du Garage, en onglets soulignés — volontairement distincts du
/// bandeau-pilule des grandes rubriques au-dessus (Garage, Soutien pétrolier,
/// Armurerie), pour qu'on lise d'un coup d'œil le niveau où l'on se trouve.
/// C'est le dessin des sous-rubriques de l'Armement.
class _BarreOnglets extends StatelessWidget {
  const _BarreOnglets({required this.controller});

  final TabController controller;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TabBar(
        controller: controller,
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
          Tab(text: 'Liste des véhicules'),
          Tab(text: 'Ordres de mission'),
          Tab(text: 'Demandes de réparation'),
        ],
      ),
    );
  }
}
