// Ce que chaque service lit sur son accueil.
//
// L'armurier a signalé trois fois de suite qu'il voyait les compteurs du
// soutien technique entier. Deux de mes trois corrections portaient sur un
// autre écran. Ce test rend l'accueil pour de bon, poste par poste, et dit
// ce qui s'y affiche : il n'y a plus à le supposer.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:sig_ensoa/core/roles.dart';
import 'package:sig_ensoa/features/accueil/accueil_screen.dart';
import 'package:sig_ensoa/features/accueil/providers/apercu_providers.dart';
import 'package:sig_ensoa/features/auth/providers/auth_providers.dart';
import 'package:sig_ensoa/models/profil.dart';

Profil _profil(RoleLogistique role) => Profil(
  id: 'p1',
  nom: 'KOUASSI',
  prenom: 'Rèmi',
  grade: 'SGT',
  roleLogistique: role,
);

/// Aucun de ces aperçus ne doit atteindre le réseau : le test porte sur ce
/// que l'écran choisit d'afficher, pas sur les chiffres.
Future<void> _ouvrir(WidgetTester tester, RoleLogistique role) async {
  tester.view.physicalSize = const Size(1400, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        profilCourantProvider.overrideWith((ref) async => _profil(role)),
        apercuLogistiqueProvider.overrideWith(
          (ref) async => const ApercuLogistique(
            vehicules: 2,
            vehiculesDisponibles: 1,
            litresEnSoute: 6350,
            armes: 1,
            armesEnDotation: 1,
          ),
        ),
        apercuArmurerieProvider.overrideWith(
          (ref) async => const ApercuArmurerie(
            armes: 1,
            enDotation: 1,
            cartouches: 0,
            inspectionsEchues: 0,
          ),
        ),
        apercuGarageProvider.overrideWith(
          (ref) async => const ApercuGarage(
            vehicules: 2,
            disponibles: 1,
            enReparation: 0,
            vidangesAPrevoir: 0,
          ),
        ),
        apercuCarburantProvider.overrideWith(
          (ref) async => const ApercuCarburant(
            litres: 6350,
            soutes: 2,
            soutesEnAlerte: 0,
            sortiesDuJour: 0,
          ),
        ),
      ],
      child: const MaterialApp(home: Scaffold(body: AccueilScreen())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  // Le bandeau affiche la date en toutes lettres : sans ces données de
  // locale, l'écran ne se construit pas du tout dans le banc d'essai.
  setUpAll(() => initializeDateFormatting('fr_FR'));

  testWidgets("l'armurier voit son armurerie, pas le parc", (tester) async {
    await _ouvrir(tester, RoleLogistique.armurerie);

    // Le titre de section est rendu en capitales.
    expect(find.text('ARMURERIE'), findsOneWidget);
    expect(find.text('Cartouches en stock'), findsOneWidget);
    expect(find.text('Inspections échues'), findsOneWidget);

    // Ce qui ne le regarde pas.
    expect(find.text('Véhicules disponibles'), findsNothing);
    expect(find.text('Litres en soute'), findsNothing);
  });

  testWidgets('le garage voit son parc, pas les soutes', (tester) async {
    await _ouvrir(tester, RoleLogistique.garage);

    expect(find.text('Véhicules disponibles'), findsOneWidget);
    expect(find.text('Vidanges à prévoir'), findsOneWidget);
    expect(find.text('Litres en soute'), findsNothing);
    expect(find.text('Armes inventoriées'), findsNothing);
  });

  testWidgets('le soutien pétrolier voit ses soutes, pas le parc', (
    tester,
  ) async {
    await _ouvrir(tester, RoleLogistique.soutienPetrolier);

    expect(find.text('Litres en soute'), findsOneWidget);
    expect(find.text('Soutes en service'), findsOneWidget);
    expect(find.text('Véhicules disponibles'), findsNothing);
    expect(find.text('Armes inventoriées'), findsNothing);
  });

  testWidgets('le chef du service garde la vue d\'ensemble', (tester) async {
    await _ouvrir(tester, RoleLogistique.chefSoutienTechnique);

    expect(find.text('Véhicules disponibles'), findsOneWidget);
    expect(find.text('Litres en soute'), findsOneWidget);
    expect(find.text('Armes inventoriées'), findsOneWidget);
  });
}
