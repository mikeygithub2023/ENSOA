/// Une promotion regroupe les phases d'une division — Formation Initiale et
/// Formation des Spécialistes en ont, la Formation Continue n'en a pas :
/// elle ne contient que des stages.
class Promotion {
  const Promotion({
    required this.id,
    required this.divisionId,
    required this.nom,
    this.annee,
  });

  final String id;
  final String divisionId;
  final String nom;

  /// Année d'incorporation, quand l'école la précise. Elle sert à ranger
  /// les promotions du plus récent au plus ancien.
  final int? annee;

  String get intitule => annee == null ? nom : '$nom ($annee)';

  factory Promotion.fromJson(Map<String, dynamic> json) {
    return Promotion(
      id: json['id'] as String,
      divisionId: json['division_id'] as String,
      nom: json['nom'] as String,
      annee: json['annee'] as int?,
    );
  }
}
