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
  _regroupementSuperAdmin();

  group('le tableau de bord', () {
    test("s'ouvre à l'administrateur", () {
      expect(
        _chemins(RoleLogistique.administrateur),
        contains('/'),
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
        expect(_chemins(role), contains('/'));
      });
    }
  });
}

/// Le super administrateur tient le parc, le carburant et l'armement sous une
/// seule rubrique « Soutien technique » à trois onglets ; les chefs de
/// service, eux, gardent leur entrée propre. On vérifie que le regroupement
/// remplace bien les trois entrées pour l'un sans les ôter aux autres.
void _regroupementSuperAdmin() {
  group('le regroupement du soutien technique', () {
    test("remplace les trois entrées pour l'administrateur", () {
      final chemins = _chemins(RoleLogistique.administrateur);

      expect(chemins, contains('/logistique/soutien-technique'));
      expect(chemins, isNot(contains('/logistique/parc')));
      expect(chemins, isNot(contains('/logistique/carburant')));
      expect(chemins, isNot(contains('/logistique/armement')));
    });

    // Le chef de garage n'administre pas la plateforme : il garde son parc,
    // et le regroupement du super administrateur ne le concerne pas.
    test('ne change rien pour le chef de garage', () {
      final chemins = _chemins(RoleLogistique.garage);

      expect(chemins, contains('/logistique/parc'));
      expect(chemins, isNot(contains('/logistique/soutien-technique')));
    });

    // Le commandant de division n'administre pas la plateforme : il garde ses
    // entrées, comme le chef de garage garde la sienne.
    test('ne change rien au commandant de division', () {
      final chemins = elementsPour(
        const Profil(
          id: 'p1',
          nom: 'KOUAME',
          prenom: 'Yao',
          roleScolarite: RoleScolarite.chefDivision,
        ),
      ).map((e) => e.chemin).toList();

      expect(chemins, contains('/scolarite/apprenants'));
      expect(chemins, isNot(contains('/instruction')));
    });

    // Le médecin garde ses entrées : le regroupement n'est pas pour lui.
    test('ne change rien au médecin', () {
      final chemins = elementsPour(
        const Profil(
          id: 'p1',
          nom: 'KOUAME',
          prenom: 'Yao',
          roleScolarite: RoleScolarite.medecin,
        ),
      ).map((e) => e.chemin).toList();

      expect(chemins, contains('/scolarite/consultations'));
      expect(chemins, isNot(contains('/scolarite/sante')));
    });

    test("ne concerne pas l'armurier ni le soutien pétrolier", () {
      expect(
        _chemins(RoleLogistique.armurerie),
        contains('/logistique/armement'),
      );
      expect(
        _chemins(RoleLogistique.armurerie),
        isNot(contains('/logistique/soutien-technique')),
      );
      expect(
        _chemins(RoleLogistique.soutienPetrolier),
        contains('/logistique/carburant'),
      );
    });
  });
}

/// Un service créé par l'administrateur ne tient aucun domaine de l'ERP : il
/// reçoit du travail, et c'est tout.
void _profilPersonnalise() {
  test("chacun a sa liste de tâches, sauf l'élève qui a son espace", () {
    for (final role in RoleLogistique.values) {
      expect(_chemins(role), contains('/logistique/taches'));
    }
    final medecin = elementsPour(
      const Profil(
        id: 'p1',
        nom: 'KOUAME',
        prenom: 'Yao',
        roleScolarite: RoleScolarite.medecin,
      ),
    ).map((e) => e.chemin);
    expect(medecin, contains('/logistique/taches'));

    final eleve = elementsPour(
      const Profil(
        id: 'p1',
        nom: 'KOUAME',
        prenom: 'Yao',
        roleScolarite: RoleScolarite.eleveStagiaire,
      ),
    ).map((e) => e.chemin);
    expect(eleve, isNot(contains('/logistique/taches')));
  });

  group("l'entrée des activités", () {
    // Elle s'appelait « Tâches » et fermait la marche du menu. Elle porte le
    // nom de ce qu'on y organise, et se tient là où l'on s'en sert.
    ElementNav entree(String chemin) => elementsNav.firstWhere(
      (e) => e.chemin == chemin,
    );

    test('porte le nom « Activités »', () {
      expect(entree('/logistique/taches').libelle, 'Activités');
    });

    test('se tient juste avant le Poste de Police', () {
      final chemins = elementsNav.map((e) => e.chemin).toList();
      expect(
        chemins.indexOf('/logistique/taches') + 1,
        chemins.indexOf('/logistique/poste-police'),
      );
    });
  });

  test('un profil personnalisé ne voit que ses tâches', () {
    final chemins = _chemins(RoleLogistique.profilPersonnalise);

    expect(chemins, contains('/logistique/taches'));
    expect(chemins, contains('/'));

    // Ce qui ne le regarde pas : les domaines de l'ERP.
    expect(chemins, isNot(contains('/logistique/parc')));
    expect(chemins, isNot(contains('/logistique/carburant')));
    expect(chemins, isNot(contains('/logistique/armement')));
    expect(chemins, isNot(contains('/scolarite/apprenants')));
    expect(chemins, isNot(contains('/administration')));
    expect(chemins, isNot(contains('/audit')));
  });
}
