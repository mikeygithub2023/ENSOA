/// Notification adressée à un profil précis : demande de suppression de
/// note ou d'apprenant à valider par un administrateur, demande de
/// réapprovisionnement de la pharmacie à titre d'information. [noteId],
/// [apprenantId] et [demandeReapprovisionnementId] permettent de retrouver
/// l'enregistrement concerné selon le [type].
class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.profileId,
    required this.type,
    required this.title,
    required this.message,
    required this.read,
    required this.createdAt,
    this.noteId,
    this.apprenantId,
    this.demandeReapprovisionnementId,
  });

  final String id;
  final String profileId;
  final String type;
  final String title;
  final String message;
  final bool read;
  final DateTime createdAt;
  final String? noteId;
  final String? apprenantId;
  final String? demandeReapprovisionnementId;

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] as String,
      profileId: json['profile_id'] as String,
      type: json['type'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      read: json['read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      noteId: json['note_id'] as String?,
      apprenantId: json['apprenant_id'] as String?,
      demandeReapprovisionnementId:
          json['demande_reapprovisionnement_id'] as String?,
    );
  }
}
