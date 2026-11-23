// La quatrième division, et le découpage des promotions en sections.
//
// Deux ajouts qui touchent au même endroit — l'effectif — sans se
// ressembler :
//
//   · la Division de Commandement et Logistique n'instruit personne. Elle
//     n'a ni promotion ni stage, et ses fiches sont celles du personnel de
//     l'école. Ce qu'on garde sous contrôle : qu'elle ne se retrouve pas
//     dans les écrans qui créent des phases, et que ce type de fiche
//     existe réellement ;
//
//   · la section s'attache à la promotion, pas à la phase. Ce qu'on garde
//     sous contrôle : qu'on puisse y verser des élèves, que le volet dise
//     la vérité sur l'effectif de chacune, et que la restriction
//     nominative qui en découle se comporte comme la restriction par
//     phases — nulle vaut « tout », vide vaut « rien ».
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sig_ensoa/modules/scolarite/features/apprenants/bureaux.dart';
import 'package:sig_ensoa/modules/scolarite/features/apprenants/data/apprenants_repository.dart';
import 'package:sig_ensoa/modules/scolarite/features/apprenants/import_apprenants_dialog.dart';
import 'package:sig_ensoa/modules/scolarite/features/apprenants/portee_promotion.dart';
import 'package:sig_ensoa/modules/scolarite/features/apprenants/providers/apprenants_providers.dart';
import 'package:sig_ensoa/modules/scolarite/features/apprenants/sections_dialog.dart';
import 'package:sig_ensoa/modules/scolarite/features/matieres/data/sections_repository.dart';
import 'package:sig_ensoa/modules/scolarite/features/matieres/providers/matieres_providers.dart';
import 'package:sig_ensoa/modules/scolarite/models/apprenant.dart';
import 'package:sig_ensoa/modules/scolarite/models/classe.dart';
import 'package:sig_ensoa/modules/scolarite/models/division.dart';
import 'package:sig_ensoa/modules/scolarite/models/promotion.dart';
import 'package:sig_ensoa/modules/scolarite/models/section.dart';

const _promotion = Promotion(
  id: 'promo-37',
  divisionId: 'div-dfs',
  nom: '37ème promotion',
  annee: 2026,
);

const _premiere = Section(
  id: 'sec-1',
  promotionId: 'promo-37',
  nom: '1ère section',
  ordre: 1,
);
const _deuxieme = Section(
  id: 'sec-2',
  promotionId: 'promo-37',
  nom: '2ème section',
  ordre: 2,
);

Apprenant _eleve(String id, String nom, {String? section}) => Apprenant(
  id: id,
  divisionId: 'div-dfs',
  type: ApprenantType.eleve,
  nom: nom,
  prenom: 'Jean',
  statut: ApprenantStatut.actif,
  classeId: 'phase-fcb',
  promotionId: 'promo-37',
  sectionId: section,
);

final _effectif = [
  _eleve('a', 'ABE'),
  _eleve('b', 'BAMBA', section: 'sec-1'),
  _eleve('c', 'CISSE', section: 'sec-1'),
];

/// Un dépôt qui ne parle à personne : il rend l'effectif qu'on lui donne et
/// retient les affectations qu'on lui demande, pour qu'on puisse les lire.
class _DepotApprenants extends ApprenantsRepository {
  @override
  Future<List<Apprenant>> fetchByPromotion(String promotionId) async =>
      _effectif;
}

class _DepotSections extends SectionsRepository {
  final affectations = <(List<String>, String?)>[];

  @override
  Future<List<Section>> fetchAll() async => [_premiere, _deuxieme];

  @override
  Future<void> affecter({
    required List<String> apprenantIds,
    required String? sectionId,
  }) async {
    affectations.add((apprenantIds, sectionId));
  }
}

Future<void> _ouvrirLaRepartition(
  WidgetTester tester,
  _DepotSections depot,
) async {
  tester.view.physicalSize = const Size(1600, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apprenantsRepositoryProvider.overrideWithValue(_DepotApprenants()),
        sectionsRepositoryProvider.overrideWithValue(depot),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () =>
                  showSectionsDialog(context, promotion: _promotion),
              child: const Text('ouvrir'),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('ouvrir'));
  await tester.pumpAndSettle();
}

void main() {
  group('la division du commandement', () {
    test('elle est la seule à tenir du personnel', () {
      const commandement = Division(
        id: 'd4',
        code: codeDivisionCommandement,
        nom: 'Division de Commandement et Logistique',
      );
      expect(commandement.tientDuPersonnel, isTrue);

      for (final code in [
        'formation_initiale',
        'formation_specialistes',
        'formation_continue',
      ]) {
        expect(
          Division(id: code, code: code, nom: code).tientDuPersonnel,
          isFalse,
          reason: '$code instruit : elle a des promotions ou des stages',
        );
      }
    });

    test('la fiche du personnel est une fiche comme les autres', () {
      expect(apprenantTypeFromString('personnel'), ApprenantType.personnel);
      expect(ApprenantType.personnel.label, 'Personnel');

      // Une valeur inconnue retombe sur l'élève plutôt que de faire
      // échouer la lecture d'une fiche.
      expect(apprenantTypeFromString('fantaisie'), ApprenantType.eleve);
    });

    testWidgets("l'import s'ouvre sur le personnel, grade compris", (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1600, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showImportApprenantsDialog(
                    context,
                    division: const Division(
                      id: 'd4',
                      code: codeDivisionCommandement,
                      nom: 'Division de Commandement et Logistique',
                    ),
                    // Pas de phase : c'est ce qui fait du personnel.
                    classe: null,
                  ),
                  child: const Text('ouvrir'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('ouvrir'));
      await tester.pumpAndSettle();

      expect(find.text('Importer du personnel (Excel)'), findsOneWidget);
      // Le classeur attendu est l'état nominatif de la DORH, tel quel : le
      // grade s'y lit, on ne le déduit pas d'une phase qu'il n'a pas.
      expect(find.text('GRADE'), findsWidgets);
      expect(find.text('NOM ET PRENOMS'), findsWidgets);
      // Le matricule identifie ; quand l'état nominatif l'a oublié, le
      // numéro mécanographique le remplace.
      expect(find.text('Unique ; à défaut, le mécano identifie'), findsWidgets);
    });
  });

  group('ce que chaque bureau propose', () {
    const commandement = Division(
      id: 'd4',
      code: codeDivisionCommandement,
      nom: 'Division de Commandement et Logistique',
    );
    const initiale = Division(
      id: 'd1',
      code: 'formation_initiale',
      nom: 'Division de Formation Initiale',
    );

    // L'instruction note des élèves : une division qui n'instruit personne
    // n'a rien à y faire, et la proposer menait à un écran vide.
    test("l'instruction ne propose pas la division du commandement", () {
      expect(
        divisionsDuBureau(const [
          initiale,
          commandement,
        ], Bureau.instruction).map((d) => d.nom),
        ['Division de Formation Initiale'],
      );
    });

    test('les ressources humaines la tiennent comme les autres', () {
      expect(
        divisionsDuBureau(const [
          initiale,
          commandement,
        ], Bureau.ressourcesHumaines),
        hasLength(2),
      );
    });
  });

  group('où l’on peut ouvrir une fiche', () {
    const commandement = Division(
      id: 'd4',
      code: codeDivisionCommandement,
      nom: 'Division de Commandement et Logistique',
    );
    const initiale = Division(
      id: 'd1',
      code: 'formation_initiale',
      nom: 'Division de Formation Initiale',
    );
    const phase = Classe(
      id: 'phase-fcb',
      divisionId: 'd1',
      type: ClasseType.phase,
      nom: 'FCB',
      promotionId: 'promo-37',
    );

    // Le cœur du sujet : le personnel s'enregistre et s'importe sans
    // phase, parce qu'il n'est en formation nulle part. Sans cette règle,
    // la division du commandement s'ouvrait sur un écran sans aucun
    // bouton, et l'on ne pouvait y inscrire personne.
    test('le personnel s’enregistre sans phase', () {
      expect(
        ouvreUneFiche(division: commandement, classeInscription: null),
        isTrue,
      );
    });

    test('un élève exige une phase ou un stage', () {
      expect(
        ouvreUneFiche(division: initiale, classeInscription: null),
        isFalse,
      );
      expect(
        ouvreUneFiche(division: initiale, classeInscription: phase),
        isTrue,
      );
    });

    // Sous « Toutes », on ne sait pas où écrire : les boutons se taisent
    // plutôt que d'échouer à l'enregistrement.
    test('sous « Toutes », on n’ouvre rien', () {
      expect(ouvreUneFiche(division: null, classeInscription: null), isFalse);
      expect(ouvreUneFiche(division: null, classeInscription: phase), isFalse);
    });
  });

  group('la portée nominative', () {
    test('nulle, elle ne restreint rien', () {
      final tout = AsyncValue.data(_effectif);
      expect(
        tout.pourLesApprenants(null, (a) => a.id).value,
        hasLength(_effectif.length),
      );
    });

    // Un ensemble vide n'est pas l'absence de restriction : une section
    // qu'on vient de créer n'a personne, et l'écran doit le montrer plutôt
    // que de retomber sur la promotion entière.
    test('vide, elle ne laisse passer personne', () {
      final tout = AsyncValue.data(_effectif);
      expect(tout.pourLesApprenants(const {}, (a) => a.id).value, isEmpty);
    });

    test('elle retient ceux qu’on lui nomme', () {
      final tout = AsyncValue.data(_effectif);
      final retenus = tout.pourLesApprenants(const {
        'b',
        'c',
      }, (a) => a.id).value!;
      expect(retenus.map((a) => a.nom), ['BAMBA', 'CISSE']);
    });
  });

  group('la répartition en sections', () {
    testWidgets('chaque section annonce son effectif', (tester) async {
      await _ouvrirLaRepartition(tester, _DepotSections());

      expect(find.text('37ème promotion (2026)'), findsOneWidget);
      expect(find.text('Sans section'), findsOneWidget);
      expect(find.text('1ère section'), findsOneWidget);
      expect(find.text('2ème section'), findsOneWidget);

      // Un seul élève sans section, deux dans la première, aucun dans la
      // seconde : les trois comptes se lisent côte à côte.
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
    });

    // Le volet s'ouvre sur ceux qui ne sont pas encore répartis : c'est là
    // qu'est tout le monde le jour où l'on commence.
    testWidgets('elle s’ouvre sur ceux qui restent à répartir', (tester) async {
      await _ouvrirLaRepartition(tester, _DepotSections());

      expect(find.text('ABE Jean'), findsOneWidget);
      expect(find.text('BAMBA Jean'), findsNothing);
      expect(find.text('1 élève(s)'), findsOneWidget);
    });

    testWidgets('on verse la sélection dans une section', (tester) async {
      final depot = _DepotSections();
      await _ouvrirLaRepartition(tester, depot);

      await tester.tap(find.widgetWithText(CheckboxListTile, 'ABE Jean'));
      await tester.pumpAndSettle();
      expect(find.text('1 retenu(s) sur 1'), findsOneWidget);

      await tester.tap(find.text('Verser dans…'));
      await tester.pumpAndSettle();

      // La section qu'on regarde ne se propose pas elle-même ; celles où
      // l'on peut verser, si — plus le retrait pur et simple.
      await tester.tap(find.text('2ème section').last);
      await tester.pumpAndSettle();

      expect(depot.affectations, hasLength(1));
      expect(depot.affectations.single.$1, ['a']);
      expect(depot.affectations.single.$2, 'sec-2');
    });

    testWidgets('sans sélection, on ne verse rien', (tester) async {
      final depot = _DepotSections();
      await _ouvrirLaRepartition(tester, depot);

      await tester.tap(find.text('Verser dans…'));
      await tester.pumpAndSettle();

      // Le menu ne s'ouvre pas : rien à déplacer.
      expect(find.text('2ème section'), findsOneWidget);
      expect(depot.affectations, isEmpty);
    });
  });
}
