/// Matière du catalogue global (créée par l'administrateur).
class Matiere {
  const Matiere({required this.id, required this.code, required this.nom});

  final String id;
  final String code;
  final String nom;

  factory Matiere.fromJson(Map<String, dynamic> json) {
    return Matiere(
      id: json['id'] as String,
      code: json['code'] as String,
      nom: json['nom'] as String,
    );
  }
}

/// Affectation d'une matière du catalogue à une (division, classe), avec son
/// coefficient pour cette classe — gérée par le commandant de division concerné.
class MatiereModule {
  const MatiereModule({
    required this.id,
    required this.matiereId,
    required this.divisionId,
    required this.classeId,
    required this.coefficient,
  });

  final String id;
  final String matiereId;
  final String divisionId;
  final String classeId;
  final double coefficient;

  factory MatiereModule.fromJson(Map<String, dynamic> json) {
    return MatiereModule(
      id: json['id'] as String,
      matiereId: json['matiere_id'] as String,
      divisionId: json['division_id'] as String,
      classeId: json['classe_id'] as String,
      coefficient: (json['coefficient'] as num).toDouble(),
    );
  }
}
