import 'roles.dart';

/// Le poste qu'occupe un agent — ce qu'on dirait de lui à l'école, et ce que
/// choisit celui qui lui ouvre un compte.
///
/// La base, elle, connaît deux familles de rôles séparées (scolarité et
/// soutien technique), parce que la centaine de politiques RLS reprises des
/// deux applications les interroge séparément. Le poste fait le pont : il dit
/// quel(s) rôle(s) poser, et évite qu'on ait à y penser à chaque création de
/// compte.
///
/// Deux postes portent les deux rôles à la fois :
///
///   - l'infirmerie est UNE seule infirmerie. Elle soigne les élèves
///     (consultations, visites médicales, pharmacie) et relève du soutien
///     technique pour ses tâches de service. Deux rôles, un seul poste.
///   - l'administrateur administre l'école entière, pas la moitié.
enum Poste {
  administrateur,
  chefDivision,
  commandantBrigade,
  instructeur,
  infirmerie,
  eleveStagiaire,
  chefSoutienTechnique,
  soutienPetrolier,
  garage,
  armurerie,
  postePolice,
  officierAdjoint,
}

/// Les rôles que pose chaque poste. Un `null` d'un côté veut dire que le
/// poste ne relève pas de ce module — et la RLS ne lui accorde alors rien.
const rolesDuPoste = <Poste, (RoleScolarite?, RoleLogistique?)>{
  Poste.administrateur: (RoleScolarite.admin, RoleLogistique.administrateur),
  Poste.chefDivision: (RoleScolarite.chefDivision, null),
  Poste.commandantBrigade: (RoleScolarite.commandantBrigade, null),
  Poste.instructeur: (RoleScolarite.instructeur, null),
  Poste.infirmerie: (RoleScolarite.medecin, RoleLogistique.sante),
  Poste.eleveStagiaire: (RoleScolarite.eleveStagiaire, null),
  Poste.chefSoutienTechnique: (null, RoleLogistique.chefSoutienTechnique),
  Poste.soutienPetrolier: (null, RoleLogistique.soutienPetrolier),
  Poste.garage: (null, RoleLogistique.garage),
  Poste.armurerie: (null, RoleLogistique.armurerie),
  Poste.postePolice: (null, RoleLogistique.postePolice),
  Poste.officierAdjoint: (null, RoleLogistique.officierAdjoint),
};

extension PosteLibelle on Poste {
  String get libelle => switch (this) {
    Poste.administrateur => 'Administrateur',
    Poste.chefDivision => 'Chef de division',
    Poste.commandantBrigade => 'Commandant de Brigade',
    Poste.instructeur => 'Instructeur',
    Poste.infirmerie => 'Infirmerie',
    Poste.eleveStagiaire => 'Élève / Stagiaire',
    Poste.chefSoutienTechnique => 'Chef Soutien Technique',
    Poste.soutienPetrolier => 'Soutien pétrolier',
    Poste.garage => 'Garage',
    Poste.armurerie => 'Armurerie',
    Poste.postePolice => 'Poste de Police',
    Poste.officierAdjoint => 'Officier Adjoint',
  };

  RoleScolarite? get roleScolarite => rolesDuPoste[this]!.$1;
  RoleLogistique? get roleLogistique => rolesDuPoste[this]!.$2;

  Set<Permission> get permissions =>
      permissionsDe(scolarite: roleScolarite, logistique: roleLogistique);
}

/// Retrouve le poste d'un profil à partir de ses deux rôles. Sert à afficher
/// « Infirmerie » plutôt que « Médecin + Service Santé ».
Poste? posteDepuisRoles(RoleScolarite? scolarite, RoleLogistique? logistique) {
  for (final e in rolesDuPoste.entries) {
    if (e.value.$1 == scolarite && e.value.$2 == logistique) return e.key;
  }
  return null;
}

/// Qui ouvre un compte pour qui, exprimé en postes — la chaîne de
/// commandement plutôt qu'un pouvoir unique : l'administrateur nomme les
/// chefs, et le chef du Soutien Technique arme lui-même son service, parce
/// qu'il sait qui tient le dépôt de carburant.
///
/// Un poste absent de cette table n'ouvre aucun compte. Elle est aussi
/// appliquée côté serveur par l'Edge Function de création : la liste
/// déroulante n'est qu'une commodité, elle ne protège rien.
const postesCreables = <Poste, Set<Poste>>{
  Poste.administrateur: {
    Poste.administrateur,
    Poste.chefDivision,
    Poste.commandantBrigade,
    Poste.instructeur,
    Poste.infirmerie,
    Poste.chefSoutienTechnique,
    Poste.postePolice,
    Poste.officierAdjoint,
  },
  Poste.chefSoutienTechnique: {
    Poste.soutienPetrolier,
    Poste.garage,
    Poste.armurerie,
  },
};
