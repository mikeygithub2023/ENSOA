/// PERSONNEL — fiche du militaire (distinct d'UTILISATEUR, qui est un compte
/// applicatif). Un DISTRIBUTION.IDPERSONNEL référence cette table : le
/// bénéficiaire de carburant n'a pas forcément de compte dans l'app.
class Personnel {
  final String id; // IDPERSONNEL
  final String nom; // NOM_PERSONNEL
  final String prenom; // PRENOM_PERSONNEL
  /// Le grade tel qu'on l'écrit — Sergent, Adjudant-chef… Nul pour le
  /// personnel civil, qui n'en a pas.
  final String? grade;
  final String matricule; // MATRICULE
  final String? contact; // CONTACT
  final String? mecano; // MECANO
  final String statutActuel; // STATUT_ACTUEL

  const Personnel({
    required this.id,
    required this.nom,
    required this.prenom,
    this.grade,
    required this.matricule,
    this.contact,
    this.mecano,
    required this.statutActuel,
  });

  String get nomComplet => '$prenom $nom';
}
