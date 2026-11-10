// La rubrique « Soutien technique » donne à chaque service son espace entier.
//
// Elle masque les trois entrées de menu séparées — Garage, Carburant,
// Armement. N'y montrer que les trois tableaux de bord fermait donc au
// commandant la gestion du carburant et de l'armement : il avait le droit sans
// le chemin. Ces épreuves tiennent la porte ouverte.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:sig_ensoa/core/chargement.dart';
import 'package:sig_ensoa/core/roles.dart';
import 'package:sig_ensoa/models/profil.dart';
import 'package:sig_ensoa/modules/logistique/data/models/armement.dart';
import 'package:sig_ensoa/modules/logistique/data/models/carburant.dart';
import 'package:sig_ensoa/modules/logistique/data/models/maintenance.dart';
import 'package:sig_ensoa/modules/logistique/data/models/vehicule.dart';
import 'package:sig_ensoa/modules/logistique/data/repositories/armament_providers.dart';
import 'package:sig_ensoa/modules/logistique/data/repositories/fleet_providers.dart';
import 'package:sig_ensoa/modules/logistique/data/repositories/fuel_providers.dart';
import 'package:sig_ensoa/modules/logistique/features/dashboard/soutien_technique_screen.dart';
import 'package:sig_ensoa/features/auth/providers/auth_providers.dart';

class _ToutCharge extends ChargementNotifier {
  @override
  Set<String> build() => {
    'vehicules',
    'reparations',
    'soutes',
    'soute_stocks',
    'depotages',
    'distributions',
    'armes',
    'dotations_armes',
    'munitions',
    'equipements',
  };
}

class _Vehicules extends VehiculesNotifier {
  @override
  Future<void> refresh() async {}

  @override
  List<Vehicule> build() => const [
    Vehicule(
      id: '1',
      chassis: 'C1',
      immatriculation: 'I1',
      kilometrage: 1000,
      etat: EtatVehicule.disponible,
      typeVehiculeId: 't1',
      kilometrageVidangeProchaine: 9000,
      marque: 'TOYOTA',
      modele: 'HILUX',
      typeVehicule: 'Pick-up',
    ),
  ];
}

class _Reparations extends ReparationsNotifier {
  @override
  Future<void> refresh() async {}

  @override
  List<Reparation> build() => const [];
}

class _Soutes extends SoutesNotifier {
  @override
  Future<void> refresh() async {}

  @override
  List<Soute> build() => const [Soute(id: 's1', libelle: 'BOUAKE')];
}

class _SouteStocks extends SouteStocksNotifier {
  @override
  Future<void> refresh() async {}

  @override
  List<SouteStock> build() => const [
    SouteStock(
      id: 's1',
      souteId: 's1',
      typeStockId: 't',
      repartitionId: 'r',
      repartitionLibelle: 'r',
      qteGasoil: 4360,
      qteSuper: 0,
      seuilNominal: 0,
      seuilCritique: 0,
    ),
  ];
}

class _Armes extends ArmesNotifier {
  @override
  Future<void> refresh() async {}

  @override
  List<Arme> build() => const [
    Arme(
      id: '1',
      type: "Fusil d'assaut",
      modele: 'AK-47',
      numeroSerie: 'SN-1',
      etat: EtatArme.bon,
      positionActuelle: 'Armurerie',
    ),
  ];
}

class _SansDotation extends DotationsNotifier {
  @override
  Future<void> refresh() async {}

  @override
  List<DotationArme> build() => const [];
}

class _Munitions extends MunitionsNotifier {
  @override
  Future<void> refresh() async {}

  @override
  List<StockMunition> build() => const [
    StockMunition(
      id: '1',
      calibre: '5.56x45mm',
      quantiteDisponible: 1200,
      seuilCritique: 200,
      souteArmementId: 'sa1',
    ),
  ];
}

class _Equipements extends EquipementsNotifier {
  @override
  Future<void> refresh() async {}

  @override
  List<EquipementProtection> build() => const [
    EquipementProtection(
      id: '1',
      libelle: 'Gilet pare-balles',
      quantiteDisponible: 40,
      seuilCritique: 5,
    ),
  ];
}

// Les notifiers se rechargent d'eux-mêmes dès qu'on les construit : sans
// doublure, le premier onglet ouvert va chercher Supabase, absent du harnais.
class _Depotages extends DepotagesNotifier {
  @override
  Future<void> refresh() async {}

  @override
  List<Depotage> build() => const [];
}

class _Distributions extends DistributionsNotifier {
  @override
  Future<void> refresh() async {}

  @override
  List<Distribution> build() => const [];
}

class _Repartitions extends RepartitionsNotifier {
  @override
  Future<void> refresh() async {}

  @override
  List<Repartition> build() => const [];
}

class _DepotagesInternes extends DepotagesInternesNotifier {
  @override
  Future<void> refresh() async {}

  @override
  List<DepotageInterne> build() => const [];
}

class _Mouvements extends MouvementsArticleNotifier {
  @override
  Future<void> refresh() async {}

  @override
  List<MouvementArticle> build() => const [];
}

Future<void> _ouvrir(
  WidgetTester tester, {
  Size taille = const Size(1600, 1400),
}) async {
  tester.view.physicalSize = taille;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        chargementProvider.overrideWith(_ToutCharge.new),
        vehiculesProvider.overrideWith(_Vehicules.new),
        reparationsProvider.overrideWith(_Reparations.new),
        soutesProvider.overrideWith(_Soutes.new),
        souteStocksProvider.overrideWith(_SouteStocks.new),
        depotagesProvider.overrideWith(_Depotages.new),
        distributionsProvider.overrideWith(_Distributions.new),
        repartitionsProvider.overrideWith(_Repartitions.new),
        depotagesInternesProvider.overrideWith(_DepotagesInternes.new),
        mouvementsArticleProvider.overrideWith(_Mouvements.new),
        armesProvider.overrideWith(_Armes.new),
        dotationsProvider.overrideWith(_SansDotation.new),
        munitionsProvider.overrideWith(_Munitions.new),
        equipementsProvider.overrideWith(_Equipements.new),
        profilCourantProvider.overrideWith(
          (ref) async => const Profil(
            id: 'p1',
            nom: 'DJAMA',
            prenom: 'Yannick',
            roleLogistique: RoleLogistique.administrateur,
          ),
        ),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: EdgeInsets.all(8),
            child: SoutienTechniqueScreen(),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Bascule sur un service par le bandeau du haut.
Future<void> _service(WidgetTester tester, String nom) async {
  await tester.tap(find.widgetWithText(Tab, nom));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  testWidgets('les trois services sont là', (tester) async {
    await _ouvrir(tester);
    expect(find.widgetWithText(Tab, 'Garage'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Soutien pétrolier'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Armurerie'), findsOneWidget);
  });

  testWidgets('le Garage ouvre sur son espace de travail', (tester) async {
    await _ouvrir(tester);
    expect(find.widgetWithText(Tab, 'Tableau de bord'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Liste des véhicules'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Ordres de mission'), findsOneWidget);
  });

  testWidgets('le soutien pétrolier porte la gestion du carburant', (
    tester,
  ) async {
    // Et pas seulement son tableau de bord : les soutes, les dépotages et les
    // distributions doivent s'atteindre d'ici.
    await _ouvrir(tester);
    await _service(tester, 'Soutien pétrolier');
    expect(find.widgetWithText(Tab, 'Tableau de bord'), findsOneWidget);
    for (final onglet in ['Soute', 'Dépotage', 'Ventilation', 'Répartitions',
        'Distributions']) {
      expect(
        find.widgetWithText(Tab, onglet),
        findsOneWidget,
        reason: '« $onglet » doit s\'atteindre depuis le soutien technique',
      );
    }
  });

  testWidgets("l'armurerie porte la gestion de l'armement", (tester) async {
    await _ouvrir(tester);
    await _service(tester, 'Armurerie');
    expect(find.widgetWithText(Tab, 'Tableau de bord'), findsOneWidget);
    for (final rubrique in ['Armement', 'Munitions', 'Équipements']) {
      expect(
        find.widgetWithText(Tab, rubrique),
        findsOneWidget,
        reason: '« $rubrique » doit s\'atteindre depuis le soutien technique',
      );
    }
  });

  // Trois niveaux d'onglets se superposent dans l'armurerie — le service, la
  // rubrique, la sous-rubrique. Sur un écran court, ils mangent la hauteur :
  // un débordement fait échouer ces épreuves.
  for (final (nom, taille) in const [
    ('le poste de bureau', Size(1600, 1200)),
    ('le portable', Size(1280, 800)),
    ('la tablette', Size(1024, 768)),
  ]) {
    testWidgets("l'armurerie tient sur $nom", (tester) async {
      await _ouvrir(tester, taille: taille);
      await _service(tester, 'Armurerie');
      await tester.tap(find.widgetWithText(Tab, 'Munitions'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets("les sous-rubriques de l'armurerie se déplient", (tester) async {
    // Le troisième niveau : dans une rubrique, son stock, ses bons et son
    // inventaire.
    await _ouvrir(tester);
    await _service(tester, 'Armurerie');
    await tester.tap(find.widgetWithText(Tab, 'Munitions'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(Tab, 'Stock'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Bons'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Inventaire'), findsOneWidget);
  });
}
