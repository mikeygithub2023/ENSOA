/// Le dossier de pension : les pièces à réunir, et ce qu'on en a vérifié.
///
/// Deux objets qui ne vont pas l'un sans l'autre. [PiecePension] est une
/// nomenclature — la liste que la Direction des Ressources Humaines exige,
/// tenue par l'administrateur depuis l'écran. [LignePension] est ce qu'on a
/// constaté pour un militaire sur une de ces pièces.
///
/// Les lignes naissent à la première vérification : un dossier jamais
/// ouvert n'a aucune ligne, et non des dizaines de lignes vides. L'écran
/// présente donc le catalogue et y pose les lignes qui existent.
library;

/// Une pièce du dossier de pension, telle que la DORH la demande.
class PiecePension {
  const PiecePension({
    required this.id,
    required this.libelle,
    required this.ordre,
    required this.obligatoire,
    required this.active,
  });

  final String id;
  final String libelle;

  /// L'ordre du dossier, pas l'ordre alphabétique.
  final int ordre;

  /// Un dossier n'est complet que si toutes les pièces obligatoires y sont.
  /// Les autres sont attendues sans être exigées.
  final bool obligatoire;

  /// Une pièce qui n'est plus demandée se désactive plutôt que de
  /// disparaître : les vérifications déjà faites gardent leur objet.
  final bool active;

  factory PiecePension.fromJson(Map<String, dynamic> json) => PiecePension(
    id: json['id'] as String,
    libelle: json['libelle'] as String,
    ordre: (json['ordre'] as num?)?.toInt() ?? 0,
    obligatoire: json['obligatoire'] as bool? ?? true,
    active: json['active'] as bool? ?? true,
  );
}

/// Ce qu'on a constaté sur une pièce, pour un militaire.
class LignePension {
  const LignePension({
    required this.id,
    required this.apprenantId,
    required this.pieceId,
    required this.presente,
    this.verifieLe,
    this.verifiePar,
    this.observation,
  });

  final String id;
  final String apprenantId;
  final String pieceId;

  /// La pièce est au dossier. Une ligne qui dit `false` n'est pas une
  /// absence de vérification : c'est une vérification qui a constaté le
  /// manque — et c'est précisément ce qu'on veut lire.
  final bool presente;

  final DateTime? verifieLe;
  final String? verifiePar;
  final String? observation;

  factory LignePension.fromJson(Map<String, dynamic> json) => LignePension(
    id: json['id'] as String,
    apprenantId: json['apprenant_id'] as String,
    pieceId: json['piece_id'] as String,
    presente: json['presente'] as bool? ?? false,
    verifieLe: json['verifie_le'] == null
        ? null
        : DateTime.parse(json['verifie_le'] as String),
    verifiePar: json['verifie_par'] as String?,
    observation: json['observation'] as String?,
  );
}
