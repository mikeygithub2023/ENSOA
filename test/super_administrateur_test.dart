// L'administrateur commande l'école : aucune rubrique ne lui est fermée —
// sauf celles qu'il retrouve regroupées ailleurs.
//
// Ce test existe parce que la liste de ses droits, tenue à la main, l'avait
// laissé sans accès aux consultations ni aux visites médicales — sans que
// rien ne le signale. Il échouera désormais si une rubrique nouvelle oublie
// de s'ouvrir à lui.
//
// Une exception, voulue : le parc, le carburant et l'armement lui sont
// présentés regroupés sous « Soutien technique », à trois onglets. Leurs
// entrées séparées lui sont donc masquées — mais la rubrique groupée doit
// rester ouverte, et masquer une rubrique sans la regrouper la lui fermerait
// en douce. Le second test tient cette garde.
import 'package:flutter_test/flutter_test.dart';
import 'package:sig_ensoa/modules/scolarite/features/scolarite_screen.dart';

import 'package:sig_ensoa/core/postes.dart';
import 'package:sig_ensoa/core/roles.dart';
import 'package:sig_ensoa/features/shell/nav_items.dart';
import 'package:sig_ensoa/models/profil.dart';

const _administrateur = Profil(
  id: 'adm',
  nom: 'BENIE',
  prenom: 'Christian',
  roleScolarite: RoleScolarite.admin,
  roleLogistique: RoleLogistique.administrateur,
);

/// « Mon espace » montre le dossier d'un élève, « Mes tâches » celles qu'un
/// service a reçues : deux vues personnelles, non des rubriques de l'ERP.
const _vuesPersonnelles = {
  Permission.voirSonEspaceEleve,
  Permission.voirMesTaches,
};

void main() {
  test('toutes les rubriques lui sont ouvertes', () {
    final ouvertes = elementsPour(_administrateur).toSet();
    final fermees = elementsNav
        .toSet()
        .difference(ouvertes)
        .where((e) => !e.permissions.every(_vuesPersonnelles.contains))
        // Une rubrique regroupée ailleurs n'est pas « fermée » : il la retrouve
        // sous « Soutien technique ». On l'écarte ici, et le test suivant
        // vérifie que ce regroupement lui tient bien lieu de porte.
        .where((e) => !e.masqueeSi.any(_administrateur.peut))
        .map((e) => e.libelle)
        .toList();

    expect(
      fermees,
      isEmpty,
      reason: 'rubriques fermées à l\'administrateur : $fermees',
    );
  });

  test('le soutien technique lui est regroupé en une seule rubrique', () {
    final chemins = elementsPour(_administrateur).map((e) => e.chemin).toSet();

    // La rubrique groupée est ouverte, et c'est elle qui tient lieu des trois
    // entrées séparées — désormais masquées pour lui.
    expect(chemins, contains('/logistique/soutien-technique'));
    expect(chemins, isNot(contains('/logistique/parc')));
    expect(chemins, isNot(contains('/logistique/carburant')));
    expect(chemins, isNot(contains('/logistique/armement')));

    // La garde : on ne lui masque que celles-là. Masquer une autre rubrique
    // sans la regrouper la lui fermerait sans que rien ne le signale.
    final masquees = elementsNav
        .where((e) => e.masqueeSi.any(_administrateur.peut))
        .map((e) => e.chemin)
        .toSet();
    expect(masquees, {
      '/logistique/parc',
      '/logistique/carburant',
      '/logistique/armement',
      '/scolarite/apprenants',
      '/scolarite/cours',
      '/scolarite/matieres',
      '/scolarite/bulletins',
    });
  });

  test('la scolarité lui est regroupée, sans rien perdre', () {
    final chemins = elementsPour(_administrateur).map((e) => e.chemin).toSet();

    expect(chemins, contains('/scolarite/rubrique'));
    expect(chemins, isNot(contains('/scolarite/apprenants')));
    // Ce qui ne fait pas partie du regroupement reste à sa place.
    expect(chemins, contains('/scolarite/consultations'));

    expect(ongletsScolarite(_administrateur).map((o) => o.$1), [
      'Élèves & Stagiaires',
      'Cours',
      'Matières',
      'Bulletins',
    ]);
  });

  test('il détient toute permission, hors vues personnelles', () {
    final manquantes = Permission.values
        .toSet()
        .difference(_administrateur.permissions)
        .difference(_vuesPersonnelles);

    expect(manquantes, isEmpty, reason: 'permissions manquantes : $manquantes');
  });

  test('il ouvre un compte pour tout poste, le sien compris', () {
    final sousSonAutorite = postesCreables[Poste.administrateur] ?? {};

    // Créer un administrateur est le propre du super administrateur : sans
    // cela, l'école ne pourrait pas se donner un second commandant.
    expect(sousSonAutorite, contains(Poste.administrateur));

    // Aucun poste ne lui est fermé, pas même ceux que le chef du soutien
    // technique arme habituellement. La délégation à ce dernier n'est pas une
    // exclusivité : l'école est restée des semaines sans armurier parce que
    // lui seul pouvait en nommer un.
    //
    // Le compte d'un élève fait exception : il s'ouvre depuis « Espaces
    // élèves », par un autre chemin et à partir de sa fiche d'apprenant.
    final horsDeSaMain = Poste.values
        .toSet()
        .difference(sousSonAutorite)
        .difference({Poste.eleveStagiaire});

    expect(
      horsDeSaMain,
      isEmpty,
      reason: "postes qu'il ne peut pas ouvrir : $horsDeSaMain",
    );

    // La délégation au chef du soutien technique subsiste : il arme ses trois
    // services sans passer par l'administrateur.
    expect(
      postesCreables[Poste.chefSoutienTechnique],
      containsAll({Poste.soutienPetrolier, Poste.garage, Poste.armurerie}),
    );
  });
}
