// Ce que la sélection multiple du parc automobile doit garantir.
//
// Une suppression en lot est le geste le plus coûteux de cet écran : elle
// retire en un clic ce qu'on a mis une matinée à saisir. Trois choses se
// vérifient donc ici plutôt que de se supposer — qui voit le bouton, ce que
// « tout sélectionner » prend, et ce que la confirmation annonce.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sig_ensoa/core/chargement.dart';
import 'package:sig_ensoa/core/roles.dart';
import 'package:sig_ensoa/features/auth/providers/auth_providers.dart';
import 'package:sig_ensoa/models/profil.dart';
import 'package:sig_ensoa/modules/logistique/data/models/vehicule.dart';
import 'package:sig_ensoa/modules/logistique/data/repositories/fleet_providers.dart';
import 'package:sig_ensoa/modules/logistique/features/fleet/fleet_screen.dart';
import 'package:sig_ensoa/modules/logistique/shared/widgets/widgets.dart';

Vehicule _vhl(String id, String immatriculation, EtatVehicule etat) => Vehicule(
  id: id,
  chassis: 'CH-$id',
  immatriculation: immatriculation,
  kilometrage: 1000,
  etat: etat,
  typeVehiculeId: '1',
  kilometrageVidangeProchaine: 6000,
  marque: 'TOYOTA',
  modele: 'Land Cruiser',
  typeVehicule: 'Station Wagon',
);

/// Le parc tel que l'écran le reçoit — sans toucher au réseau.
class _ParcFige extends VehiculesNotifier {
  @override
  List<Vehicule> build() => [
    _vhl('1', '310 20 155', EtatVehicule.disponible),
    _vhl('2', '310 20 156', EtatVehicule.disponible),
    _vhl('3', '310 40 026', EtatVehicule.horsService),
  ];
}

class _ToutCharge extends ChargementNotifier {
  @override
  Set<String> build() => {'vehicules'};
}

Future<void> _ouvrir(WidgetTester tester, RoleLogistique role) async {
  tester.view.physicalSize = const Size(1400, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        chargementProvider.overrideWith(_ToutCharge.new),
        vehiculesProvider.overrideWith(_ParcFige.new),
        profilCourantProvider.overrideWith(
          (ref) async => Profil(
            id: 'p1',
            nom: 'KOUASSI',
            prenom: 'Rémi',
            grade: 'SGT',
            roleLogistique: role,
          ),
        ),
      ],
      child: const MaterialApp(home: Scaffold(body: FleetScreen())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('qui peut entrer en sélection', () {
    // La politique « parc ecriture » ouvre l'écriture au garage et au chef
    // du soutien technique ; `admin_tout_pouvoir` y ajoute l'administrateur.
    // Vérifié contre la base : ces trois-là et aucun autre. Un bouton offert
    // à qui le serveur refusera ne vaut pas mieux qu'une absence de bouton.
    for (final role in [
      RoleLogistique.garage,
      RoleLogistique.chefSoutienTechnique,
      RoleLogistique.administrateur,
    ]) {
      testWidgets('${role.name} voit le bouton', (tester) async {
        await _ouvrir(tester, role);
        expect(find.text('Sélectionner'), findsOneWidget);
      });
    }

    for (final role in [
      RoleLogistique.soutienPetrolier,
      RoleLogistique.armurerie,
      RoleLogistique.postePolice,
      RoleLogistique.sante,
      RoleLogistique.officierAdjoint,
    ]) {
      testWidgets('${role.name} ne le voit pas', (tester) async {
        await _ouvrir(tester, role);
        expect(find.text('Sélectionner'), findsNothing);
        // Il garde l'import, qui ne retire rien.
        expect(find.text('Importer depuis Excel'), findsOneWidget);
      });
    }
  });

  testWidgets('tout sélectionner prend les trois véhicules', (tester) async {
    await _ouvrir(tester, RoleLogistique.chefSoutienTechnique);

    await tester.tap(find.text('Sélectionner'));
    await tester.pumpAndSettle();
    expect(find.text('Aucun véhicule coché'), findsOneWidget);
    expect(find.text('Supprimer (0)'), findsOneWidget);

    await tester.tap(find.text('Tout sélectionner'));
    await tester.pumpAndSettle();
    expect(find.text('3 véhicule(s) coché(s) sur 3'), findsOneWidget);
    expect(find.text('Supprimer (3)'), findsOneWidget);
    // Le bouton bascule : on peut tout lâcher du même geste.
    expect(find.text('Tout décocher'), findsOneWidget);
  });

  testWidgets('la confirmation nomme ce qu\'elle emporte', (tester) async {
    // Une suppression en lot se confirme sur ce qu'elle retire, pas sur un
    // nombre : « Supprimer 3 véhicules » ne dit pas lesquels.
    await _ouvrir(tester, RoleLogistique.administrateur);

    await tester.tap(find.text('Sélectionner'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tout sélectionner'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer (3)'));
    await tester.pumpAndSettle();

    expect(find.text('Supprimer 3 véhicules'), findsOneWidget);
    expect(
      find.text('• 310 20 155 — TOYOTA Land Cruiser'),
      findsOneWidget,
    );
    expect(
      find.text('• 310 40 026 — TOYOTA Land Cruiser'),
      findsOneWidget,
    );
    expect(find.textContaining('historique'), findsOneWidget);
  });

  testWidgets('le filtre d\'état restreint ce que « tout » prend', (
    tester,
  ) async {
    // Une sélection peut survivre à un changement de filtre. « Supprimer »
    // ne doit emporter que ce que l'écran montre, sinon il retire des
    // véhicules qu'on ne voit plus.
    await _ouvrir(tester, RoleLogistique.garage);

    // « Hors service » paraît deux fois : comme filtre, et comme état sur la
    // carte du véhicule. On vise la pastille de filtre.
    await tester.tap(find.widgetWithText(FilterChipPill, 'Hors service'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sélectionner'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tout sélectionner'));
    await tester.pumpAndSettle();

    expect(find.text('1 véhicule(s) coché(s) sur 1'), findsOneWidget);
    expect(find.text('Supprimer (1)'), findsOneWidget);
  });
}
