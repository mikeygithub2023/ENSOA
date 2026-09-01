/// REPARATION
class Reparation {
  final String id; // IDREPARATION
  final DateTime dateEntree; // DATE_ENTREE_REPARATION
  final DateTime? dateSortie; // DATE_SORTIE_REPARATION
  final String pannesConstatees; // PANNES_CONSTATEES
  final String? solutionsApportees; // SOLUTIONS_APPORTEES
  final String? chefEquipe; // CHEF_EQUIPE
  final String? aideMecano; // AIDE_MECANO
  final String?
  lieu; // Lieu de mise en réparation (ajout hors analyse HFSQL d'origine)
  final String vehiculeId; // IDVEHICULE
  final String utilisateurId; // IDUTILISATEUR

  const Reparation({
    required this.id,
    required this.dateEntree,
    this.dateSortie,
    required this.pannesConstatees,
    this.solutionsApportees,
    this.chefEquipe,
    this.aideMecano,
    this.lieu,
    required this.vehiculeId,
    required this.utilisateurId,
  });

  bool get cloturee => dateSortie != null;
}

/// VIDANGE
class Vidange {
  final String id; // IDVIDANGE
  final DateTime date; // DATE_VIDANGE
  final String? filtreVidange; // FILTRE_VIDANGE
  final String typeHuile; // TYPE_HUILE
  final int qteHuile; // QTE_HUILE
  final String? ingredient; // INGREDIENT
  final String vehiculeId; // IDVEHICULE
  final String utilisateurId; // IDUTILISATEUR

  const Vidange({
    required this.id,
    required this.date,
    this.filtreVidange,
    required this.typeHuile,
    required this.qteHuile,
    this.ingredient,
    required this.vehiculeId,
    required this.utilisateurId,
  });
}
