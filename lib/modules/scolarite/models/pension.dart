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
    this.condition = ConditionPiece.aucune,
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

  /// À qui la pièce se demande. L'acte de mariage ne se demande qu'au
  /// militaire marié, l'acte de naissance des enfants qu'à celui qui en a :
  /// pour les autres, la pièce ne manque pas — elle n'a pas lieu d'être.
  final ConditionPiece condition;

  factory PiecePension.fromJson(Map<String, dynamic> json) => PiecePension(
    id: json['id'] as String,
    libelle: json['libelle'] as String,
    ordre: (json['ordre'] as num?)?.toInt() ?? 0,
    obligatoire: json['obligatoire'] as bool? ?? true,
    active: json['active'] as bool? ?? true,
    condition: ConditionPiece.depuis(json['condition'] as String?),
  );
}

/// La situation matrimoniale dit-elle « marié » ? Les fiches portent
/// « Marié(e) », parfois « MARIE » ou « M » à l'import.
bool estMarie(String? situationMatrimoniale) {
  final s = (situationMatrimoniale ?? '').trim().toUpperCase();
  return s == 'M' || s.startsWith('MARI');
}

/// À qui une pièce du dossier se demande.
enum ConditionPiece {
  /// À tous.
  aucune(null, null),

  /// Au militaire marié.
  marie('marie', 'Si le militaire est marié'),

  /// Au militaire qui a des enfants.
  enfants('enfants', 'Si le militaire a des enfants');

  const ConditionPiece(this.valeur, this.libelle);

  /// La valeur en base (`pieces_pension.condition`).
  final String? valeur;

  /// Ce que le catalogue affiche.
  final String? libelle;

  static ConditionPiece depuis(String? valeur) => ConditionPiece.values
      .firstWhere((c) => c.valeur == valeur, orElse: () => aucune);
}

/// Les pièces qu'on demande à ce militaire : tout le catalogue, moins celles
/// réservées aux mariés s'il ne l'est pas, et aux parents s'il n'a pas
/// d'enfant. Un nombre d'enfants inconnu ne retire rien : mieux vaut
/// demander une pièce de trop que d'en oublier une.
List<PiecePension> piecesPour(
  List<PiecePension> pieces, {
  String? situationMatrimoniale,
  int? nombreEnfants,
}) {
  final marie = estMarie(situationMatrimoniale);
  final sansEnfant = nombreEnfants == 0;
  return pieces
      .where(
        (p) => switch (p.condition) {
          ConditionPiece.aucune => true,
          ConditionPiece.marie => marie,
          ConditionPiece.enfants => !sansEnfant,
        },
      )
      .toList();
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
