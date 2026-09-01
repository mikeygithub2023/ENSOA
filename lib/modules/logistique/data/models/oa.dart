import 'package:sig_ensoa/core/roles.dart';

/// Service/acteur auquel l'Officier Adjoint peut confier une tâche sur une
/// activité. Distinct de [RoleLogistique] : plusieurs rôles applicatifs peuvent, à
/// terme, se rattacher au même acteur (ex. Santé aujourd'hui minimal).
enum ActeurTache { st, garage, armurerie, sante }

extension ActeurTacheLabel on ActeurTache {
  String get label {
    switch (this) {
      case ActeurTache.st:
        return 'Soutien pétrolier';
      case ActeurTache.garage:
        return 'Garage';
      case ActeurTache.armurerie:
        return 'Armurerie';
      case ActeurTache.sante:
        return 'Service de santé';
    }
  }
}

/// Rôle applicatif habilité à voir/traiter les tâches de cet acteur — null
/// si aucun rôle connecté ne correspond (l'acteur existe pour la
/// planification même sans utilisateur applicatif dédié pour l'instant).
extension ActeurTacheRole on ActeurTache {
  RoleLogistique get role {
    switch (this) {
      case ActeurTache.st:
        return RoleLogistique.soutienPetrolier;
      case ActeurTache.garage:
        return RoleLogistique.garage;
      case ActeurTache.armurerie:
        return RoleLogistique.armurerie;
      case ActeurTache.sante:
        return RoleLogistique.sante;
    }
  }
}

/// Trouve l'acteur correspondant au rôle connecté, s'il y en a un — sert à
/// filtrer "Mes tâches" sans dupliquer le mapping à chaque écran.
ActeurTache? acteurPourRole(RoleLogistique role) {
  for (final a in ActeurTache.values) {
    if (a.role == role) return a;
  }
  return null;
}

enum StatutActivite { planifiee, enCours, terminee, annulee }

extension StatutActiviteLabel on StatutActivite {
  String get label {
    switch (this) {
      case StatutActivite.planifiee:
        return 'Planifiée';
      case StatutActivite.enCours:
        return 'En cours';
      case StatutActivite.terminee:
        return 'Terminée';
      case StatutActivite.annulee:
        return 'Annulée';
    }
  }
}

/// aFaire → l'acteur exécute → terminee (en attente de validation OA) →
/// validee (clôturée par l'OA).
enum StatutTache { aFaire, terminee, validee }

extension StatutTacheLabel on StatutTache {
  String get label {
    switch (this) {
      case StatutTache.aFaire:
        return 'À faire';
      case StatutTache.terminee:
        return 'En attente de validation';
      case StatutTache.validee:
        return 'Validée';
    }
  }
}

class Activite {
  final String id;
  final String titre;
  final String? description;
  final DateTime dateActivite;
  final String? lieu;
  final StatutActivite statut;
  final String creePar;
  final DateTime creeLe;

  const Activite({
    required this.id,
    required this.titre,
    this.description,
    required this.dateActivite,
    this.lieu,
    this.statut = StatutActivite.planifiee,
    required this.creePar,
    required this.creeLe,
  });
}

class TacheActivite {
  final String id;
  final String activiteId;
  final ActeurTache acteur;
  final String description;
  final DateTime? dateLimite;
  final StatutTache statut;
  final String? termineePar;
  final DateTime? termineeLe;
  final DateTime? valideeLe;
  final String? commentaire;

  const TacheActivite({
    required this.id,
    required this.activiteId,
    required this.acteur,
    required this.description,
    this.dateLimite,
    this.statut = StatutTache.aFaire,
    this.termineePar,
    this.termineeLe,
    this.valideeLe,
    this.commentaire,
  });

  bool get enRetard =>
      statut == StatutTache.aFaire &&
      dateLimite != null &&
      dateLimite!.isBefore(DateTime.now());
}
