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

/// Une arme au registre.
///
/// Les deux premiers champs portent à l'écran les noms du registre tenu à
/// la main : [type] est la **désignation** (PA, PM, FA...), [modele] le
/// **marquage**. Les colonnes de la base gardent leurs anciens noms — les
/// bons de sortie s'y rattachent depuis l'origine.
class Arme {
  final String id;
  final String numeroSerie;

  /// Désignation — « Type d'arme » jusqu'au 17 octobre 2026.
  final String type;

  /// Marquage — « Modèle » jusqu'au 17 octobre 2026.
  final String modele;

  final EtatArme etat;

  /// Où se trouve l'arme : armurerie, compagnie, atelier...
  final String? positionActuelle;
  final String? observations;

  /// Facultatives : un registre repris d'un fichier ne les porte pas, et
  /// une date inventée vaut moins qu'une case vide.
  final DateTime? dateAcquisition;
  final DateTime? derniereInspection;
  final DateTime? prochaineInspection;

  const Arme({
    required this.id,
    required this.numeroSerie,
    required this.type,
    required this.modele,
    required this.etat,
    this.positionActuelle,
    this.observations,
    this.dateAcquisition,
    this.derniereInspection,
    this.prochaineInspection,
  });

  /// Sans date d'inspection prévue, il n'y a pas de retard : il n'y a rien
  /// de prévu. Les deux ne se confondent pas.
  bool get inspectionEnRetard =>
      prochaineInspection != null &&
      DateTime.now().isAfter(prochaineInspection!);

  /// « FA — AK 47 », ou « FA » seul quand le marquage manque : un tiret qui
  /// ne précède rien ressemble à une donnée perdue.
  String get designationComplete =>
      modele.trim().isEmpty ? type : '$type — $modele';
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

/// Référentiel des désignations d'arme (TYPE_ARME) — remplace la saisie
/// libre.
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

// --- Bons de munitions et d'équipements ------------------------------------

/// Les deux familles tenues en quantité, par opposition aux armes, tenues
/// pièce par pièce.
enum FamilleArticle { munition, equipement }

extension FamilleArticleLabel on FamilleArticle {
  String get libelle =>
      this == FamilleArticle.munition ? 'Munitions' : 'Équipements';
}

enum SensMouvement { entree, sortie }

extension SensMouvementLabel on SensMouvement {
  String get label => this == SensMouvement.entree ? 'Entrée' : 'Sortie';

  /// Le mot du registre : on perçoit ce qui sort, on réintègre ce qui rentre.
  String get libelleBon =>
      this == SensMouvement.entree ? 'Bon d\'entrée' : 'Bon de sortie';
}

/// Une entrée ou une sortie de stock — le bon lui-même.
///
/// C'est ce mouvement qui fait bouger la quantité disponible, et non
/// l'inverse : un déclencheur l'applique au stock dans la même transaction.
/// Le journal est donc toujours d'accord avec le stock.
class MouvementArticle {
  final String id;
  final FamilleArticle famille;
  final String articleId;
  final SensMouvement sens;
  final int quantite;
  final String? beneficiaireMatricule;
  final String? beneficiaireNom;
  final String? motif;
  final DateTime date;

  const MouvementArticle({
    required this.id,
    required this.famille,
    required this.articleId,
    required this.sens,
    required this.quantite,
    this.beneficiaireMatricule,
    this.beneficiaireNom,
    this.motif,
    required this.date,
  });

  String get beneficiaire {
    final nom = beneficiaireNom?.trim() ?? '';
    final mat = beneficiaireMatricule?.trim() ?? '';
    if (nom.isEmpty && mat.isEmpty) return '—';
    if (nom.isEmpty) return mat;
    if (mat.isEmpty) return nom;
    return '$nom ($mat)';
  }
}
