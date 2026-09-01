import 'package:flutter/material.dart';

/// Couleur du badge visiteur remis en échange d'une pièce d'identité.
enum CouleurBadge { rouge, jaune, vert, bleu, blanc }

extension CouleurBadgeLabel on CouleurBadge {
  String get label {
    switch (this) {
      case CouleurBadge.rouge:
        return 'Rouge';
      case CouleurBadge.jaune:
        return 'Jaune';
      case CouleurBadge.vert:
        return 'Vert';
      case CouleurBadge.bleu:
        return 'Bleu';
      case CouleurBadge.blanc:
        return 'Blanc';
    }
  }

  Color get couleur {
    switch (this) {
      case CouleurBadge.rouge:
        return const Color(0xFFE0524B);
      case CouleurBadge.jaune:
        return const Color(0xFFE0C23B);
      case CouleurBadge.vert:
        return const Color(0xFF2FA36B);
      case CouleurBadge.bleu:
        return const Color(0xFF2F6FE0);
      case CouleurBadge.blanc:
        return const Color(0xFFB8C2D6);
    }
  }
}

/// PASSAGE_VISITEUR — mouvement d'entrée/sortie d'un visiteur au poste de
/// police. [dateSortie] reste nul tant que le visiteur est dans le camp.
class PassageVisiteur {
  final String id;
  final String contactVisiteur;
  final String nomVisiteur;
  final String? photoBase64;
  final CouleurBadge couleurBadge;
  final String contactRecu; // contact de la personne visitée
  final String nomRecu; // nom de la personne visitée
  final DateTime dateArrivee;
  final DateTime? dateSortie;
  final String enregistrePar;

  /// Immatriculation du véhicule avec lequel le visiteur se présente.
  ///
  /// Un véhicule civil, qui n'appartient pas au parc de l'école : il n'a ni
  /// ordre de mission ni kilométrage à relever, et ne doit pas être
  /// confondu avec un [PassageVehicule].
  final String? vehiculeImmatriculation;

  /// Marque, modèle, couleur — ce qui permet de le reconnaître sur le
  /// parking.
  final String? vehiculeDescription;

  /// Personnes venues avec le visiteur, sous sa responsabilité.
  final int nombreAccompagnants;

  /// Leurs noms, tels que le planton les inscrit sur son registre.
  final String? accompagnants;

  const PassageVisiteur({
    required this.id,
    required this.contactVisiteur,
    required this.nomVisiteur,
    this.photoBase64,
    required this.couleurBadge,
    required this.contactRecu,
    required this.nomRecu,
    required this.dateArrivee,
    this.dateSortie,
    required this.enregistrePar,
    this.vehiculeImmatriculation,
    this.vehiculeDescription,
    this.nombreAccompagnants = 0,
    this.accompagnants,
  });

  bool get enCours => dateSortie == null;

  bool get avecVehicule =>
      vehiculeImmatriculation != null && vehiculeImmatriculation!.isNotEmpty;

  bool get accompagne => nombreAccompagnants > 0;

  /// Effectif total entré au portail : le visiteur et ceux qu'il amène.
  int get effectif => 1 + nombreAccompagnants;
}

/// PASSAGE_VEHICULE — contrôle par le poste de police du franchissement
/// physique du portail pour un véhicule dont la sortie a été autorisée par
/// un mouvement (mission) créé côté Garage : [mouvementId] porte cette
/// autorisation, le poste de police se limite à horodater sortie/retour.
class PassageVehicule {
  final String id;
  final String vehiculeId;
  final String? mouvementId;
  final DateTime dateSortie;
  final DateTime? dateRetour;
  final int? kmRetour;
  final String enregistrePar;

  const PassageVehicule({
    required this.id,
    required this.vehiculeId,
    this.mouvementId,
    required this.dateSortie,
    this.dateRetour,
    this.kmRetour,
    required this.enregistrePar,
  });

  bool get enCours => dateRetour == null;
}
