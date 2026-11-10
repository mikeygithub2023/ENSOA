enum ApprenantType { eleve, stagiaire }

ApprenantType apprenantTypeFromString(String value) {
  return ApprenantType.values.firstWhere(
    (t) => t.name == value,
    orElse: () => ApprenantType.eleve,
  );
}

extension ApprenantTypeLabel on ApprenantType {
  String get label => switch (this) {
    ApprenantType.eleve => 'Élève',
    ApprenantType.stagiaire => 'Stagiaire',
  };
}

enum ApprenantStatut { actif, radie, diplome, suspendu }

ApprenantStatut apprenantStatutFromString(String value) {
  return ApprenantStatut.values.firstWhere(
    (s) => s.name == value,
    orElse: () => ApprenantStatut.actif,
  );
}

extension ApprenantStatutLabel on ApprenantStatut {
  String get label => switch (this) {
    ApprenantStatut.actif => 'Actif',
    ApprenantStatut.radie => 'Radié',
    ApprenantStatut.diplome => 'Diplômé',
    ApprenantStatut.suspendu => 'Suspendu',
  };
}

/// Fiche signalétique complète d'un élève/stagiaire (DFS) : identité de
/// base + affectation, plus toutes les rubriques facultatives saisies à
/// l'enregistrement (filiation, contact d'urgence, données médicales,
/// formation civile, photo).
class Apprenant {
  const Apprenant({
    required this.id,
    required this.divisionId,
    required this.type,
    required this.nom,
    required this.prenom,
    required this.statut,
    this.profileId,
    this.classeId,
    this.matricule,
    this.grade,
    this.sexe,
    this.telephone,
    this.ethnie,
    this.dateNaissance,
    this.lieuNaissance,
    this.situationMatrimoniale,
    this.nombreEnfants,
    this.nomPere,
    this.nomMere,
    this.contact,
    this.email,
    this.urgenceNom,
    this.urgenceLien,
    this.urgenceContact,
    this.tailleCm,
    this.poidsKg,
    this.groupeSanguin,
    this.qualification,
    this.permisConduire,
    this.photoPath,
    this.deletionRequestedAt,
    this.deletionRequestedBy,
  });

  final String id;
  final String divisionId;
  final String? profileId;
  final ApprenantType type;
  final String? matricule;
  final String nom;
  final String prenom;
  final String? classeId;
  final ApprenantStatut statut;

  final String? grade;

  /// « M » ou « F », nul tant que la fiche ne le précise pas. C'est lui
  /// qui décide du barème appliqué aux épreuves sportives (migration 052) :
  /// sans lui, la performance reste sans note.
  final String? sexe;

  final String? telephone;
  final String? ethnie;
  final DateTime? dateNaissance;
  final String? lieuNaissance;
  final String? situationMatrimoniale;
  final int? nombreEnfants;
  final String? nomPere;
  final String? nomMere;
  final String? contact;
  final String? email;
  final String? urgenceNom;
  final String? urgenceLien;
  final String? urgenceContact;
  final num? tailleCm;
  final num? poidsKg;
  final String? groupeSanguin;
  final String? qualification;
  final String? permisConduire;
  final String? photoPath;
  final DateTime? deletionRequestedAt;
  final String? deletionRequestedBy;

  /// Le nom d'usage militaire : le NOM d'abord, le prénom ensuite.
  ///
  /// C'est ainsi qu'on appelle quelqu'un au rapport, ainsi qu'il se présente,
  /// et ainsi que les listes de l'école sont tenues — un effectif se lit par
  /// ordre alphabétique de nom. L'écrire dans l'autre sens obligeait à
  /// chercher le patronyme au milieu de trois ou quatre prénoms.
  String get nomComplet => '$nom $prenom'.trim();
  bool get suppressionDemandee => deletionRequestedAt != null;

  factory Apprenant.fromJson(Map<String, dynamic> json) {
    return Apprenant(
      id: json['id'] as String,
      divisionId: json['division_id'] as String,
      profileId: json['profile_id'] as String?,
      type: apprenantTypeFromString(json['type'] as String? ?? 'eleve'),
      matricule: json['matricule'] as String?,
      nom: json['nom'] as String? ?? '',
      prenom: json['prenom'] as String? ?? '',
      classeId: json['classe_id'] as String?,
      statut: apprenantStatutFromString(json['statut'] as String? ?? 'actif'),
      grade: json['grade'] as String?,
      sexe: json['sexe'] as String?,
      telephone: json['telephone'] as String?,
      ethnie: json['ethnie'] as String?,
      dateNaissance: json['date_naissance'] == null
          ? null
          : DateTime.tryParse(json['date_naissance'] as String),
      lieuNaissance: json['lieu_naissance'] as String?,
      situationMatrimoniale: json['situation_matrimoniale'] as String?,
      nombreEnfants: json['nombre_enfants'] as int?,
      nomPere: json['nom_pere'] as String?,
      nomMere: json['nom_mere'] as String?,
      contact: json['contact'] as String?,
      email: json['email'] as String?,
      urgenceNom: json['urgence_nom'] as String?,
      urgenceLien: json['urgence_lien'] as String?,
      urgenceContact: json['urgence_contact'] as String?,
      tailleCm: json['taille_cm'] as num?,
      poidsKg: json['poids_kg'] as num?,
      groupeSanguin: json['groupe_sanguin'] as String?,
      qualification: json['qualification'] as String?,
      permisConduire: json['permis_conduire'] as String?,
      photoPath: json['photo_path'] as String?,
      deletionRequestedAt: json['deletion_requested_at'] == null
          ? null
          : DateTime.parse(json['deletion_requested_at'] as String),
      deletionRequestedBy: json['deletion_requested_by'] as String?,
    );
  }
}
