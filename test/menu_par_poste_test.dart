// Qui voit quelle rubrique.
//
// Ce test est né d'une méprise coûteuse : quatre tableaux de bord écrits pour
// des postes qui n'avaient pas l'entrée de menu permettant d'y accéder. Le
// travail était juste, la porte fermée. On vérifie donc ici la porte.
import 'package:flutter_test/flutter_test.dart';

import 'package:sig_ensoa/core/roles.dart';
import 'package:sig_ensoa/features/shell/nav_items.dart';
import 'package:sig_ensoa/models/profil.dart';

Profil _profil(RoleLogistique role) =>
    Profil(id: 'p1', nom: 'KOUAME', prenom: 'Yao', roleLogistique: role);

List<String> _chemins(RoleLogistique role) =>
    elementsPour(_profil(role)).map((e) => e.chemin).toList();

void main() {
  _profilPersonnalise();

  group('le tableau de bord', () {
    test("s'ouvre à l'administrateur", () {
      expect(
        _chemins(RoleLogistique.administrateur),
        contains('/tableau-de-bord'),
      );
    });

    // Chacun de ces postes a son propre tableau de bord. Sans cette entrée,
    // aucun d'eux ne peut l'atteindre — et l'écran qu'il prend pour « le
    // tableau de bord » est en réalité son accueil.
    for (final role in [
      RoleLogistique.chefSoutienTechnique,
      RoleLogistique.armurerie,
      RoleLogistique.garage,
      RoleLogistique.soutienPetrolier,
      RoleLogistique.officierAdjoint,
    ]) {
      test("s'ouvre à ${role.libelle}", () {
        expect(_chemins(role), contains('/tableau-de-bord'));
      });
    }
  });
}

/// Un service créé par l'administrateur ne tient aucun domaine de l'ERP : il
/// reçoit du travail, et c'est tout.
void _profilPersonnalise() {
  test('un profil personnalisé ne voit que ses tâches', () {
    final chemins = _chemins(RoleLogistique.profilPersonnalise);

    expect(chemins, contains('/logistique/mes-taches'));
    expect(chemins, contains('/tableau-de-bord'));

    // Ce qui ne le regarde pas : les domaines de l'ERP.
    expect(chemins, isNot(contains('/logistique/parc')));
    expect(chemins, isNot(contains('/logistique/carburant')));
    expect(chemins, isNot(contains('/logistique/armement')));
    expect(chemins, isNot(contains('/scolarite/apprenants')));
    expect(chemins, isNot(contains('/administration')));
    expect(chemins, isNot(contains('/audit')));
  });
}
