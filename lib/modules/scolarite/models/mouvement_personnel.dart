/// Les mouvements du personnel : affectation, mutation, mise à disposition,
/// reversement, retour.
///
/// Un mouvement s'écrit une fois et ne se réécrit pas : c'est un journal.
/// La base le porte sur la fiche (statut, position, service, unité) et
/// garde dans la ligne ce qui était vrai juste avant — voir la migration
/// `20261125010000_les_mouvements_du_personnel.sql`.
library;

enum NatureMouvement {
  affectation,
  mutation,
  miseADisposition,
  reversement,
  retour;

  /// La valeur en base.
  String get valeur => switch (this) {
    NatureMouvement.miseADisposition => 'mise_a_disposition',
    _ => name,
  };

  String get libelle => switch (this) {
    NatureMouvement.affectation => 'Affectation',
    NatureMouvement.mutation => 'Mutation',
    NatureMouvement.miseADisposition => 'Mise à disposition',
    NatureMouvement.reversement => 'Reversement',
    NatureMouvement.retour => 'Retour à l\'école',
  };

  /// Ce que le mouvement fait du militaire, dit à qui le saisit.
  String get explication => switch (this) {
    NatureMouvement.affectation =>
      'Il rejoint l\'école ou y est affecté à un service. Il compte dans '
          'l\'effectif.',
    NatureMouvement.mutation => 'Il change de service au sein de l\'école.',
    NatureMouvement.miseADisposition =>
      'Il est prêté à une autre formation et reste des nôtres : il compte '
          'toujours dans l\'effectif.',
    NatureMouvement.reversement =>
      'Il quitte l\'école pour une autre unité. Sa fiche est gardée, mais il '
          'ne compte plus dans l\'effectif.',
    NatureMouvement.retour =>
      'Il reprend son service à l\'école après une mise à disposition ou un '
          'reversement. Il compte de nouveau dans l\'effectif.',
  };

  /// Le service où il va : exigé pour une mutation et une mise à
  /// disposition, proposé pour une affectation et un retour.
  bool get demandeService => this != NatureMouvement.reversement;
  bool get serviceObligatoire =>
      this == NatureMouvement.mutation ||
      this == NatureMouvement.miseADisposition;

  /// L'unité qui le reçoit : exigée pour un reversement seulement.
  bool get demandeUnite => this == NatureMouvement.reversement;

  static NatureMouvement depuis(String valeur) =>
      NatureMouvement.values.firstWhere(
        (n) => n.valeur == valeur,
        orElse: () => NatureMouvement.mutation,
      );
}

class MouvementPersonnel {
  const MouvementPersonnel({
    required this.id,
    required this.apprenantId,
    required this.nature,
    required this.dateEffet,
    this.serviceApres,
    this.uniteAccueil,
    this.reference,
    this.observation,
    this.serviceAvant,
    this.positionAvant,
    this.uniteAvant,
  });

  final String id;
  final String apprenantId;
  final NatureMouvement nature;
  final DateTime dateEffet;
  final String? serviceApres;
  final String? uniteAccueil;
  final String? reference;
  final String? observation;

  /// Ce qui était vrai juste avant, relevé par la base.
  final String? serviceAvant;
  final String? positionAvant;
  final String? uniteAvant;

  /// « CCAS/ENSOA → ENSOA/BRH », « ENSOA → AFA » : d'où il part, où il va.
  String? get trajet {
    final (de, vers) = switch (nature) {
      NatureMouvement.reversement => (uniteAvant, uniteAccueil),
      _ => (serviceAvant, serviceApres),
    };
    if (vers == null || vers.trim().isEmpty) return null;
    if (de == null || de.trim().isEmpty || de == vers) return vers;
    return '$de → $vers';
  }

  factory MouvementPersonnel.fromJson(Map<String, dynamic> json) =>
      MouvementPersonnel(
        id: json['id'] as String,
        apprenantId: json['apprenant_id'] as String,
        nature: NatureMouvement.depuis(json['nature'] as String),
        dateEffet: DateTime.parse(json['date_effet'] as String),
        serviceApres: json['service_apres'] as String?,
        uniteAccueil: json['unite_accueil'] as String?,
        reference: json['reference'] as String?,
        observation: json['observation'] as String?,
        serviceAvant: json['service_avant'] as String?,
        positionAvant: json['position_avant'] as String?,
        uniteAvant: json['unite_avant'] as String?,
      );
}
