/// Ce qu'une fiche décrit.
///
/// `personnel` est venu avec la Division de Commandement et Logistique :
/// elle n'instruit personne, elle regroupe le personnel de l'école. Ce
/// personnel reçoit la même fiche que les élèves — la prise d'armes du
/// matin compte toute l'école, et une permission se tient de la même façon
/// pour un adjudant que pour un élève —, mais il n'est pas en formation :
/// ni promotion, ni phase, ni section, ni note. La base le fait respecter.
enum ApprenantType { eleve, stagiaire, personnel }

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
    ApprenantType.personnel => 'Personnel',
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
    this.promotionId,
    this.sectionId,
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
  /// La phase qu'il suit aujourd'hui. Nulle pour le personnel.
  final String? classeId;

  /// La promotion où il est inscrit — c'est elle qui le rattache à l'école,
  /// et elle ne change pas d'une phase à l'autre (migration 065). Nulle
  /// pour un stagiaire comme pour le personnel.
  final String? promotionId;

  /// La section de sa promotion. Nulle tant que la répartition n'est pas
  /// faite — et nulle à jamais pour un stagiaire ou le personnel.
  final String? sectionId;

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
      promotionId: json['promotion_id'] as String?,
      sectionId: json['section_id'] as String?,
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
