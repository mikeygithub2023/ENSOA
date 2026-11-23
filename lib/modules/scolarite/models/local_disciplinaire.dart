/// Un séjour aux locaux disciplinaires.
///
/// Une punition n'est pas une absence : elle a une durée décidée d'avance,
/// un motif et une autorité qui l'a prononcée. C'est pourquoi elle ne se
/// range pas avec les absences, où l'on constate après coup que quelqu'un
/// manque.
///
/// [jours] compte le premier jour : trois jours à partir du lundi
/// s'achèvent le mercredi. [dateSortie] n'est renseignée qu'au retour — plus
/// tôt que prévu si la punition est levée, plus tard si l'intéressé est
/// resté.
class LocalDisciplinaire {
  const LocalDisciplinaire({
    required this.id,
    required this.apprenantId,
    required this.divisionId,
    required this.dateDebut,
    required this.jours,
    required this.motif,
    this.classeId,
    this.autorite,
    this.dateSortie,
  });

  final String id;
  final String apprenantId;
  final String divisionId;

  /// Nulle pour le personnel de l'école, qui ne suit aucune phase.
  final String? classeId;

  final DateTime dateDebut;
  final int jours;
  final String motif;
  final String? autorite;
  final DateTime? dateSortie;

  /// Le dernier jour de punition, celui-ci compris.
  DateTime get dateFinPrevue =>
      DateTime(dateDebut.year, dateDebut.month, dateDebut.day + jours - 1);

  /// Tant que la sortie n'est pas marquée, le séjour court.
  bool get enCours => dateSortie == null;

  /// La punition est échue mais personne n'a marqué la sortie : il y a
  /// quelqu'un à faire sortir, ou une écriture à terminer.
  bool sortieEnRetard(DateTime jour) =>
      enCours && _jourSeul(jour).isAfter(dateFinPrevue);

  /// L'intéressé est-il aux arrêts ce jour-là ?
  ///
  /// Il l'est du premier jour au dernier, celui-ci compris, et cesse de
  /// l'être dès que la sortie est marquée — même si les jours infligés
  /// n'étaient pas écoulés. Une punition échue dont la sortie n'a pas été
  /// notée ne le retient pas non plus : on ne garde personne aux arrêts par
  /// défaut d'écriture.
  bool estAuxArretsLe(DateTime jour) {
    final j = _jourSeul(jour);
    if (j.isBefore(_jourSeul(dateDebut))) return false;
    final sortie = dateSortie;
    if (sortie != null) return j.isBefore(_jourSeul(sortie));
    return !j.isAfter(dateFinPrevue);
  }

  static DateTime _jourSeul(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  factory LocalDisciplinaire.fromJson(Map<String, dynamic> json) {
    return LocalDisciplinaire(
      id: json['id'] as String,
      apprenantId: json['apprenant_id'] as String,
      divisionId: json['division_id'] as String,
      classeId: json['classe_id'] as String?,
      dateDebut: DateTime.parse(json['date_debut'] as String),
      jours: (json['jours'] as num?)?.toInt() ?? 1,
      motif: json['motif'] as String? ?? '',
      autorite: json['autorite'] as String?,
      dateSortie: json['date_sortie'] == null
          ? null
          : DateTime.parse(json['date_sortie'] as String),
    );
  }
}
