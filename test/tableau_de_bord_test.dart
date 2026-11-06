// Le tableau de bord unique, tel que le lit celui qui relève des deux domaines.
//
// Il réunit deux écrans qui se répétaient : on vérifie qu'un chiffre n'y paraît
// qu'une fois, et que la page tient de l'écran de bureau au téléphone — un
// débordement fait échouer le test.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:sig_ensoa/core/chargement.dart';
import 'package:sig_ensoa/core/roles.dart';
import 'package:sig_ensoa/core/theme.dart';
import 'package:sig_ensoa/features/accueil/accueil_screen.dart';
import 'package:sig_ensoa/features/accueil/providers/apercu_providers.dart';
import 'package:sig_ensoa/features/auth/providers/auth_providers.dart';
import 'package:sig_ensoa/features/shell/nav_items.dart';
import 'package:sig_ensoa/models/profil.dart';
import 'package:sig_ensoa/modules/logistique/data/models/armement.dart';
import 'package:sig_ensoa/modules/logistique/data/models/carburant.dart';
import 'package:sig_ensoa/modules/logistique/data/models/vehicule.dart';
import 'package:sig_ensoa/modules/logistique/data/repositories/armament_providers.dart';
import 'package:sig_ensoa/modules/logistique/data/repositories/fleet_providers.dart';
import 'package:sig_ensoa/modules/logistique/data/repositories/fuel_providers.dart';
import 'package:sig_ensoa/modules/scolarite/features/dashboard/providers/dashboard_providers.dart';
import 'package:sig_ensoa/modules/scolarite/models/division.dart';

class _Vehicules extends VehiculesNotifier {
  @override
  List<Vehicule> build() => [
    for (var i = 0; i < 22; i++)
      Vehicule(
        id: '$i',
        chassis: 'C$i',
        immatriculation: 'I$i',
        kilometrage: 1000,
        etat: i < 12
            ? EtatVehicule.disponible
            : (i < 18 ? EtatVehicule.enMission : EtatVehicule.enReparation),
        typeVehiculeId: 't${i % 4}',
        // Deux véhicules ont passé leur vidange, de quoi remplir les alertes.
        kilometrageVidangeProchaine: i < 2 ? 900 : 9000,
        marque: 'TOYOTA',
        modele: 'HILUX',
        typeVehicule: const ['Pick-up', 'Bus', 'Camion', 'Ambulance'][i % 4],
      ),
  ];
}

class _Armes extends ArmesNotifier {
  @override
  List<Arme> build() => const [];
}

class _ToutCharge extends ChargementNotifier {
  @override
  Set<String> build() => {
    'vehicules',
    'soutes',
    'soute_stocks',
    'depotages',
    'distributions',
  };
}

SouteVue _soute(String nom, int litres) => SouteVue(
  soute: Soute(id: nom, libelle: nom),
  stock: SouteStock(
    id: nom,
    souteId: nom,
    typeStockId: 't',
    repartitionId: 'r',
    repartitionLibelle: 'r',
    qteGasoil: litres,
    qteSuper: 0,
    seuilNominal: 0,
    seuilCritique: 0,
  ),
);

Future<void> _ouvrir(WidgetTester tester, Size taille) async {
  tester.view.physicalSize = taille;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final hier = DateTime.now().subtract(const Duration(days: 1));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        profilCourantProvider.overrideWith(
          (ref) async => const Profil(
            id: 'p1',
            nom: 'DJAMA',
            prenom: 'Yannick',
            roleScolarite: RoleScolarite.admin,
            roleLogistique: RoleLogistique.administrateur,
          ),
        ),
        apercuScolariteProvider.overrideWith(
          (ref) async => const ApercuScolarite(
            apprenants: 203,
            promotions: 4,
            classes: 2,
            cours: 2,
          ),
        ),
        apercuLogistiqueProvider.overrideWith(
          (ref) async => const ApercuLogistique(
            vehicules: 22,
            vehiculesDisponibles: 12,
            litresEnSoute: 5620,
            armes: 254,
            armesEnDotation: 0,
          ),
        ),
        dashboardStatsProvider.overrideWith(
          (ref) async => DashboardStats(
            total: 203,
            parDivision: [
              DivisionCount(
                division: Division(
                  id: 'd1',
                  code: 'DFI',
                  nom: 'Division de Formation Initiale',
                ),
                count: 203,
              ),
            ],
          ),
        ),
        chargementProvider.overrideWith(_ToutCharge.new),
        vehiculesProvider.overrideWith(_Vehicules.new),
        armesProvider.overrideWith(_Armes.new),
        soutesAvecStockProvider.overrideWith(
          (ref) => [
            _soute('BOUAKE', 4360),
            _soute('ABIDJAN', 1000),
            _soute('KATIOLA', 185),
            _soute('DALOA', 75),
          ],
        ),
        soutesEnAlerteProvider.overrideWith((ref) => []),
        dotationsEnRetardProvider.overrideWith((ref) => []),
        armesInspectionEnRetardProvider.overrideWith((ref) => []),
        journalCarburantProvider.overrideWith(
          (ref) => [
            // Une vieille entrée : la carte « du jour » ne doit pas la compter.
            JournalCarburantEntry(
              date: hier,
              description: 'Dépotage',
              quantite: 5520,
              entree: true,
              auteurId: 'a',
            ),
            JournalCarburantEntry(
              date: DateTime.now(),
              description: 'Distribution',
              quantite: 500,
              entree: false,
              auteurId: 'a',
            ),
          ],
        ),
      ],
      child: MaterialApp(
        theme: ThemeData(
          fontFamily: 'Roboto',
          scaffoldBackgroundColor: AppColors.cardBg,
          cardTheme: CardThemeData(
            elevation: 0,
            margin: EdgeInsets.zero,
            color: AppColors.blueMist,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.card),
              side: const BorderSide(color: Color(0xFFE3E9F5)),
            ),
          ),
        ),
        home: const Scaffold(
          body: Padding(padding: EdgeInsets.all(32), child: AccueilScreen()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR');
    final police = FontLoader('Roboto')
      ..addFont(rootBundle.load('assets/fonts/roboto-regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/roboto-bold.ttf'));
    await police.load();
  });

  test('un seul bouton mène au tableau de bord', () {
    final libelles = elementsNav.where((e) => e.libelle == 'Tableau de bord');

    expect(libelles.map((e) => e.chemin), ['/']);
    expect(
      elementsNav.map((e) => e.chemin),
      isNot(contains('/tableau-de-bord')),
    );
  });

  testWidgets('les deux tableaux se lisent sans se répéter', (tester) async {
    await _ouvrir(tester, const Size(1680, 1400));

    expect(find.text('SCOLARITÉ'), findsOneWidget);
    expect(find.text('SOUTIEN TECHNIQUE'), findsOneWidget);
    expect(find.text('Division de Formation Initiale'), findsOneWidget);
    expect(find.text('Alertes prioritaires'), findsOneWidget);
    expect(find.text('Carburant en soute'), findsOneWidget);
    expect(find.text('Disponibilité par type'), findsOneWidget);

    // La disponibilité du parc tient sur sa tuile, plus sur une jauge à part.
    expect(find.text('12/22'), findsOneWidget);
    expect(find.text('Disponibilité du parc'), findsNothing);
  });

  testWidgets('la carte du jour ne compte que la journée', (tester) async {
    await _ouvrir(tester, const Size(1680, 1400));

    expect(find.text('+0 L'), findsOneWidget); // aucune entrée aujourd'hui
    expect(find.text('-500 L'), findsNWidgets(2)); // le solde, et les sorties
  });

  for (final (nom, taille) in [
    ('le poste de bureau', const Size(1680, 1000)),
    ('la tablette', const Size(1000, 800)),
    ('le téléphone', const Size(420, 800)),
  ]) {
    testWidgets('la page tient sur $nom', (tester) async {
      await _ouvrir(tester, taille);

      expect(tester.takeException(), isNull);
    });
  }
}
