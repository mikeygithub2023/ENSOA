// Le personnel de l'école s'absente et part en permission comme les élèves.
//
// Les deux registres ont été écrits quand l'école ne tenait que des élèves :
// la phase y était obligatoire, en base comme dans le code. Le personnel de
// la Division de Commandement et Logistique n'en suit aucune — ses fiches
// paraissaient dans les deux onglets sans qu'on puisse y porter la moindre
// écriture. Ces épreuves fixent la règle nouvelle : la phase est facultative,
// la division ne l'est pas.

import 'package:flutter_test/flutter_test.dart';

import 'package:sig_ensoa/modules/scolarite/features/apprenants/bureaux.dart';
import 'package:sig_ensoa/modules/scolarite/features/apprenants/data/absences_repository.dart';
import 'package:sig_ensoa/modules/scolarite/features/apprenants/data/permissions_repository.dart';
import 'package:sig_ensoa/modules/scolarite/features/apprenants/entity_tabs.dart';
import 'package:sig_ensoa/modules/scolarite/models/absence.dart';
import 'package:sig_ensoa/modules/scolarite/models/classe.dart';
import 'package:sig_ensoa/modules/scolarite/models/division.dart';
import 'package:sig_ensoa/modules/scolarite/models/permission.dart';

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
const stage = Classe(
  id: 'stage-cat',
  divisionId: 'd3',
  type: ClasseType.stage,
  nom: 'CAT',
);

void main() {
  group("l'absence d'un militaire sans phase", () {
    test('elle part en base avec une phase nulle, pas avec un vide', () {
      final draft = AbsenceDraft(
        apprenantId: 'a1',
        divisionId: commandement.id,
        dateDebut: DateTime(2026, 5, 18),
      );
      final json = draft.toInsertJson();
      expect(json['classe_id'], isNull);
      expect(json['division_id'], commandement.id);
      expect(json['date_debut'], '2026-05-18');
    });

    test('la phase reste portée quand il y en a une', () {
      final draft = AbsenceDraft(
        apprenantId: 'a2',
        divisionId: initiale.id,
        classeId: phase.id,
        dateDebut: DateTime(2026, 5, 18),
      );
      expect(draft.toInsertJson()['classe_id'], phase.id);
    });

    test('elle se relit depuis une ligne sans phase', () {
      final absence = Absence.fromJson({
        'id': 'abs-1',
        'apprenant_id': 'a1',
        'division_id': commandement.id,
        'classe_id': null,
        'date_debut': '2026-05-18',
        'created_at': '2026-05-18T08:00:00Z',
      });
      expect(absence.classeId, isNull);
      expect(absence.divisionId, commandement.id);
    });
  });

  group("la permission d'un militaire sans phase", () {
    test('elle part en base avec une phase nulle', () {
      final draft = PermissionDraft(
        apprenantId: 'a1',
        divisionId: commandement.id,
        dateDepart: DateTime(2026, 5, 18),
        dateRetour: DateTime(2026, 5, 25),
        localite: 'Bouaké',
      );
      final json = draft.toInsertJson();
      expect(json['classe_id'], isNull);
      expect(json['division_id'], commandement.id);
      expect(json['date_depart'], '2026-05-18');
      expect(json['date_retour'], '2026-05-25');
    });

    test('elle se relit depuis une ligne sans phase', () {
      final permission = Permission.fromJson({
        'id': 'perm-1',
        'apprenant_id': 'a1',
        'division_id': commandement.id,
        'classe_id': null,
        'date_depart': '2026-05-18',
        'date_retour': '2026-05-25',
        'created_at': '2026-05-18T08:00:00Z',
      });
      expect(permission.classeId, isNull);
      expect(permission.divisionId, commandement.id);
    });
  });

  // Les deux boutons d'enregistrement suivent désormais la même règle que
  // la fiche elle-même : la division suffit au personnel, l'élève exige en
  // plus une phase ou un stage.
  group("qui peut porter une écriture dans les deux registres", () {
    test('le personnel, sous sa seule division', () {
      expect(
        ouvreUneFiche(division: commandement, classeInscription: null),
        isTrue,
      );
    });

    test('un élève, seulement dans sa phase', () {
      expect(
        ouvreUneFiche(division: initiale, classeInscription: null),
        isFalse,
      );
    });

    test('sous « Toutes », personne', () {
      expect(ouvreUneFiche(division: null, classeInscription: null), isFalse);
    });
  });

  // Sous « Toutes », la liste réunit tout l'effectif de l'école depuis que la
  // DCL y figure : l'intitulé le disait encore « Élèves/Stagiaires ».
  group("l'intitulé de l'onglet de l'effectif", () {
    test('sous « Toutes », il nomme aussi les personnels', () {
      expect(
        intituleDeLEffectif(division: null, classe: null, sousPromotion: false),
        'Personnels/Élèves/Stagiaires',
      );
    });

    test("dans la division du commandement, il ne dit que le personnel", () {
      expect(
        intituleDeLEffectif(
          division: commandement,
          classe: null,
          sousPromotion: false,
        ),
        'Personnel',
      );
    });

    test('dans une division de formation, les élèves et les stagiaires', () {
      expect(
        intituleDeLEffectif(
          division: initiale,
          classe: null,
          sousPromotion: false,
        ),
        'Élèves/Stagiaires',
      );
    });

    test('sous une promotion, des élèves et rien d’autre', () {
      expect(
        intituleDeLEffectif(division: null, classe: null, sousPromotion: true),
        'Élèves',
      );
    });

    test('une phase ne tient que des élèves, un stage que des stagiaires', () {
      expect(
        intituleDeLEffectif(
          division: initiale,
          classe: phase,
          sousPromotion: false,
        ),
        'Élèves',
      );
      expect(
        intituleDeLEffectif(
          division: initiale,
          classe: stage,
          sousPromotion: false,
        ),
        'Stagiaires',
      );
    });
  });
}
