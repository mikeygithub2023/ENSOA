/// Les rôles de l'école, dans les deux familles que la fusion réunit.
///
/// Un profil porte les deux, chacune facultative : un adjudant peut être
/// instructeur ET tenir l'armurerie. Un rôle nul veut dire « ne relève pas de
/// ce module » — et les politiques RLS, côté serveur, n'accordent alors rien.
///
/// Les deux énumérations sont le reflet exact des types `socle.app_role` et
/// `socle.user_role` en base. Elles restent séparées parce que la centaine de
/// politiques RLS reprises des deux applications les interroge séparément.
library;

// --- Scolarité ---------------------------------------------------------------

enum RoleScolarite {
  admin,
  chefDivision,
  commandantPromotion,
  commandantBrigade,
  eleveStagiaire,
  medecin,
}

const _valeursScolarite = {
  RoleScolarite.admin: 'admin',
  RoleScolarite.chefDivision: 'chef_division',
  RoleScolarite.commandantPromotion: 'commandant_promotion',
  RoleScolarite.commandantBrigade: 'commandant_brigade',
  RoleScolarite.eleveStagiaire: 'eleve_stagiaire',
  RoleScolarite.medecin: 'medecin',
};

extension RoleScolariteDb on RoleScolarite {
  String get valeurDb => _valeursScolarite[this]!;

  String get libelle => switch (this) {
    RoleScolarite.admin => 'Administrateur scolarité',
    RoleScolarite.chefDivision => 'Commandant de division',
    RoleScolarite.commandantPromotion => 'Commandant de promotion',
    RoleScolarite.commandantBrigade => 'Commandant de brigade',
    RoleScolarite.eleveStagiaire => 'Élève / Stagiaire',
    RoleScolarite.medecin => 'Médecin',
  };
}

RoleScolarite? roleScolariteDepuisDb(String? valeur) {
  if (valeur == null) return null;
  for (final e in _valeursScolarite.entries) {
    if (e.value == valeur) return e.key;
  }
  return null;
}

// --- Soutien technique -------------------------------------------------------

enum RoleLogistique {
  chefSoutienTechnique,
  soutienPetrolier,
  garage,
  armurerie,
  postePolice,
  officierAdjoint,
  sante,
  administrateur,
}

const _valeursLogistique = {
  RoleLogistique.chefSoutienTechnique: 'chef_soutien_technique',
  RoleLogistique.soutienPetrolier: 'soutien_petrolier',
  RoleLogistique.garage: 'garage',
  RoleLogistique.armurerie: 'armurerie',
  RoleLogistique.postePolice: 'poste_police',
  RoleLogistique.officierAdjoint: 'officier_adjoint',
  RoleLogistique.sante: 'sante',
  RoleLogistique.administrateur: 'administrateur',
};

extension RoleLogistiqueDb on RoleLogistique {
  String get valeurDb => _valeursLogistique[this]!;

  String get libelle => switch (this) {
    RoleLogistique.chefSoutienTechnique => 'Chef Soutien Technique',
    RoleLogistique.soutienPetrolier => 'Soutien pétrolier',
    RoleLogistique.garage => 'Garage',
    RoleLogistique.armurerie => 'Armurerie',
    RoleLogistique.postePolice => 'Poste de Police',
    RoleLogistique.officierAdjoint => 'Officier Adjoint',
    RoleLogistique.sante => 'Service Santé',
    RoleLogistique.administrateur => 'Administrateur plateforme',
  };
}

RoleLogistique? roleLogistiqueDepuisDb(String? valeur) {
  if (valeur == null) return null;
  for (final e in _valeursLogistique.entries) {
    if (e.value == valeur) return e.key;
  }
  return null;
}

// --- Permissions -------------------------------------------------------------

/// Ce qu'un poste a le droit de faire. Un profil cumule les permissions de
/// ses deux rôles : c'est ce cumul qui fait de l'ensemble un seul ERP plutôt
/// que deux applications partageant une base.
///
/// La navigation et les écrans se règlent là-dessus, jamais sur le rôle
/// directement : ajouter un rôle ne doit pas obliger à rouvrir chaque écran.
enum Permission {
  // Scolarité
  voirTableauBordScolarite,
  consulterApprenants,
  gererApprenants,
  gererCours,
  suivreCours,
  gererMatieres,
  editerBulletins,
  gererConsultations,
  gererVisitesMedicales,
  gererPharmacie,
  gererDepensesSante,
  voirSonEspaceEleve,
  administrerScolarite,

  // Soutien technique
  voirTableauBordLogistique,
  gererParc,
  gererMaintenance,
  gererCarburant,
  validerDistribution,
  gererArmement,
  validerDotationArme,
  gererPostePolice,
  gererActivites,
  voirMesTaches,
  voirTachesEquipe,

  // Commun
  voirJournalAudit,
  gererUtilisateurs,
  administrerPlateforme,
}

const _permissionsScolarite = <RoleScolarite, Set<Permission>>{
  RoleScolarite.admin: {
    Permission.voirTableauBordScolarite,
    Permission.consulterApprenants,
    Permission.gererApprenants,
    Permission.gererCours,
    Permission.gererMatieres,
    Permission.editerBulletins,
    Permission.gererPharmacie,
    Permission.gererDepensesSante,
    Permission.administrerScolarite,
    Permission.gererUtilisateurs,
    Permission.voirJournalAudit,
  },
  RoleScolarite.chefDivision: {
    Permission.voirTableauBordScolarite,
    Permission.consulterApprenants,
    Permission.gererApprenants,
    Permission.gererCours,
    Permission.gererMatieres,
  },
  // Les deux commandants d'une promotion ouvrent les mêmes écrans : la RLS
  // les borne l'un et l'autre aux phases de leur promotion. Ce qui les
  // distingue ne se voit pas ici mais en base — le Commandant de Brigade ne
  // saisit que les notes du module Sport, celui de Promotion les saisit
  // toutes. Une permission de plus ne changerait rien à cette limite, qui
  // porte sur des lignes et non sur des écrans.
  RoleScolarite.commandantPromotion: {
    Permission.voirTableauBordScolarite,
    Permission.consulterApprenants,
    Permission.gererCours,
    Permission.gererMatieres,
  },
  RoleScolarite.commandantBrigade: {
    Permission.voirTableauBordScolarite,
    Permission.consulterApprenants,
    Permission.gererCours,
    Permission.gererMatieres,
  },
  RoleScolarite.eleveStagiaire: {
    Permission.voirTableauBordScolarite,
    Permission.suivreCours,
    Permission.voirSonEspaceEleve,
  },
  RoleScolarite.medecin: {
    Permission.voirTableauBordScolarite,
    Permission.gererConsultations,
    Permission.gererVisitesMedicales,
    Permission.gererPharmacie,
    Permission.gererDepensesSante,
  },
};

const _permissionsLogistique = <RoleLogistique, Set<Permission>>{
  RoleLogistique.chefSoutienTechnique: {
    Permission.voirTableauBordLogistique,
    Permission.gererParc,
    Permission.gererMaintenance,
    Permission.gererCarburant,
    Permission.validerDistribution,
    Permission.gererArmement,
    Permission.validerDotationArme,
    Permission.gererUtilisateurs,
    Permission.voirTachesEquipe,
  },
  RoleLogistique.soutienPetrolier: {
    Permission.gererCarburant,
    Permission.validerDistribution,
    Permission.voirMesTaches,
  },
  RoleLogistique.garage: {
    Permission.gererParc,
    Permission.gererMaintenance,
    Permission.voirMesTaches,
  },
  RoleLogistique.armurerie: {
    Permission.gererArmement,
    Permission.validerDotationArme,
    Permission.voirMesTaches,
  },
  RoleLogistique.postePolice: {Permission.gererPostePolice},
  RoleLogistique.officierAdjoint: {Permission.gererActivites},
  RoleLogistique.sante: {Permission.voirMesTaches},
  // L'administrateur voit tout le soutien technique et les activités de
  // l'officier adjoint : ses rubriques figurent dans le menu comme celles
  // d'un chef de service.
  //
  // ⚠ C'est une vue, pas une main. La RLS ne lui accorde que la lecture sur
  // ces domaines (migration 018b, « lecture transversale ») : les écrans
  // s'ouvrent et affichent, mais un enregistrement serait refusé par le
  // serveur. Lui donner la main demanderait d'ajouter des politiques
  // d'écriture — décision d'organisation, pas de code.
  RoleLogistique.administrateur: {
    Permission.administrerPlateforme,
    Permission.voirJournalAudit,
    Permission.gererUtilisateurs,
    Permission.voirTableauBordLogistique,
    Permission.gererParc,
    Permission.gererMaintenance,
    Permission.gererCarburant,
    Permission.gererArmement,
    Permission.gererPostePolice,
    Permission.gererActivites,
    Permission.voirTachesEquipe,
  },
};

/// Les permissions d'un profil : l'union de ses deux rôles.
Set<Permission> permissionsDe({
  RoleScolarite? scolarite,
  RoleLogistique? logistique,
}) => {
  if (scolarite != null) ..._permissionsScolarite[scolarite]!,
  if (logistique != null) ..._permissionsLogistique[logistique]!,
};

// Qui ouvre un compte pour qui ne s'exprime pas ici mais dans `postes.dart` :
// on nomme quelqu'un à un poste, pas à un rôle de module. Une seule table,
// une seule vérité.
