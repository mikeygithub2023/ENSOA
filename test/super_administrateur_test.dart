// L'administrateur commande l'école : aucune rubrique ne lui est fermée.
//
// Ce test existe parce que la liste de ses droits, tenue à la main, l'avait
// laissé sans accès aux consultations ni aux visites médicales — sans que
// rien ne le signale. Il échouera désormais si une rubrique nouvelle oublie
// de s'ouvrir à lui.
import 'package:flutter_test/flutter_test.dart';

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
        .map((e) => e.libelle)
        .toList();

    expect(
      fermees,
      isEmpty,
      reason: 'rubriques fermées à l\'administrateur : $fermees',
    );
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

    // Les postes de service relèvent du chef du soutien technique ; ils lui
    // restent fermés à dessein, et c'est la seule exception.
    final deleguesAuChefST = postesCreables[Poste.chefSoutienTechnique] ?? {};
    final jamaisCreables = Poste.values
        .toSet()
        .difference(sousSonAutorite)
        .difference(deleguesAuChefST)
        .difference({Poste.eleveStagiaire});

    expect(
      jamaisCreables,
      isEmpty,
      reason: 'postes que personne ne peut ouvrir : $jamaisCreables',
    );
  });
}
