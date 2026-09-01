/// Une phase appartient à une promotion ; un stage relève directement de sa
/// division. C'est la seule différence de structure entre les deux, et elle
/// se lit dans [Classe.promotionId].
enum ClasseType { phase, stage }

ClasseType classeTypeFromString(String value) {
  return ClasseType.values.firstWhere(
    (t) => t.name == value,
    orElse: () => ClasseType.phase,
  );
}

extension ClasseTypeLabel on ClasseType {
  String get label => switch (this) {
    ClasseType.phase => 'Phase',
    ClasseType.stage => 'Stage',
  };
}

/// Classe (contient des élèves) ou stage (contient des stagiaires), propre
/// à une division — ex. FCB, ESOA1, ESOA2, BA1, BA2.
class Classe {
  const Classe({
    required this.id,
    required this.divisionId,
    required this.type,
    required this.nom,
    this.promotionId,
    this.ordre = 0,
    this.coefficient = 1,
    this.clotureeLe,
  });

  final String id;
  final String divisionId;
  final ClasseType type;
  final String nom;

  /// Renseigné pour une phase, nul pour un stage — la base fait respecter
  /// cette règle.
  final String? promotionId;

  /// Rang de la phase dans le cursus de sa promotion. Les phases se
  /// suivent : c'est lui qui dit laquelle vient après.
  final int ordre;

  /// Poids de la phase dans la moyenne générale de sa promotion. Propre à
  /// chaque promotion : chacune a ses propres phases, donc son propre barème.
  /// Sans objet pour un stage, qui ne se compose pas de phases.
  final num coefficient;

  /// Date de clôture, nulle tant que la phase est ouverte. Une phase close
  /// est figée — plus aucune saisie n'y est possible — et ses élèves sont
  /// passés à la suivante (migration 066).
  final DateTime? clotureeLe;

  bool get estCloturee => clotureeLe != null;

  factory Classe.fromJson(Map<String, dynamic> json) {
    return Classe(
      id: json['id'] as String,
      divisionId: json['division_id'] as String,
      type: classeTypeFromString(json['type'] as String? ?? 'phase'),
      nom: json['nom'] as String,
      promotionId: json['promotion_id'] as String?,
      ordre: json['ordre'] as int? ?? 0,
      coefficient: (json['coefficient'] as num?) ?? 1,
      clotureeLe: json['cloturee_le'] == null
          ? null
          : DateTime.parse(json['cloturee_le'] as String),
    );
  }
}
