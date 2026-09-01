/// Classe pharmacologique d'un médicament — liste fermée (pas de catalogue
/// libre) pour que le rangement du catalogue par type reste cohérent : un
/// champ texte libre fragmenterait les groupes au moindre écart de saisie.
enum TypeMedicament {
  antalgique,
  antibiotique,
  antipaludeen,
  antiInflammatoire,
  antiseptique,
  antihistaminique,
  digestif,
  vitamine,
  solute,
  materiel,
  autre,
}

TypeMedicament typeMedicamentFromString(String value) {
  return TypeMedicament.values.firstWhere(
    (t) => t.value == value,
    orElse: () => TypeMedicament.autre,
  );
}

extension TypeMedicamentLabel on TypeMedicament {
  String get value => switch (this) {
    TypeMedicament.antalgique => 'antalgique',
    TypeMedicament.antibiotique => 'antibiotique',
    TypeMedicament.antipaludeen => 'antipaludeen',
    TypeMedicament.antiInflammatoire => 'anti_inflammatoire',
    TypeMedicament.antiseptique => 'antiseptique',
    TypeMedicament.antihistaminique => 'antihistaminique',
    TypeMedicament.digestif => 'digestif',
    TypeMedicament.vitamine => 'vitamine',
    TypeMedicament.solute => 'solute',
    TypeMedicament.materiel => 'materiel',
    TypeMedicament.autre => 'autre',
  };

  String get label => switch (this) {
    TypeMedicament.antalgique => 'Antalgique / Antipyrétique',
    TypeMedicament.antibiotique => 'Antibiotique',
    TypeMedicament.antipaludeen => 'Antipaludéen',
    TypeMedicament.antiInflammatoire => 'Anti-inflammatoire',
    TypeMedicament.antiseptique => 'Antiseptique / Désinfectant',
    TypeMedicament.antihistaminique => 'Antihistaminique',
    TypeMedicament.digestif => 'Digestif',
    TypeMedicament.vitamine => 'Vitamines / Compléments',
    TypeMedicament.solute => 'Solutés / Perfusion',
    TypeMedicament.materiel => 'Matériel médical',
    TypeMedicament.autre => 'Autre',
  };
}

/// État du stock d'un médicament, du plus critique au plus serein. Les
/// trois premiers appellent une action du pharmacien ; [EtatStock.suffisant]
/// est le cas nominal.
enum EtatStock { rupture, seuilAtteint, seuilProche, suffisant }

extension EtatStockLabel on EtatStock {
  String get label => switch (this) {
    EtatStock.rupture => 'Rupture de stock',
    EtatStock.seuilAtteint => 'Seuil atteint',
    EtatStock.seuilProche => 'Seuil bientôt atteint',
    EtatStock.suffisant => 'Stock suffisant',
  };

  /// Ce que l'état veut dire, en une ligne — affiché sous le compte dans le
  /// tableau de bord de la pharmacie.
  String get description => switch (this) {
    EtatStock.rupture => 'Stock épuisé',
    EtatStock.seuilAtteint => 'Au seuil d\'alerte ou en dessous',
    EtatStock.seuilProche => 'À moins de 10 % au-dessus du seuil',
    EtatStock.suffisant => 'Au-dessus du seuil d\'alerte',
  };
}

/// Médicament du catalogue de l'infirmerie, avec un stock unique pour
/// toute l'école ("le point") — géré par l'administrateur et le médecin.
/// [stock] n'est plus jamais modifié directement : il ne change qu'en
/// réaction à l'insertion d'un [MouvementStock] (trigger côté base), qui en
/// est la seule source de vérité. [datePeremption] pilote l'alerte de
/// péremption ; [seuilAlerte] détermine l'[etatStock], sur lequel s'appuient
/// la pastille de chaque médicament et le tableau de bord de la pharmacie.
/// [type] sert à ranger le catalogue par classe pharmacologique.
class Medicament {
  const Medicament({
    required this.id,
    required this.nom,
    required this.stock,
    required this.seuilAlerte,
    required this.type,
    this.unite,
    this.datePeremption,
  });

  final String id;
  final String nom;
  final String? unite;
  final int stock;
  final int seuilAlerte;
  final DateTime? datePeremption;
  final TypeMedicament type;

  /// Stock à partir duquel le seuil d'alerte est jugé « bientôt atteint » :
  /// 10 % au-dessus du seuil, arrondi au supérieur pour rester parlant sur
  /// les petits seuils (un seuil de 5 alerte donc à partir de 6).
  int get seuilProche => (seuilAlerte * 1.1).ceil();

  EtatStock get etatStock {
    if (stock <= 0) return EtatStock.rupture;
    if (stock <= seuilAlerte) return EtatStock.seuilAtteint;
    if (stock <= seuilProche) return EtatStock.seuilProche;
    return EtatStock.suffisant;
  }

  bool get perime =>
      datePeremption != null && datePeremption!.isBefore(DateTime.now());

  /// Trois mois : le délai qu'il faut à la pharmacie pour écouler un lot ou
  /// le faire reprendre. En deçà, le médicament doit apparaître dans les
  /// alertes même si son stock est confortable.
  bool get perimeBientot =>
      !perime &&
      datePeremption != null &&
      datePeremption!.isBefore(DateTime.now().add(const Duration(days: 90)));

  /// Périmé ou sur le point de l'être — ce qui appelle une décision, qu'il
  /// s'agisse de retirer le lot ou de l'écouler en priorité.
  bool get peremptionAsurveiller => perime || perimeBientot;

  factory Medicament.fromJson(Map<String, dynamic> json) {
    return Medicament(
      id: json['id'] as String,
      nom: json['nom'] as String,
      unite: json['unite'] as String?,
      stock: json['stock'] as int,
      seuilAlerte: json['seuil_alerte'] as int? ?? 10,
      datePeremption: json['date_peremption'] == null
          ? null
          : DateTime.parse(json['date_peremption'] as String),
      type: typeMedicamentFromString(json['type'] as String? ?? 'autre'),
    );
  }
}

/// Un médicament prescrit lors d'une consultation — son insertion décompte
/// automatiquement le stock du [Medicament] correspondant (trigger côté
/// base), sa suppression le restitue. Chacune de ces opérations est elle
/// -même enregistrée comme un [MouvementStock].
class OrdonnanceLigne {
  const OrdonnanceLigne({
    required this.id,
    required this.consultationId,
    required this.medicamentId,
    required this.quantite,
    this.posologie,
  });

  final String id;
  final String consultationId;
  final String medicamentId;
  final int quantite;
  final String? posologie;

  factory OrdonnanceLigne.fromJson(Map<String, dynamic> json) {
    return OrdonnanceLigne(
      id: json['id'] as String,
      consultationId: json['consultation_id'] as String,
      medicamentId: json['medicament_id'] as String,
      quantite: json['quantite'] as int,
      posologie: json['posologie'] as String?,
    );
  }
}

enum MouvementType { entree, sortie }

MouvementType mouvementTypeFromString(String value) {
  return value == 'entree' ? MouvementType.entree : MouvementType.sortie;
}

extension MouvementTypeLabel on MouvementType {
  String get label => switch (this) {
    MouvementType.entree => 'Entrée',
    MouvementType.sortie => 'Sortie',
  };
}

/// Une ligne du journal des mouvements de stock d'un médicament — seule
/// source de vérité pour [Medicament.stock] (voir la migration 023).
class MouvementStock {
  const MouvementStock({
    required this.id,
    required this.medicamentId,
    required this.type,
    required this.quantite,
    required this.motif,
    required this.createdAt,
    this.consultationId,
  });

  final String id;
  final String medicamentId;
  final MouvementType type;
  final int quantite;
  final String motif;
  final String? consultationId;
  final DateTime createdAt;

  factory MouvementStock.fromJson(Map<String, dynamic> json) {
    return MouvementStock(
      id: json['id'] as String,
      medicamentId: json['medicament_id'] as String,
      type: mouvementTypeFromString(json['type'] as String),
      quantite: json['quantite'] as int,
      motif: json['motif'] as String,
      consultationId: json['consultation_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// Consommation d'un médicament sur une période : le net des quantités
/// dispensées lors des consultations. Les prescriptions annulées sont
/// déduites — le journal enregistre leur restitution comme une entrée
/// rattachée à la même consultation (voir la migration 023).
class ConsommationMedicament {
  const ConsommationMedicament({
    required this.medicamentId,
    required this.nom,
    required this.type,
    required this.quantite,
  });

  final String medicamentId;
  final String nom;
  final TypeMedicament type;
  final int quantite;
}
