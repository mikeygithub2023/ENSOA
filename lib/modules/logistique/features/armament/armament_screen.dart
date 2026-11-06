import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sig_ensoa/core/theme.dart';
import '../../data/models/armement.dart';
import '../../data/repositories/armament_providers.dart';
import '../dashboard/dashboard_armurerie.dart';
import 'armes_tab.dart';
import 'bons_armes_tab.dart';
import 'bon_stock_dialog.dart';
import 'bons_stock_tab.dart';
import 'dotation_form_dialog.dart';
import 'equipements_tab.dart';
import 'inventaire_tab.dart';
import 'munitions_tab.dart';
import 'nouvel_article_dialog.dart';
import 'weapon_form_dialog.dart';

/// L'armement se tient en trois rubriques — Armement, Munitions,
/// Équipements —, et chacune porte ses bons et son inventaire. Son tableau de
/// bord les précède, comme au Garage : on arrive sur l'état de l'armurerie,
/// puis on descend dans le détail.
///
/// Auparavant, les cinq onglets étaient à plat : « Armes », « Bons »,
/// « Munitions », « Équipements », « Inventaire ». Les bons n'étaient donc
/// que ceux des armes, et l'inventaire mêlait les trois domaines. Ce
/// classement-ci suit celui du service : on travaille dans un domaine, et
/// dans ce domaine on tient un stock, des bons et un inventaire.
class ArmamentScreen extends ConsumerStatefulWidget {
  const ArmamentScreen({super.key, this.sansCadre = false});

  /// Rendu nu, sans titre : la vue groupée du commandant (« Soutien
  /// technique ») porte déjà le sien et n'a pas à en empiler un second.
  ///
  /// Le bandeau change de dessin avec lui. Le bandeau-pilule marque le niveau
  /// le plus haut d'une page ; emboîté sous « Soutien technique », ce niveau
  /// est déjà pris par les trois services, et l'armurerie descend d'un cran —
  /// des onglets soulignés, comme le Garage à la même place.
  final bool sansCadre;

  @override
  ConsumerState<ArmamentScreen> createState() => _ArmamentScreenState();
}

class _ArmamentScreenState extends ConsumerState<ArmamentScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _rubriques;

  @override
  void initState() {
    super.initState();
    _rubriques = TabController(length: 4, vsync: this);
    _rubriques.addListener(() {
      if (_rubriques.indexIsChanging) return;
      setState(() {});
      _rafraichirRubrique(_rubriques.index);
    });
  }

  @override
  void dispose() {
    _rubriques.dispose();
    super.dispose();
  }

  /// Un provider ne se recharge pas tout seul en changeant d'onglet (les
  /// widgets restent montés en mémoire par TabBarView) — on force donc le
  /// rafraîchissement des données de la rubrique affichée.
  void _rafraichirRubrique(int index) {
    switch (index) {
      case 0:
        // Le tableau de bord lit les trois domaines à la fois.
        ref.read(armesProvider.notifier).refresh();
        ref.read(dotationsProvider.notifier).refresh();
        ref.read(munitionsProvider.notifier).refresh();
        ref.read(equipementsProvider.notifier).refresh();
      case 1:
        ref.read(armesProvider.notifier).refresh();
        ref.read(dotationsProvider.notifier).refresh();
      case 2:
        ref.read(munitionsProvider.notifier).refresh();
        ref.read(mouvementsArticleProvider.notifier).refresh();
      case 3:
        ref.read(equipementsProvider.notifier).refresh();
        ref.read(mouvementsArticleProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!widget.sansCadre) ...[
          const Text(
            'Armement',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 16),
        ],
        _BarreRubriques(
          controller: _rubriques,
          pilules: !widget.sansCadre,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: TabBarView(
            controller: _rubriques,
            // Les deux niveaux d'onglets se superposent : laisser les deux
            // répondre au glissement rendrait imprévisible le passage d'une
            // sous-rubrique à l'autre. Le niveau haut se change au doigt sur
            // son bouton, le niveau bas au glissement.
            physics: const NeverScrollableScrollPhysics(),
            children: [
              // Le tableau de bord se rend nu et défile dans son onglet. Ses
              // alertes mènent à la rubrique « Armement », à côté, au lieu de
              // quitter la page pour y revenir.
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 100),
                child: DashboardArmurerie(
                  sansCadre: true,
                  versGestion: () => _rubriques.animateTo(1),
                ),
              ),
              const _RubriqueArmement(),
              const _RubriqueStock(famille: FamilleArticle.munition),
              const _RubriqueStock(famille: FamilleArticle.equipement),
            ],
          ),
        ),
      ],
    );
  }
}

/// Le tableau de bord et les trois grandes rubriques.
///
/// En bandeau segmenté quand l'armement tient la page à lui seul — distinct
/// des onglets soulignés qui sont, eux, les sous-rubriques. En onglets
/// soulignés quand il est emboîté sous « Soutien technique », où le bandeau
/// segmenté sert déjà à choisir le service.
class _BarreRubriques extends StatelessWidget {
  const _BarreRubriques({required this.controller, required this.pilules});

  final TabController controller;
  final bool pilules;

  static const _titres = [
    'Tableau de bord',
    'Armement',
    'Munitions',
    'Équipements',
  ];

  @override
  Widget build(BuildContext context) {
    if (!pilules) {
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
          tabs: [for (final t in _titres) Tab(text: t)],
        ),
      );
    }
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
        tabs: [for (final t in _titres) Tab(text: t)],
      ),
    );
  }
}

/// Une rubrique : ses sous-rubriques, et le bouton d'action de celle qui
/// est ouverte.
class _Rubrique extends ConsumerStatefulWidget {
  const _Rubrique({required this.titres, required this.contenus, this.fabs});

  final List<String> titres;
  final List<Widget> contenus;

  /// Un bouton par sous-rubrique, ou `null` là où il n'y a rien à créer.
  final List<Widget? Function(BuildContext, WidgetRef)>? fabs;

  @override
  ConsumerState<_Rubrique> createState() => _RubriqueState();
}

class _RubriqueState extends ConsumerState<_Rubrique>
    with SingleTickerProviderStateMixin {
  late final TabController _onglets;

  @override
  void initState() {
    super.initState();
    _onglets = TabController(length: widget.titres.length, vsync: this);
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
    final fab = widget.fabs == null
        ? null
        : widget.fabs![_onglets.index](context, ref);

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Les sous-rubriques, en onglets plus discrets que ceux du
            // niveau au-dessus : sous « Soutien technique », trois niveaux
            // d'onglets se superposent, et il faut lire d'un coup d'œil
            // lequel on manœuvre.
            SizedBox(
              height: 38,
              child: Align(
                alignment: Alignment.centerLeft,
                child: TabBar(
                  controller: _onglets,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: AppColors.blue,
                  unselectedLabelColor: AppColors.inkMuted,
                  indicatorColor: AppColors.blue,
                  indicatorWeight: 2,
                  dividerColor: Colors.transparent,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 14),
                  labelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  tabs: [for (final t in widget.titres) Tab(text: t)],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TabBarView(
                controller: _onglets,
                children: widget.contenus,
              ),
            ),
          ],
        ),
        if (fab != null)
          Positioned(right: 4, bottom: 12, child: fab),
      ],
    );
  }
}

class _RubriqueArmement extends StatelessWidget {
  const _RubriqueArmement();

  @override
  Widget build(BuildContext context) {
    return _Rubrique(
      titres: const ['Registre', 'Bons', 'Inventaire'],
      contenus: const [
        ArmesTabContent(),
        BonsArmesTabContent(),
        InventaireArmesTabContent(),
      ],
      fabs: [
        (context, ref) => FloatingActionButton.extended(
          onPressed: () => showDialog(
            context: context,
            builder: (_) => const WeaponFormDialog(),
          ),
          icon: const Icon(Icons.add),
          label: const Text('Nouvelle arme'),
        ),
        (context, ref) => FloatingActionButton.extended(
          onPressed: () => showDialog(
            context: context,
            builder: (_) => const DotationFormDialog(),
          ),
          icon: const Icon(Icons.assignment_outlined),
          label: const Text('Nouveau bon de sortie'),
        ),
        (context, ref) => null,
      ],
    );
  }
}

/// Munitions et Équipements se tiennent de la même façon — un stock, des
/// bons, un inventaire —, d'où une seule rubrique paramétrée.
class _RubriqueStock extends StatelessWidget {
  const _RubriqueStock({required this.famille});

  final FamilleArticle famille;

  @override
  Widget build(BuildContext context) {
    final munitions = famille == FamilleArticle.munition;
    return _Rubrique(
      titres: const ['Stock', 'Bons', 'Inventaire'],
      contenus: [
        munitions ? const MunitionsTabContent() : const EquipementsTabContent(),
        BonsStockTabContent(famille: famille),
        InventaireStockTabContent(famille: famille),
      ],
      fabs: [
        (context, ref) => FloatingActionButton.extended(
          onPressed: () => showDialog(
            context: context,
            builder: (_) => NouvelArticleDialog(
              titre: munitions ? 'Nouveau calibre' : 'Nouvel équipement',
              labelLibelle: munitions
                  ? 'Calibre (ex. 5.56x45mm)'
                  : 'Libellé (ex. Gilet pare-balles)',
              onCreer:
                  ({
                    required libelle,
                    required quantiteInitiale,
                    required seuilCritique,
                  }) => munitions
                      ? ref
                            .read(munitionsProvider.notifier)
                            .creer(
                              calibre: libelle,
                              quantiteInitiale: quantiteInitiale,
                              seuilCritique: seuilCritique,
                            )
                      : ref
                            .read(equipementsProvider.notifier)
                            .creer(
                              libelle: libelle,
                              quantiteInitiale: quantiteInitiale,
                              seuilCritique: seuilCritique,
                            ),
            ),
          ),
          icon: const Icon(Icons.add),
          label: Text(munitions ? 'Nouveau calibre' : 'Nouvel équipement'),
        ),
        (context, ref) => FloatingActionButton.extended(
          onPressed: () => afficherNouveauBon(context, ref, famille),
          icon: const Icon(Icons.receipt_long_outlined),
          label: const Text('Nouveau bon'),
        ),
        (context, ref) => null,
      ],
    );
  }
}
