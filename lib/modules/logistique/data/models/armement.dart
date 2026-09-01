enum EtatArme { enDotation, enArmurerie, enMaintenance, reforme }

extension EtatArmeLabel on EtatArme {
  String get label {
    switch (this) {
      case EtatArme.enDotation:
        return 'En dotation';
      case EtatArme.enArmurerie:
        return 'En armurerie';
      case EtatArme.enMaintenance:
        return 'En maintenance';
      case EtatArme.reforme:
        return 'Réformée';
    }
  }
}

class Arme {
  final String id;
  final String numeroSerie;
  final String type; // ex: Fusil d'assaut, Pistolet, Mitrailleuse...
  final String modele;
  final EtatArme etat;
  final DateTime dateAcquisition;
  final DateTime? derniereInspection;
  final DateTime prochaineInspection;

  const Arme({
    required this.id,
    required this.numeroSerie,
    required this.type,
    required this.modele,
    required this.etat,
    required this.dateAcquisition,
    this.derniereInspection,
    required this.prochaineInspection,
  });

  bool get inspectionEnRetard => DateTime.now().isAfter(prochaineInspection);
}

class DotationArme {
  final String id;
  final String armeId;
  final String beneficiaireId; // matricule militaire
  final String beneficiaireNom;
  final DateTime dateRemise;
  final DateTime? dateRetourPrevue;
  final DateTime? dateRetourEffective;
  final String remisePar;
  final String? motif; // garde, instruction, mission...

  const DotationArme({
    required this.id,
    required this.armeId,
    required this.beneficiaireId,
    required this.beneficiaireNom,
    required this.dateRemise,
    this.dateRetourPrevue,
    this.dateRetourEffective,
    required this.remisePar,
    this.motif,
  });

  bool get enCours => dateRetourEffective == null;

  bool get retourEnRetard =>
      enCours &&
      dateRetourPrevue != null &&
      DateTime.now().isAfter(dateRetourPrevue!);
}

class StockMunition {
  final String id;
  final String calibre;
  final int quantiteDisponible;
  final int seuilCritique;
  final String souteArmementId;

  const StockMunition({
    required this.id,
    required this.calibre,
    required this.quantiteDisponible,
    required this.seuilCritique,
    required this.souteArmementId,
  });

  bool get seuilAtteint => quantiteDisponible <= seuilCritique;
}

/// Référentiel des types d'arme (TYPE_ARME) — remplace la saisie libre.
class TypeArme {
  final String id;
  final String libelle;
  const TypeArme({required this.id, required this.libelle});
}

/// Équipement de protection individuelle (EPI) — géré en stock global comme
/// les munitions (quantité disponible / seuil critique).
class EquipementProtection {
  final String id;
  final String libelle;
  final int quantiteDisponible;
  final int seuilCritique;

  const EquipementProtection({
    required this.id,
    required this.libelle,
    required this.quantiteDisponible,
    required this.seuilCritique,
  });

  bool get seuilAtteint => quantiteDisponible <= seuilCritique;
}

/// Attribution nominative d'un EPI (miroir de [DotationArme]).
class DotationEquipement {
  final String id;
  final String equipementId;
  final String beneficiaireId; // matricule militaire
  final DateTime dateRemise;
  final DateTime? dateRetourEffective;
  final String remisePar;
  final String? motif;

  const DotationEquipement({
    required this.id,
    required this.equipementId,
    required this.beneficiaireId,
    required this.dateRemise,
    this.dateRetourEffective,
    required this.remisePar,
    this.motif,
  });

  bool get enCours => dateRetourEffective == null;
}
