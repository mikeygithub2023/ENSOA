// Le grade suit la phase — et la division qui la donne.
//
// La Formation Commune de Base se fait des deux côtés de l'école. En FCB,
// un élève de la Division de Formation Initiale est élève sous-officier
// d'active ; celui de la Division de Formation des Spécialistes est élève
// sous-officier spécialiste. Même nom de phase, deux grades : c'est la
// division qui tranche, et ce grade part sur les bulletins.
//
// La même règle vit côté base, dans `scolarite.grade_de_la_phase`. Si l'un
// des deux barèmes change, l'autre doit changer avec lui.
import 'package:flutter_test/flutter_test.dart';

import 'package:sig_ensoa/modules/scolarite/features/apprenants/grade_defaults.dart';

void main() {
  const initiale = 'formation_initiale';
  const specialistes = codeDivisionSpecialistes;

  group('la Formation Commune de Base', () {
    test('fait des élèves sous-officiers d’active en Formation Initiale', () {
      expect(
        defaultGradeForClasse('FCB', divisionCode: initiale),
        "Elève sous-officier d'active de première année",
      );
    });

    test('fait des spécialistes chez les spécialistes', () {
      expect(
        defaultGradeForClasse('FCB', divisionCode: specialistes),
        'Elève sous-officier spécialiste de première année',
      );
    });

    // Les noms se saisissent à la main.
    test('se reconnaît quelle que soit la casse', () {
      expect(
        defaultGradeForClasse('fcb', divisionCode: specialistes),
        'Elève sous-officier spécialiste de première année',
      );
    });
  });

  group('les deux années de cours d’application', () {
    test('suivent la même règle', () {
      expect(
        defaultGradeForClasse('CA 1', divisionCode: specialistes),
        'Elève sous-officier spécialiste de première année',
      );
      expect(
        defaultGradeForClasse('CA 2', divisionCode: specialistes),
        'Elève sous-officier spécialiste de deuxième année',
      );
      expect(
        defaultGradeForClasse('CA 2', divisionCode: initiale),
        "Elève sous-officier d'active de deuxième année",
      );
    });
  });

  // Ces phases disent la spécialité dans leur nom : la division n'a plus
  // rien à trancher.
  group('les phases qui se nomment elles-mêmes', () {
    test('gardent leur grade, quelle que soit la division', () {
      for (final code in [initiale, specialistes, null]) {
        expect(
          defaultGradeForClasse('ESOS 1', divisionCode: code),
          'Elève sous-officier spécialiste de première année',
        );
        expect(
          defaultGradeForClasse('ESOA 2', divisionCode: code),
          "Elève sous-officier d'active de deuxième année",
        );
      }
    });
  });

  // Hors barème, le grade saisi à la main est conservé tel quel : rendre
  // nul, c'est dire « je ne sais pas », et non « efface ».
  test('une phase hors barème ne propose aucun grade', () {
    expect(defaultGradeForClasse('Stage moniteur'), isNull);
    expect(defaultGradeForClasse('', divisionCode: specialistes), isNull);
  });
}
