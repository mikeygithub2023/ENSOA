// Le NOM d'abord, le prénom ensuite.
//
// C'est ainsi qu'on appelle quelqu'un au rapport, ainsi qu'il se présente, et
// ainsi que les listes de l'école sont tenues. Écrit dans l'autre sens, il
// fallait chercher le patronyme au bout de trois ou quatre prénoms — la 37e
// promotion en compte qui en portent quatre.
//
// La règle vaut pour l'élève comme pour celui qui tient l'application : le
// même ordre partout, sans quoi la même personne se lit de deux façons selon
// l'écran.
import 'package:flutter_test/flutter_test.dart';

import 'package:sig_ensoa/models/profil.dart';
import 'package:sig_ensoa/modules/scolarite/models/apprenant.dart';

Apprenant _apprenant({required String nom, required String prenom}) =>
    Apprenant(
      id: 'a1',
      divisionId: 'd1',
      classeId: 'c1',
      type: ApprenantType.eleve,
      nom: nom,
      prenom: prenom,
      statut: ApprenantStatut.actif,
    );

void main() {
  test("l'apprenant se lit nom d'abord", () {
    expect(
      _apprenant(nom: 'ABE', prenom: 'ATSE ALEX AMIRAL').nomComplet,
      'ABE ATSE ALEX AMIRAL',
    );
  });

  // Une fiche incomplète ne doit pas laisser d'espace en tête ou en queue.
  test('un prénom manquant ne laisse pas d’espace traînant', () {
    expect(_apprenant(nom: 'ABE', prenom: '').nomComplet, 'ABE');
  });

  test('le profil porte déjà le même ordre dans son nom d’usage', () {
    const profil = Profil(id: 'p1', nom: 'DJAMA', prenom: 'Yannick');
    expect(profil.nomDUsage, 'DJAMA Yannick');
  });
}
