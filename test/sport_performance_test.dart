// La fiche de l'apprenant dit la performance, pas seulement la note.
//
// « 14 / 20 » est une lecture du barème : elle donne le rang, pas ce qui a
// été fait. Douze minutes au 3000 et vingt minutes au 3000 peuvent valoir la
// même note dans deux barèmes différents, et c'est la performance qu'on
// relit l'année suivante. Chaque séance porte donc sa valeur, mise en forme
// dans l'unité de son activité.
import 'package:flutter_test/flutter_test.dart';

import 'package:sig_ensoa/modules/scolarite/features/apprenants/providers/sport_providers.dart';
import 'package:sig_ensoa/modules/scolarite/models/sous_module.dart';

ActiviteSportive _activite(String id, String nom, UniteEpreuve unite) =>
    ActiviteSportive(
      id: id,
      nom: nom,
      unite: unite,
      meilleur: SensEpreuve.minimum,
    );

PerformanceSportive _perf(String sousModuleId, num valeur) =>
    PerformanceSportive(
      id: 'p-$sousModuleId',
      sousModuleId: sousModuleId,
      apprenantId: 'a1',
      valeur: valeur,
      note: 14,
    );

void main() {
  final cross = _activite('act-cross', 'CROSS', UniteEpreuve.secondes);
  final traction = _activite(
    'act-traction',
    'Traction',
    UniteEpreuve.repetitions,
  );

  test('chaque séance est rendue dans l’unité de son activité', () {
    final mise = performancesParSeance([
      (performance: _perf('s1', 750), activiteId: cross.id),
      (performance: _perf('s2', 12), activiteId: traction.id),
    ], [cross, traction]);

    // Un chrono se lit en minutes et secondes, pas en secondes cumulées.
    expect(mise['s1'], '12′30″');
    expect(mise['s2'], '12 rép.');
  });

  test('moins d’une minute reste en secondes', () {
    final mise = performancesParSeance([
      (performance: _perf('s1', 48), activiteId: cross.id),
    ], [cross]);

    expect(mise['s1'], '48 s');
  });

  // Sans unité, un nombre nu induirait en erreur : la séance s'efface, la
  // note reste seule.
  test('une séance dont l’activité a disparu du catalogue est laissée', () {
    final mise = performancesParSeance([
      (performance: _perf('s1', 750), activiteId: cross.id),
      (performance: _perf('s2', 12), activiteId: 'act-supprimee'),
    ], [cross]);

    expect(mise.keys, ['s1']);
  });

  test('aucune performance, aucune ligne', () {
    expect(performancesParSeance(const [], [cross]), isEmpty);
  });
}
