import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;

import 'package:sig_ensoa/core/theme.dart' hide AlertLevel, AlertLevelColor;
import '../../models/classe.dart';
import '../../models/division.dart';
import 'absences_tab_view.dart';
import 'consultations_medicales_tab_view.dart';
import 'controles_tab_view.dart';
import 'permissions_tab_view.dart';
import 'situation_prise_armes_tab_view.dart';
import 'statistiques_classe_tab_view.dart';

/// Onglets affichés une fois une division (et éventuellement une classe/stage)
/// sélectionnée sur l'écran Élèves & Stagiaires. "Élèves/Stagiaires",
/// "Consultations médicales", "Permissions", "Absences" et "Contrôle continu
/// / Contrôle intermédiaire" sont branchés sur les données réelles ; les
/// autres sont de simples emplacements en attendant l'implémentation de
/// chaque module. "Statistiques générales" et "Contrôle continu / Contrôle
/// intermédiaire" ne s'affichent que pour une classe/stage précis(e) — pas
/// sous "Toutes phases / stages", où ces rubriques n'auraient pas de portée
/// définie.
class EntityTabsView extends StatefulWidget {
  const EntityTabsView({
    super.key,
    required this.division,
    required this.classe,
    required this.elevesStagiairesTab,
    this.classesRetenues,
    this.sousPromotion = false,
  });

  final Division division;
  final Classe? classe;
  final Widget elevesStagiairesTab;

  /// Phases retenues quand une promotion est sélectionnée sans phase
  /// précise — nul sous « Toutes promotions », où la portée est la division
  /// entière. Voir `portee_promotion.dart`.
  final Set<String>? classesRetenues;

  /// La portée est-elle une promotion ? Une promotion ne contient que des
  /// élèves, un stage que des stagiaires — c'est ce qui décide du mot.
  final bool sousPromotion;

  @override
  State<EntityTabsView> createState() => _EntityTabsViewState();
}

class _TabDef {
  const _TabDef(this.label, this.icon);
  final String label;
  final IconData icon;
}

class _EntityTabsViewState extends State<EntityTabsView>
    with TickerProviderStateMixin {
  late TabController _controller;

  /// La barre d'onglets, escamotée pendant qu'on descend dans le contenu.
  bool _ongletsVisibles = true;

  /// Le mot suit la portée : une promotion et ses phases ne contiennent
  /// que des élèves, un stage que des stagiaires. « Élèves/Stagiaires » ne
  /// subsiste que sous une division entière, où les deux se côtoient.
  String get _elevesStagiairesLabel => switch (widget.classe?.type) {
    ClasseType.phase => 'Élèves',
    ClasseType.stage => 'Stagiaires',
    null => widget.sousPromotion ? 'Élèves' : 'Élèves/Stagiaires',
  };

  /// Les modules ne concernent que les classes (élèves) ; les stages n'ont
  /// que le contrôle continu et l'examen final.
  String get _controlesTabLabel => switch (widget.classe?.type) {
    ClasseType.phase => 'Modules / Contrôle continu / Examen',
    ClasseType.stage => 'Contrôle continu / Examen final',
    null => 'Contrôle continu / Examen',
  };

  List<_TabDef> get _tabs => [
    const _TabDef('Situation de Prise d\'Armes', Icons.groups_outlined),
    _TabDef(_elevesStagiairesLabel, Icons.school_outlined),
    if (widget.classe != null) ...[
      const _TabDef('Statistiques générales', Icons.bar_chart_outlined),
      _TabDef(_controlesTabLabel, Icons.grading_outlined),
    ],
    const _TabDef('Consultations médicales', Icons.medical_services_outlined),
    const _TabDef('Permissions', Icons.assignment_turned_in_outlined),
    const _TabDef('Absences', Icons.event_busy_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _controller = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void didUpdateWidget(covariant EntityTabsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller.length != _tabs.length) {
      final oldController = _controller;
      _controller = TabController(length: _tabs.length, vsync: this);
      oldController.dispose();
    } else if (oldWidget.division.id != widget.division.id ||
        oldWidget.classe?.id != widget.classe?.id) {
      _controller.index = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // La barre d'onglets s'efface elle aussi quand on descend dans le
        // contenu, et revient au premier geste vers le haut : on change
        // d'onglet avant de lire, pas pendant.
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: Alignment.topLeft,
          child: _ongletsVisibles
              ? Container(
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    borderRadius: BorderRadius.circular(AppRadii.control),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: TabBar(
                    controller: _controller,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelColor: AppColors.navy,
                    unselectedLabelColor: AppColors.inkMuted,
                    indicatorColor: AppColors.navy,
                    indicatorWeight: 3,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    tabs: [
                      for (final tab in _tabs)
                        Tab(
                          icon: Icon(tab.icon, size: 18),
                          text: tab.label,
                          iconMargin: const EdgeInsets.only(bottom: 4),
                        ),
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: SizedBox(height: _ongletsVisibles ? 16 : 0),
        ),
        Expanded(
          child: NotificationListener<UserScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.axis != Axis.vertical) return false;
              final visibles = switch (notification.direction) {
                ScrollDirection.reverse => false,
                ScrollDirection.forward => true,
                ScrollDirection.idle => _ongletsVisibles,
              };
              if (visibles != _ongletsVisibles) {
                setState(() => _ongletsVisibles = visibles);
              }
              return false;
            },
            child: TabBarView(
              controller: _controller,
              children: [
                SituationPriseArmesTabView(
                  division: widget.division,
                  classe: widget.classe,
                  classesRetenues: widget.classesRetenues,
                ),
                widget.elevesStagiairesTab,
                if (widget.classe != null) ...[
                  StatistiquesClasseTabView(classe: widget.classe!),
                  ControlesTabView(
                    division: widget.division,
                    classe: widget.classe,
                  ),
                ],
                ConsultationsMedicalesTabView(
                  division: widget.division,
                  classe: widget.classe,
                  classesRetenues: widget.classesRetenues,
                ),
                PermissionsTabView(
                  division: widget.division,
                  classe: widget.classe,
                  classesRetenues: widget.classesRetenues,
                ),
                AbsencesTabView(
                  division: widget.division,
                  classe: widget.classe,
                  classesRetenues: widget.classesRetenues,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
