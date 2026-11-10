/// Reflète VEHICULE (analyse CST.wda). ETAT_VHL/POSITION_ACTUELLE restent des
/// chaînes côté HFSQL — mappées ici vers des enums pour la sécurité de type,
/// via [EtatVehicule]/[fromHfsql]/[toHfsql] au moment de brancher le backend.
enum EtatVehicule { disponible, enMission, enReparation, horsService }

extension EtatVehiculeLabel on EtatVehicule {
  String get label {
    switch (this) {
      case EtatVehicule.disponible:
        return 'Disponible';
      case EtatVehicule.enMission:
        return 'En mission';
      case EtatVehicule.enReparation:
        return 'En réparation';
      case EtatVehicule.horsService:
        return 'Hors service';
    }
  }
}

/// MARQUE_VHL
class MarqueVehicule {
  final String id; // IDMARQUE_VHL
  final String marque; // MARQUE
  const MarqueVehicule({required this.id, required this.marque});
}

/// MODELE_VHL
class ModeleVehicule {
  final String id; // IDMODELE_VHL
  final String modele; // MODELE_VHL
  final String marqueId; // IDMARQUE_VHL
  const ModeleVehicule({
    required this.id,
    required this.modele,
    required this.marqueId,
  });
}

/// TYPE_VHL
class TypeVehicule {
  final String id; // IDTYPE_VHL
  final String type; // TYPE_VHL
  final String modeleId; // IDMODELE_VHL
  const TypeVehicule({
    required this.id,
    required this.type,
    required this.modeleId,
  });
}

/// VEHICULE
class Vehicule {
  final String id; // IDVEHICULE
  final String chassis; // CHASSIS
  final String immatriculation; // IMMATRICULATION
  final int kilometrage; // KILOMETRAGE
  final EtatVehicule etat; // ETAT_VHL
  final String? positionActuelle; // POSITION_ACTUELLE
  final int nbrePlaces; // NBRE_PLACES
  final String? observations; // OBSERVATIONS
  final String typeVehiculeId; // IDTYPE_VHL
  final int kilometrageVidangeProchaine; // KILOMETRAGE_VIDANGE_PROCHAINE
  final int? kilometrageVidangePrecedente; // KILOMETRAGE_VIDANGE_PRECEDENTE

  /// La date de l'unique correction du kilométrage depuis la fiche ; nulle
  /// tant qu'elle n'a pas eu lieu.
  final DateTime? kilometrageCorrigeLe;

  // Champs d'affichage dénormalisés côté app (résolus via TYPE_VHL → MODELE_VHL → MARQUE_VHL) :
  final String marque;
  final String modele;
  final String typeVehicule;

  const Vehicule({
    required this.id,
    required this.chassis,
    required this.immatriculation,
    required this.kilometrage,
    required this.etat,
    this.positionActuelle,
    this.nbrePlaces = 4,
    this.observations,
    required this.typeVehiculeId,
    required this.kilometrageVidangeProchaine,
    this.kilometrageVidangePrecedente,
    this.kilometrageCorrigeLe,
    required this.marque,
    required this.modele,
    required this.typeVehicule,
  });

  bool get vidangeRequise => kilometrage >= kilometrageVidangeProchaine;

  bool get kilometrageCorrige => kilometrageCorrigeLe != null;
}
