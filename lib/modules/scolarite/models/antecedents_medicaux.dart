/// Fiche persistante des antécédents médicaux d'un apprenant (allergies,
/// maladies chroniques, chirurgies, antécédents familiaux, traitement en
/// cours) — distincte des consultations ponctuelles, réservée à
/// l'administrateur et au médecin (données médicales sensibles). Une seule
/// fiche par apprenant (voir [apprenantId]).
class AntecedentsMedicaux {
  const AntecedentsMedicaux({
    required this.id,
    required this.apprenantId,
    required this.updatedAt,
    this.allergies,
    this.antecedentsPathologiques,
    this.antecedentsChirurgicaux,
    this.antecedentsFamiliaux,
    this.traitementEnCours,
    this.observations,
  });

  final String id;
  final String apprenantId;
  final String? allergies;
  final String? antecedentsPathologiques;
  final String? antecedentsChirurgicaux;
  final String? antecedentsFamiliaux;
  final String? traitementEnCours;
  final String? observations;
  final DateTime updatedAt;

  factory AntecedentsMedicaux.fromJson(Map<String, dynamic> json) {
    return AntecedentsMedicaux(
      id: json['id'] as String,
      apprenantId: json['apprenant_id'] as String,
      allergies: json['allergies'] as String?,
      antecedentsPathologiques: json['antecedents_pathologiques'] as String?,
      antecedentsChirurgicaux: json['antecedents_chirurgicaux'] as String?,
      antecedentsFamiliaux: json['antecedents_familiaux'] as String?,
      traitementEnCours: json['traitement_en_cours'] as String?,
      observations: json['observations'] as String?,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
