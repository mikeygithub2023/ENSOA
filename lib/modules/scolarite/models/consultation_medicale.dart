enum ConsultationType { routine, urgence }

ConsultationType consultationTypeFromString(String value) {
  return value == 'urgence'
      ? ConsultationType.urgence
      : ConsultationType.routine;
}

extension ConsultationTypeLabel on ConsultationType {
  String get label => switch (this) {
    ConsultationType.routine => 'Routine',
    ConsultationType.urgence => 'Urgence',
  };

  String get value => switch (this) {
    ConsultationType.routine => 'routine',
    ConsultationType.urgence => 'urgence',
  };
}

/// Grand groupe clinique dont relève la pathologie constatée — liste
/// fermée, comme la classe pharmacologique d'un médicament : c'est elle qui
/// rend le volet santé exploitable en statistiques, qu'un champ libre
/// fragmenterait à la moindre variante d'orthographe. Le diagnostic précis
/// se saisit à côté, en clair.
enum Pathologie {
  paludisme,
  infectionRespiratoire,
  troubleDigestif,
  traumatologie,
  dermatologie,
  dentaire,
  ophtalmologie,
  fievreTyphoide,
  cephalees,
  uroGenital,
  allergie,
  pathologieChronique,
  autre,
}

const _pathologieDbValues = {
  Pathologie.paludisme: 'paludisme',
  Pathologie.infectionRespiratoire: 'infection_respiratoire',
  Pathologie.troubleDigestif: 'trouble_digestif',
  Pathologie.traumatologie: 'traumatologie',
  Pathologie.dermatologie: 'dermatologie',
  Pathologie.dentaire: 'dentaire',
  Pathologie.ophtalmologie: 'ophtalmologie',
  Pathologie.fievreTyphoide: 'fievre_typhoide',
  Pathologie.cephalees: 'cephalees',
  Pathologie.uroGenital: 'uro_genital',
  Pathologie.allergie: 'allergie',
  Pathologie.pathologieChronique: 'pathologie_chronique',
  Pathologie.autre: 'autre',
};

Pathologie? pathologieFromString(String? value) {
  if (value == null) return null;
  for (final entry in _pathologieDbValues.entries) {
    if (entry.value == value) return entry.key;
  }
  return Pathologie.autre;
}

extension PathologieValue on Pathologie {
  String get value => _pathologieDbValues[this]!;

  String get label => switch (this) {
    Pathologie.paludisme => 'Paludisme',
    Pathologie.infectionRespiratoire => 'Infection respiratoire / ORL',
    Pathologie.troubleDigestif => 'Troubles digestifs',
    Pathologie.traumatologie => 'Traumatologie / lésion de l\'effort',
    Pathologie.dermatologie => 'Affection dermatologique',
    Pathologie.dentaire => 'Affection dentaire',
    Pathologie.ophtalmologie => 'Affection ophtalmologique',
    Pathologie.fievreTyphoide => 'Fièvre typhoïde',
    Pathologie.cephalees => 'Céphalées',
    Pathologie.uroGenital => 'Affection uro-génitale',
    Pathologie.allergie => 'Allergie',
    Pathologie.pathologieChronique => 'Pathologie chronique',
    Pathologie.autre => 'Autre',
  };
}

enum ConsultationStatut { enAttente, enCours, terminee }

ConsultationStatut consultationStatutFromString(String value) {
  return switch (value) {
    'en_cours' => ConsultationStatut.enCours,
    'terminee' => ConsultationStatut.terminee,
    _ => ConsultationStatut.enAttente,
  };
}

extension ConsultationStatutValue on ConsultationStatut {
  String get label => switch (this) {
    ConsultationStatut.enAttente => 'En attente',
    ConsultationStatut.enCours => 'En cours',
    ConsultationStatut.terminee => 'Terminée',
  };

  String get value => switch (this) {
    ConsultationStatut.enAttente => 'en_attente',
    ConsultationStatut.enCours => 'en_cours',
    ConsultationStatut.terminee => 'terminee',
  };
}

/// Une consultation de [ConsultationType.routine] démarre par l'autorisation
/// d'un élève/stagiaire à consulter le médecin : tant qu'elle n'existe pas,
/// le médecin ne peut pas effectuer cette consultation-là. Une consultation
/// [ConsultationType.urgence] ne nécessite aucune autorisation préalable —
/// le médecin la crée directement et peut la clore dans la foulée.
/// [examensDemandes] est un texte libre décrivant les examens à faire suite
/// à la consultation ; les médicaments prescrits sont dans une table à part
/// (voir `OrdonnanceLigne`), reliée par [id].
class ConsultationMedicale {
  const ConsultationMedicale({
    required this.id,
    required this.apprenantId,
    required this.divisionId,
    required this.classeId,
    required this.dateSouhaitee,
    required this.type,
    required this.statut,
    required this.exemption,
    required this.hospitalisationInterne,
    required this.hospitalisationExterne,
    this.pathologie,
    this.pathologieDetails,
    this.joursRepos,
    this.examensDemandes,
    this.exemptionDetails,
    this.hospitalisationInterneLieu,
    this.hospitalisationExterneLieu,
  });

  final String id;
  final String apprenantId;
  final String divisionId;
  final String classeId;
  final DateTime dateSouhaitee;
  final ConsultationType type;
  final ConsultationStatut statut;
  final Pathologie? pathologie;
  final String? pathologieDetails;
  final int? joursRepos;
  final bool exemption;
  final bool hospitalisationInterne;
  final bool hospitalisationExterne;
  final String? examensDemandes;
  final String? exemptionDetails;
  final String? hospitalisationInterneLieu;
  final String? hospitalisationExterneLieu;

  factory ConsultationMedicale.fromJson(Map<String, dynamic> json) {
    return ConsultationMedicale(
      id: json['id'] as String,
      apprenantId: json['apprenant_id'] as String,
      divisionId: json['division_id'] as String,
      classeId: json['classe_id'] as String,
      dateSouhaitee: DateTime.parse(json['date_souhaitee'] as String),
      type: consultationTypeFromString(json['type'] as String? ?? 'routine'),
      statut: consultationStatutFromString(
        json['statut'] as String? ?? 'en_attente',
      ),
      pathologie: pathologieFromString(json['pathologie'] as String?),
      pathologieDetails: json['pathologie_details'] as String?,
      joursRepos: json['jours_repos'] as int?,
      exemption: json['exemption'] as bool? ?? false,
      hospitalisationInterne: json['hospitalisation_interne'] as bool? ?? false,
      hospitalisationExterne: json['hospitalisation_externe'] as bool? ?? false,
      examensDemandes: json['examens_demandes'] as String?,
      exemptionDetails: json['exemption_details'] as String?,
      hospitalisationInterneLieu:
          json['hospitalisation_interne_lieu'] as String?,
      hospitalisationExterneLieu:
          json['hospitalisation_externe_lieu'] as String?,
    );
  }
}
