/// Note (sur 20) d'un apprenant à un contrôle précis. [matiereId] précise
/// la matière pour un contrôle continu/examen (un même contrôle peut
/// couvrir plusieurs matières) ; il est `null` pour un contrôle de type
/// "module", où la note est liée directement au module et à l'apprenant.
/// [previousNote] garde la valeur d'avant la dernière modification (null si
/// la note n'a jamais été modifiée depuis sa saisie).
/// [deletionRequestedAt] est renseigné quand un non-administrateur a demandé
/// la suppression de la note — elle attend alors la confirmation d'un
/// administrateur (voir [Note.suppressionDemandee]).
class Note {
  const Note({
    required this.id,
    required this.controleId,
    required this.apprenantId,
    this.matiereId,
    this.sousModuleId,
    required this.note,
    this.previousNote,
    this.deletionRequestedAt,
    this.deletionRequestedBy,
  });

  final String id;
  final String controleId;
  final String apprenantId;
  final String? matiereId;

  /// Renseigné pour une note de module : elle porte sur un sous-module
  /// précis. Exclusif de [matiereId] — la base fait respecter la règle.
  final String? sousModuleId;
  final num note;
  final num? previousNote;
  final DateTime? deletionRequestedAt;
  final String? deletionRequestedBy;

  bool get modifiee => previousNote != null;
  bool get suppressionDemandee => deletionRequestedAt != null;

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'] as String,
      controleId: json['controle_id'] as String,
      apprenantId: json['apprenant_id'] as String,
      matiereId: json['matiere_id'] as String?,
      sousModuleId: json['sous_module_id'] as String?,
      note: json['note'] as num,
      previousNote: json['previous_note'] as num?,
      deletionRequestedAt: json['deletion_requested_at'] == null
          ? null
          : DateTime.parse(json['deletion_requested_at'] as String),
      deletionRequestedBy: json['deletion_requested_by'] as String?,
    );
  }
}
