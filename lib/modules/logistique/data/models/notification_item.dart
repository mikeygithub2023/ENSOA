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

  const AppNotification({
    required this.id,
    required this.categorie,
    required this.titre,
    required this.message,
    required this.date,
    this.lue = false,
  });
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
