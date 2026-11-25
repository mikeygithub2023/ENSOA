/// Les décorations : celles que décerne le Chef d'État-Major, et ce que
/// chacun porte.
///
/// [TypeDecoration] est la nomenclature — les décorations en usage, tenues
/// par l'administrateur. [DecorationRecue] est une attribution : telle
/// décoration, à telle date, par tel texte.
///
/// La même décoration peut revenir : citations successives, échelons,
/// agrafes. Une attribution n'est donc pas identifiée par la décoration
/// seule, mais par la décoration et sa date.
library;

/// Une décoration du catalogue : l'une de celles que décerne le Chef
/// d'État-Major.
///
/// Nommée `TypeDecoration` et non `Decoration` : Flutter porte déjà une
/// classe `Decoration` (celle dont `BoxDecoration` hérite), et tout écran
/// qui importerait les deux ne saurait plus de laquelle on parle.
class TypeDecoration {
  const TypeDecoration({
    required this.id,
    required this.libelle,
    required this.ordre,
    required this.active,
  });

  final String id;
  final String libelle;

  /// L'ordre de préséance, qui n'est ni alphabétique ni chronologique.
  final int ordre;

  final bool active;

  factory TypeDecoration.fromJson(Map<String, dynamic> json) => TypeDecoration(
    id: json['id'] as String,
    libelle: json['libelle'] as String,
    ordre: (json['ordre'] as num?)?.toInt() ?? 0,
    active: json['active'] as bool? ?? true,
  );
}

/// Une décoration reçue par un militaire.
class DecorationRecue {
  const DecorationRecue({
    required this.id,
    required this.apprenantId,
    required this.decorationId,
    this.dateAttribution,
    this.reference,
    this.echelon,
    this.observation,
  });

  final String id;
  final String apprenantId;
  final String decorationId;

  /// Facultative : une médaille portée depuis des années dont la date ne se
  /// retrouve pas vaut mieux qu'une ligne qu'on n'a pas pu saisir.
  final DateTime? dateAttribution;

  /// La décision du Chef d'État-Major qui la décerne.
  final String? reference;

  /// Échelon, agrafe, palme — ce qui distingue deux attributions de la
  /// même décoration.
  final String? echelon;

  final String? observation;

  factory DecorationRecue.fromJson(Map<String, dynamic> json) =>
      DecorationRecue(
        id: json['id'] as String,
        apprenantId: json['apprenant_id'] as String,
        decorationId: json['decoration_id'] as String,
        dateAttribution: json['date_attribution'] == null
            ? null
            : DateTime.parse(json['date_attribution'] as String),
        reference: json['reference'] as String?,
        echelon: json['echelon'] as String?,
        observation: json['observation'] as String?,
      );
}
