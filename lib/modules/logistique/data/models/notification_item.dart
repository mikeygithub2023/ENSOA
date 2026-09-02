import 'package:flutter/material.dart';

enum NotificationCategory {
  carburant,
  maintenance,
  armement,
  systeme,
  activite,
}

class AppNotification {
  final String id;
  final NotificationCategory categorie;
  final String titre;
  final String message;
  final DateTime date;
  final bool lue;

  /// La note dont la suppression est demandée, pour une notification de ce
  /// type. C'est elle qui permet à l'administrateur de trancher depuis la
  /// liste : sans elle, il lisait la demande sans pouvoir y répondre.
  final String? noteId;

  const AppNotification({
    required this.id,
    required this.categorie,
    required this.titre,
    required this.message,
    required this.date,
    this.lue = false,
    this.noteId,
  });

  bool get estDemandeDeSuppression => noteId != null;

  /// La même notification, lue. Les champs sont finaux : pour en changer
  /// un il faut reconstruire l'objet, et le refaire à la main partout
  /// invitait à en oublier un.
  AppNotification copieLue() => AppNotification(
    id: id,
    categorie: categorie,
    titre: titre,
    message: message,
    date: date,
    lue: true,
    noteId: noteId,
  );
}

extension NotificationCategoryIcon on NotificationCategory {
  IconData get icon {
    switch (this) {
      case NotificationCategory.carburant:
        return Icons.local_gas_station;
      case NotificationCategory.maintenance:
        return Icons.build;
      case NotificationCategory.armement:
        return Icons.security;
      case NotificationCategory.systeme:
        return Icons.info;
      case NotificationCategory.activite:
        return Icons.event_note;
    }
  }
}
