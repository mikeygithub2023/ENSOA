import 'package:flutter/material.dart';

import 'package:sig_ensoa/core/theme.dart' hide AlertLevel, AlertLevelColor;
import '../../models/classe.dart';
import '../../models/division.dart';
import 'absences_tab_view.dart';
import 'bureaux.dart';
import 'consultations_medicales_tab_view.dart';
import 'controles_tab_view.dart';
import 'permissions_tab_view.dart';
import 'situation_prise_armes_tab_view.dart';
import 'statistiques_classe_tab_view.dart';

/// Les onglets que peut porter l'écran d'un effectif, tous bureaux confondus.
enum OngletEffectif {
  priseArmes,
  effectif,
  resultats,
  statistiques,
  controles,
  consultations,
  permissions,
  absences,
}

/// Les onglets d'un bureau, dans l'ordre où ils se présentent.
///
/// Deux d'entre eux ne paraissent que sur une phase ou un stage précis — les
/// résultats et les contrôles côté instruction, les statistiques côté
/// ressources humaines : sous « toutes phases / stages », ces rubriques
/// n'auraient pas de portée définie. Les autres se cumulent sans peine sur une
/// promotion ou une division entière.
///
/// « Effectif » — la liste nominative — figure dans les deux : c'est par elle
/// qu'on ouvre la fiche d'un élève, et les deux bureaux en ont besoin.
List<OngletEffectif> ongletsDuBureau(
  Bureau bureau, {
  required bool avecClasse,
}) {
  return switch (bureau) {
    Bureau.instruction => [
      OngletEffectif.effectif,
      if (avecClasse) ...[OngletEffectif.resultats, OngletEffectif.controles],
    ],
    Bureau.ressourcesHumaines => [
      OngletEffectif.priseArmes,
      OngletEffectif.effectif,
      if (avecClasse) OngletEffectif.statistiques,
      OngletEffectif.consultations,
      OngletEffectif.permissions,
      OngletEffectif.absences,
    ],
  };
}

/// Onglets affichés une fois une division (et éventuellement une classe/stage)
/// sélectionnée, sous le bureau où l'on se trouve. Tous sont branchés sur les
/// données réelles.
class EntityTabsView extends StatefulWidget {
  const EntityTabsView({
    super.key,
    required this.bureau,
    required this.division,
    required this.classe,
    required this.elevesStagiairesTab,
    this.classesRetenues,
    this.sousPromotion = false,
  });

  /// Le bureau dont on tient l'écran : c'est lui qui décide des onglets.
  final Bureau bureau;

  /// Nulle sous « Toutes » : les onglets cumulent alors les divisions que
  /// l'utilisateur a le droit de voir.
  final Division? division;
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

class _EntityTabsViewState extends State<EntityTabsView>
    with TickerProviderStateMixin {
  late TabController _controller;

  List<OngletEffectif> get _onglets =>
      ongletsDuBureau(widget.bureau, avecClasse: widget.classe != null);

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

  String _libelle(OngletEffectif onglet) => switch (onglet) {
    OngletEffectif.priseArmes => 'Situation de Prise d\'Armes',
    OngletEffectif.effectif => _elevesStagiairesLabel,
    OngletEffectif.resultats => 'Résultats',
    OngletEffectif.statistiques => 'Statistiques générales',
    OngletEffectif.controles => _controlesTabLabel,
    OngletEffectif.consultations => 'Consultations médicales',
    OngletEffectif.permissions => 'Permissions',
    OngletEffectif.absences => 'Absences',
  };

  IconData _icone(OngletEffectif onglet) => switch (onglet) {
    OngletEffectif.priseArmes => Icons.groups_outlined,
    OngletEffectif.effectif => Icons.school_outlined,
    OngletEffectif.resultats => Icons.insights_outlined,
    OngletEffectif.statistiques => Icons.bar_chart_outlined,
    OngletEffectif.controles => Icons.grading_outlined,
    OngletEffectif.consultations => Icons.medical_services_outlined,
    OngletEffectif.permissions => Icons.assignment_turned_in_outlined,
    OngletEffectif.absences => Icons.event_busy_outlined,
  };

  Widget _vue(OngletEffectif onglet) => switch (onglet) {
    OngletEffectif.priseArmes => SituationPriseArmesTabView(
      division: widget.division,
      classe: widget.classe,
      classesRetenues: widget.classesRetenues,
    ),
    OngletEffectif.effectif => widget.elevesStagiairesTab,
    // Les deux voient le même écran, chacun son volet : les résultats pour
    // l'instruction, l'effectif et sa disponibilité pour les RH.
    OngletEffectif.resultats => StatistiquesClasseTabView(
      classe: widget.classe!,
      bureau: Bureau.instruction,
    ),
    OngletEffectif.statistiques => StatistiquesClasseTabView(
      classe: widget.classe!,
      bureau: Bureau.ressourcesHumaines,
    ),
    OngletEffectif.controles => ControlesTabView(
      // Une classe est retenue : sa division l'est donc aussi.
      division: widget.division!,
      classe: widget.classe,
    ),
    OngletEffectif.consultations => ConsultationsMedicalesTabView(
      division: widget.division,
      classe: widget.classe,
      classesRetenues: widget.classesRetenues,
    ),
    OngletEffectif.permissions => PermissionsTabView(
      division: widget.division,
      classe: widget.classe,
      classesRetenues: widget.classesRetenues,
    ),
    OngletEffectif.absences => AbsencesTabView(
      division: widget.division,
      classe: widget.classe,
      classesRetenues: widget.classesRetenues,
    ),
  };

  @override
  void initState() {
    super.initState();
    _controller = TabController(length: _onglets.length, vsync: this);
  }

  @override
  void didUpdateWidget(covariant EntityTabsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller.length != _onglets.length) {
      final oldController = _controller;
      _controller = TabController(length: _onglets.length, vsync: this);
      oldController.dispose();
    } else if (oldWidget.division?.id != widget.division?.id ||
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
    final onglets = _onglets;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
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
              for (final onglet in onglets)
                Tab(
                  icon: Icon(_icone(onglet), size: 18),
                  text: _libelle(onglet),
                  iconMargin: const EdgeInsets.only(bottom: 4),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: TabBarView(
            controller: _controller,
            children: [for (final onglet in onglets) _vue(onglet)],
          ),
        ),
      ],
    );
  }
}
