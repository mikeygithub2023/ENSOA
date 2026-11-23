// Les locaux disciplinaires.
//
// L'école relevait les absences et les permissions, jamais les punitions :
// un élève aux arrêts était compté présent à la prise d'armes, et le seul
// moyen d'expliquer son absence des rangs était de l'inscrire en absence —
// ce qui confond une faute punie avec une absence constatée.
//
// Ce qu'on garde sous contrôle ici :
//
//   · le calcul des jours. Le premier jour compte : trois jours à partir du
//     lundi s'achèvent le mercredi, et non le jeudi. C'est le genre d'erreur
//     qu'on ne voit pas et qui retient quelqu'un un jour de trop ;
//
//   · la sortie. Une punition levée libère immédiatement ; une sortie qu'on
//     a oublié de marquer ne retient personne au-delà de son terme — on ne
//     garde pas un homme aux arrêts par défaut d'écriture ;
//
//   · la rubrique elle-même : aux ressources humaines, jamais à
//     l'instruction, et ouverte au personnel de l'école comme aux élèves.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sig_ensoa/modules/scolarite/features/apprenants/bureaux.dart';
import 'package:sig_ensoa/modules/scolarite/features/apprenants/data/apprenants_repository.dart';
import 'package:sig_ensoa/modules/scolarite/features/apprenants/data/locaux_disciplinaires_repository.dart';
import 'package:sig_ensoa/modules/scolarite/features/apprenants/entity_tabs.dart';
import 'package:sig_ensoa/modules/scolarite/features/apprenants/locaux_disciplinaires_tab_view.dart';
import 'package:sig_ensoa/modules/scolarite/features/apprenants/providers/apprenants_providers.dart';
import 'package:sig_ensoa/modules/scolarite/features/apprenants/providers/locaux_disciplinaires_providers.dart';
import 'package:sig_ensoa/modules/scolarite/features/matieres/data/classes_repository.dart';
import 'package:sig_ensoa/modules/scolarite/features/matieres/providers/matieres_providers.dart';
import 'package:sig_ensoa/modules/scolarite/models/apprenant.dart';
import 'package:sig_ensoa/modules/scolarite/models/classe.dart';
import 'package:sig_ensoa/modules/scolarite/models/division.dart';
import 'package:sig_ensoa/modules/scolarite/models/local_disciplinaire.dart';

final _lundi = DateTime(2026, 11, 23);
final _mardi = DateTime(2026, 11, 24);
final _mercredi = DateTime(2026, 11, 25);
final _jeudi = DateTime(2026, 11, 26);

const _dfi = Division(
  id: 'div-dfi',
  code: 'formation_initiale',
  nom: 'Division de Formation Initiale',
);
const _dcl = Division(
  id: 'div-dcl',
  code: codeDivisionCommandement,
  nom: 'Division de Commandement et Logistique',
);
const _fcb = Classe(
  id: 'phase-fcb',
  divisionId: 'div-dfi',
  type: ClasseType.phase,
  nom: 'FCB',
  promotionId: 'promo-37',
);

const _eleve = Apprenant(
  id: 'app-1',
  divisionId: 'div-dfi',
  type: ApprenantType.eleve,
  nom: 'KOUAME',
  prenom: 'Yao',
  statut: ApprenantStatut.actif,
  classeId: 'phase-fcb',
  promotionId: 'promo-37',
);

const _adjudant = Apprenant(
  id: 'app-2',
  divisionId: 'div-dcl',
  type: ApprenantType.personnel,
  nom: 'BAMBA',
  prenom: 'Abou',
  statut: ApprenantStatut.actif,
);

LocalDisciplinaire _sejour({
  DateTime? debut,
  int jours = 3,
  DateTime? sortie,
  String? classeId = 'phase-fcb',
}) => LocalDisciplinaire(
  id: 'loc-1',
  apprenantId: 'app-1',
  divisionId: 'div-dfi',
  classeId: classeId,
  dateDebut: debut ?? _lundi,
  jours: jours,
  motif: 'Retard au rassemblement',
  autorite: 'CNE TIA',
  dateSortie: sortie,
);

/// Des dépôts qui ne parlent à personne.
class _DepotApprenants extends ApprenantsRepository {
  @override
  Future<List<Apprenant>> fetchByClasse(String classeId) async => [_eleve];

  @override
  Future<List<Apprenant>> fetchByPromotion(String promotionId) async => [
    _eleve,
  ];

  @override
  Future<List<Apprenant>> fetchByDivision(String divisionId) async =>
      divisionId == 'div-dcl' ? [_adjudant] : [_eleve];
}

class _DepotClasses extends ClassesRepository {
  @override
  Future<List<Classe>> fetchAll() async => [_fcb];
}

class _DepotLocaux extends LocauxDisciplinairesRepository {
  _DepotLocaux([this.sejours = const []]);

  final List<LocalDisciplinaire> sejours;

  @override
  Future<List<LocalDisciplinaire>> fetchByClasse(String classeId) async =>
      sejours;

  @override
  Future<List<LocalDisciplinaire>> fetchByDivision(String divisionId) async =>
      sejours;

  @override
  Future<List<LocalDisciplinaire>> fetchTous() async => sejours;
}

Future<void> _ouvrirLOnglet(
  WidgetTester tester, {
  required Division? division,
  required Classe? classe,
  List<LocalDisciplinaire> sejours = const [],
}) async {
  tester.view.physicalSize = const Size(1600, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apprenantsRepositoryProvider.overrideWithValue(_DepotApprenants()),
        classesRepositoryProvider.overrideWithValue(_DepotClasses()),
        locauxDisciplinairesRepositoryProvider.overrideWithValue(
          _DepotLocaux(sejours),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1200,
            height: 800,
            child: LocauxDisciplinairesTabView(
              division: division,
              classe: classe,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  group('la punition court du premier au dernier jour', () {
    // Trois jours à partir du lundi s'achèvent le mercredi. Compter le
    // premier jour pour rien retiendrait l'intéressé jusqu'au jeudi.
    test('le premier jour compte', () {
      expect(_sejour(debut: _lundi, jours: 3).dateFinPrevue, _mercredi);
      expect(_sejour(debut: _lundi, jours: 1).dateFinPrevue, _lundi);
    });

    test('du premier au dernier jour, et pas au-delà', () {
      final sejour = _sejour(debut: _mardi, jours: 2);
      expect(sejour.estAuxArretsLe(_lundi), isFalse);
      expect(sejour.estAuxArretsLe(_mardi), isTrue);
      expect(sejour.estAuxArretsLe(_mercredi), isTrue);
      expect(sejour.estAuxArretsLe(_jeudi), isFalse);
    });

    // L'heure ne compte pas : seule la journée.
    test("le jour se lit sans l'heure", () {
      final sejour = _sejour(debut: _lundi, jours: 1);
      expect(sejour.estAuxArretsLe(DateTime(2026, 11, 23, 23, 59)), isTrue);
    });

    test('une punition levée libère le jour même', () {
      final sejour = _sejour(debut: _lundi, jours: 3, sortie: _mardi);
      expect(sejour.estAuxArretsLe(_lundi), isTrue);
      expect(sejour.estAuxArretsLe(_mardi), isFalse);
      expect(sejour.enCours, isFalse);
    });

    // On ne garde personne aux arrêts par défaut d'écriture.
    test("une sortie oubliée ne retient personne, mais se signale", () {
      final sejour = _sejour(debut: _lundi, jours: 1);
      expect(sejour.estAuxArretsLe(_jeudi), isFalse);
      expect(sejour.sortieEnRetard(_jeudi), isTrue);
      expect(sejour.sortieEnRetard(_lundi), isFalse);
    });

    // Le personnel de l'école ne suit aucune phase : la colonne est nulle,
    // et la fiche doit s'en accommoder.
    test('le personnel va aux arrêts sans phase', () {
      final sejour = LocalDisciplinaire.fromJson({
        'id': 'loc-2',
        'apprenant_id': 'app-2',
        'division_id': 'div-dcl',
        'classe_id': null,
        'date_debut': '2026-11-23',
        'jours': 2,
        'motif': 'Absence au rapport',
        'autorite': null,
        'date_sortie': null,
      });
      expect(sejour.classeId, isNull);
      expect(sejour.dateFinPrevue, _mardi);
      expect(sejour.estAuxArretsLe(_mardi), isTrue);
    });
  });

  group('la rubrique', () {
    test('elle revient aux ressources humaines, jamais à l\'instruction', () {
      expect(
        ongletsDuBureau(Bureau.ressourcesHumaines, avecClasse: true),
        contains(OngletEffectif.locauxDisciplinaires),
      );
      expect(
        ongletsDuBureau(Bureau.ressourcesHumaines, avecClasse: false),
        contains(OngletEffectif.locauxDisciplinaires),
      );
      expect(
        ongletsDuBureau(Bureau.instruction, avecClasse: true),
        isNot(contains(OngletEffectif.locauxDisciplinaires)),
      );
    });

    testWidgets('sous une phase, on peut mettre aux arrêts', (tester) async {
      await _ouvrirLOnglet(tester, division: _dfi, classe: _fcb);
      expect(find.text('Mettre aux arrêts'), findsOneWidget);
      expect(
        find.textContaining('Personne aux locaux disciplinaires'),
        findsOneWidget,
      );
    });

    // Le personnel de l'école n'a ni phase ni stage : si la saisie exigeait
    // une phase, aucun sous-officier de l'école ne pourrait être puni.
    testWidgets('le personnel aussi, sans phase', (tester) async {
      await _ouvrirLOnglet(tester, division: _dcl, classe: null);
      expect(find.text('Mettre aux arrêts'), findsOneWidget);
    });

    // Sous « Toutes », il n'y a pas de division à quoi rattacher l'écriture.
    testWidgets('sous « Toutes », on ne punit personne', (tester) async {
      await _ouvrirLOnglet(tester, division: null, classe: null);
      expect(find.text('Mettre aux arrêts'), findsNothing);
    });

    testWidgets('ce qui court se distingue de ce qui est purgé', (
      tester,
    ) async {
      await _ouvrirLOnglet(
        tester,
        division: _dfi,
        classe: _fcb,
        sejours: [_sejour(debut: DateTime.now(), jours: 30)],
      );
      expect(find.text('KOUAME Yao'), findsOneWidget);
      expect(find.text('Aux arrêts'), findsOneWidget);
      expect(find.text('Marquer la sortie'), findsOneWidget);
      expect(find.textContaining('Retard au rassemblement'), findsOneWidget);

      await _ouvrirLOnglet(
        tester,
        division: _dfi,
        classe: _fcb,
        sejours: [
          _sejour(
            debut: DateTime(2026, 1, 5),
            jours: 3,
            sortie: DateTime(2026, 1, 7),
          ),
        ],
      );
      expect(find.text('Sorti'), findsOneWidget);
      expect(find.text('Marquer la sortie'), findsNothing);
    });
  });
}
