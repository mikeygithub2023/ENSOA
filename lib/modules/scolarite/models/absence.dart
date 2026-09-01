/// Absence d'un élève/stagiaire. `dateFin` est nulle tant que le retour
/// n'a pas été marqué : l'absence est alors "en cours".
class Absence {
  const Absence({
    required this.id,
    required this.apprenantId,
    required this.divisionId,
    required this.classeId,
    required this.dateDebut,
    required this.justifiee,
    this.dateFin,
    this.motif,
  });

  final String id;
  final String apprenantId;
  final String divisionId;
  final String classeId;
  final DateTime dateDebut;
  final DateTime? dateFin;
  final bool justifiee;
  final String? motif;

  bool get enCours => dateFin == null;

  factory Absence.fromJson(Map<String, dynamic> json) {
    return Absence(
      id: json['id'] as String,
      apprenantId: json['apprenant_id'] as String,
      divisionId: json['division_id'] as String,
      classeId: json['classe_id'] as String,
      dateDebut: DateTime.parse(json['date_debut'] as String),
      dateFin: json['date_fin'] == null
          ? null
          : DateTime.parse(json['date_fin'] as String),
      justifiee: json['justifiee'] as bool? ?? false,
      motif: json['motif'] as String?,
    );
  }
}
