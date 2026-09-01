enum PermissionStatut { aVenir, enCours, terminee }

extension PermissionStatutLabel on PermissionStatut {
  String get label => switch (this) {
    PermissionStatut.aVenir => 'À venir',
    PermissionStatut.enCours => 'En cours',
    PermissionStatut.terminee => 'Terminée',
  };
}

/// Permission (autorisation de sortie) accordée à un élève/stagiaire.
class Permission {
  const Permission({
    required this.id,
    required this.apprenantId,
    required this.divisionId,
    required this.classeId,
    required this.dateDepart,
    required this.dateRetour,
    this.localite,
    this.motif,
    this.personneContact,
  });

  final String id;
  final String apprenantId;
  final String divisionId;
  final String classeId;
  final DateTime dateDepart;
  final DateTime dateRetour;
  final String? localite;
  final String? motif;
  final String? personneContact;

  /// Statut dérivé des dates par rapport à aujourd'hui (rien n'est stocké
  /// en base : une permission "en cours" hier devient "terminée" toute
  /// seule au jour suivant).
  PermissionStatut get statut {
    final today = DateTime.now();
    final day = DateTime(today.year, today.month, today.day);
    if (day.isBefore(dateDepart)) return PermissionStatut.aVenir;
    if (day.isAfter(dateRetour)) return PermissionStatut.terminee;
    return PermissionStatut.enCours;
  }

  factory Permission.fromJson(Map<String, dynamic> json) {
    return Permission(
      id: json['id'] as String,
      apprenantId: json['apprenant_id'] as String,
      divisionId: json['division_id'] as String,
      classeId: json['classe_id'] as String,
      dateDepart: DateTime.parse(json['date_depart'] as String),
      dateRetour: DateTime.parse(json['date_retour'] as String),
      localite: json['localite'] as String?,
      motif: json['motif'] as String?,
      personneContact: json['personne_contact'] as String?,
    );
  }
}
