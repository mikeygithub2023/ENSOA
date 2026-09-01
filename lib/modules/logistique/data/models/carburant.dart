/// SOUTE — simple emplacement/réservoir nommé. Les quantités vivent dans
/// SOUTE_TYPE_STOCK, pas ici.
class Soute {
  final String id; // IDSOUTE
  final String libelle; // LIBELLE_SOUTE
  const Soute({required this.id, required this.libelle});
}

/// TYPE_STOCK — libellé d'un type de carburant (Gasoil, Super...).
class TypeStock {
  final String id; // IDTYPE_STOCK
  final String libelle; // LIBELLE_TYPE_STOCK
  const TypeStock({required this.id, required this.libelle});
}

/// RÉPARTITION — une allocation par unité (ex. "BA1", "CA1", "CA2"),
/// indépendante des soutes : une même répartition peut avoir du carburant
/// dans plusieurs soutes différentes.
class Repartition {
  final String id;
  final String libelle;
  const Repartition({required this.id, required this.libelle});
}

/// SOUTE_TYPE_STOCK — la jonction Soute × Répartition × TypeStock : combien
/// une répartition donnée a de carburant DANS une soute donnée. Le niveau
/// affiché d'une soute est la somme de ses lignes — ce n'est PAS une valeur
/// stockée directement sur la soute. Dépotage et Distribution ciblent
/// toujours une ligne précise (souteStockId), jamais la soute elle-même :
/// le dépotage se fait DANS une soute mais est AFFECTÉ à une répartition.
class SouteStock {
  final String id; // ID_AUTO_TYPE_STOCK
  final String souteId; // IDSOUTE
  final String typeStockId; // IDTYPE_STOCK
  final String repartitionId; // Répartition propriétaire de cette ligne
  final String repartitionLibelle; // Résolu via jointure, pour l'affichage
  final int qteGasoil; // QTE_GASOIL
  final int qteSuper; // QTE_SUPER
  final int seuilNominal; // SEUIL_NOMINAL
  final int seuilCritique; // SEUIL_CRITIQUE

  const SouteStock({
    required this.id,
    required this.souteId,
    required this.typeStockId,
    required this.repartitionId,
    required this.repartitionLibelle,
    required this.qteGasoil,
    required this.qteSuper,
    required this.seuilNominal,
    required this.seuilCritique,
  });

  int get quantiteTotale => qteGasoil + qteSuper;
  bool get seuilAtteint => quantiteTotale <= seuilCritique;
}

/// DEPOTAGE — réception de carburant dans une soute.
class Depotage {
  final String id; // IDDEPOTAGE
  final DateTime date; // DATE_DEPOTAGE
  final int quantiteRecue; // QTE_CARBURANT_RECUE
  final String typeCarburant; // TYPE_CARBURANT
  final String utilisateurId; // IDUTILISATEUR
  final String souteStockId; // ID_AUTO_TYPE_STOCK

  const Depotage({
    required this.id,
    required this.date,
    required this.quantiteRecue,
    required this.typeCarburant,
    required this.utilisateurId,
    required this.souteStockId,
  });
}

/// DISTRIBUTION — remise de carburant à un militaire, avec informations
/// dénormalisées (destinataire/véhicule) telles que saisies au moment de l'acte.
class Distribution {
  final String id; // ID_AUTO_DISTRIBUTION
  final String souteStockId; // ID_AUTO_TYPE_STOCK
  final String? personnelId; // IDPERSONNEL
  final String utilisateurId; // IDUTILISATEUR (agent qui distribue)
  final int quantitePercue; // QTE_PERCUE
  final DateTime date; // DATE_DISTRIBUTION
  final String? heure; // HEURE_DISTRIBUTION
  final String typeCarburant; // TYPE_CARBURANT
  final String? contact; // CONTACT
  final String? gradeDestinataire; // GRADE_DESTINATAIRE
  final String destinataire; // DESTINATAIRE
  final String? vehicule; // VEHICULE
  final String? vhlImmatriculation; // VHL_IMMATRICULATION
  final int? kilometrage; // KILOMETRAGE
  final String? typeStock; // TYPE_STOCK
  final String? motif; // MOTIF

  const Distribution({
    required this.id,
    required this.souteStockId,
    this.personnelId,
    required this.utilisateurId,
    required this.quantitePercue,
    required this.date,
    this.heure,
    required this.typeCarburant,
    this.contact,
    this.gradeDestinataire,
    required this.destinataire,
    this.vehicule,
    this.vhlImmatriculation,
    this.kilometrage,
    this.typeStock,
    this.motif,
  });
}
