/// Nature d'une dépense du volet médical : soit un besoin courant du
/// service (aucun patient rattaché), soit une dépense engagée pour un
/// patient à la suite d'une consultation.
enum TypeDepense { service, consultation }

TypeDepense typeDepenseFromString(String value) {
  return value == 'consultation'
      ? TypeDepense.consultation
      : TypeDepense.service;
}

extension TypeDepenseValue on TypeDepense {
  String get value => switch (this) {
    TypeDepense.service => 'service',
    TypeDepense.consultation => 'consultation',
  };

  String get label => switch (this) {
    TypeDepense.service => 'Service médical',
    TypeDepense.consultation => 'Consultation',
  };

  /// Libellé complet, pour les en-têtes d'état imprimé et les infobulles.
  String get description => switch (this) {
    TypeDepense.service => 'Besoins courants du service médical',
    TypeDepense.consultation => 'Dépense engagée pour un patient',
  };
}

/// Poste de dépense — liste fermée (pas de saisie libre) pour que les
/// totaux par poste restent exploitables. Chaque poste appartient à un ou
/// plusieurs [TypeDepense] : le formulaire ne propose que ceux qui
/// correspondent à la nature choisie.
enum CategorieDepense {
  // Service
  fournitures,
  approvisionnementPharmacie,
  materiel,
  entretien,
  transportService,
  // Consultation
  analyse,
  imagerie,
  medicament,
  hospitalisationExterne,
  consultationExterne,
  evacuationSanitaire,
  // Commune
  autre,
}

CategorieDepense categorieDepenseFromString(String value) {
  return CategorieDepense.values.firstWhere(
    (c) => c.value == value,
    orElse: () => CategorieDepense.autre,
  );
}

extension CategorieDepenseValue on CategorieDepense {
  String get value => switch (this) {
    CategorieDepense.fournitures => 'fournitures',
    CategorieDepense.approvisionnementPharmacie =>
      'approvisionnement_pharmacie',
    CategorieDepense.materiel => 'materiel',
    CategorieDepense.entretien => 'entretien',
    CategorieDepense.transportService => 'transport_service',
    CategorieDepense.analyse => 'analyse',
    CategorieDepense.imagerie => 'imagerie',
    CategorieDepense.medicament => 'medicament',
    CategorieDepense.hospitalisationExterne => 'hospitalisation_externe',
    CategorieDepense.consultationExterne => 'consultation_externe',
    CategorieDepense.evacuationSanitaire => 'evacuation_sanitaire',
    CategorieDepense.autre => 'autre',
  };

  String get label => switch (this) {
    CategorieDepense.fournitures => 'Fournitures et consommables',
    CategorieDepense.approvisionnementPharmacie =>
      'Approvisionnement de la pharmacie',
    CategorieDepense.materiel => 'Matériel et équipement',
    CategorieDepense.entretien => 'Entretien et maintenance',
    CategorieDepense.transportService => 'Transport et carburant',
    CategorieDepense.analyse => 'Analyse / examen de laboratoire',
    CategorieDepense.imagerie => 'Imagerie / radiographie',
    CategorieDepense.medicament => 'Médicament acheté à l\'extérieur',
    CategorieDepense.hospitalisationExterne => 'Hospitalisation externe',
    CategorieDepense.consultationExterne => 'Consultation spécialisée externe',
    CategorieDepense.evacuationSanitaire => 'Évacuation sanitaire',
    CategorieDepense.autre => 'Autre',
  };

  /// Natures de dépense auxquelles ce poste s'applique.
  Set<TypeDepense> get types => switch (this) {
    CategorieDepense.fournitures ||
    CategorieDepense.approvisionnementPharmacie ||
    CategorieDepense.materiel ||
    CategorieDepense.entretien ||
    CategorieDepense.transportService => const {TypeDepense.service},
    CategorieDepense.analyse ||
    CategorieDepense.imagerie ||
    CategorieDepense.medicament ||
    CategorieDepense.hospitalisationExterne ||
    CategorieDepense.consultationExterne ||
    CategorieDepense.evacuationSanitaire => const {TypeDepense.consultation},
    CategorieDepense.autre => const {
      TypeDepense.service,
      TypeDepense.consultation,
    },
  };
}

/// Postes proposés pour une nature de dépense donnée, dans l'ordre de
/// déclaration de l'énumération.
List<CategorieDepense> categoriesPour(TypeDepense type) {
  return CategorieDepense.values.where((c) => c.types.contains(type)).toList();
}

/// Formate un montant en francs CFA avec une espace comme séparateur de
/// milliers ("1 250 000"). Le franc CFA n'ayant pas de subdivision en
/// usage, les montants sont manipulés en entiers de bout en bout.
String formatMontant(int montant) {
  final chiffres = montant.abs().toString();
  final buffer = StringBuffer(montant < 0 ? '-' : '');
  for (var i = 0; i < chiffres.length; i++) {
    if (i > 0 && (chiffres.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(chiffres[i]);
  }
  return buffer.toString();
}

/// Une dépense du volet médical. Pour une dépense de type
/// [TypeDepense.consultation], [consultationId] est toujours renseigné et
/// les champs `apprenant*`/[dateConsultation] portent le rappel du patient
/// concerné, lu en même temps que la dépense (jointure) pour que la liste
/// et l'état imprimé n'aient pas à recharger chaque consultation.
class Depense {
  const Depense({
    required this.id,
    required this.dateDepense,
    required this.type,
    required this.categorie,
    required this.libelle,
    required this.montant,
    this.observations,
    this.consultationId,
    this.dateConsultation,
    this.apprenantNom,
    this.apprenantMatricule,
    this.apprenantGrade,
  });

  final String id;
  final DateTime dateDepense;
  final TypeDepense type;
  final CategorieDepense categorie;
  final String libelle;
  final int montant;
  final String? observations;
  final String? consultationId;
  final DateTime? dateConsultation;
  final String? apprenantNom;
  final String? apprenantMatricule;
  final String? apprenantGrade;

  /// Identification du patient telle qu'elle apparaît en liste et à
  /// l'impression — `null` pour une dépense de service.
  String? get patient {
    final nom = apprenantNom;
    if (nom == null || nom.isEmpty) return null;
    final grade = apprenantGrade;
    return grade == null || grade.isEmpty ? nom : '$grade $nom';
  }

  factory Depense.fromJson(Map<String, dynamic> json) {
    final consultation =
        json['consultations_medicales'] as Map<String, dynamic>?;
    final apprenant = consultation?['apprenants'] as Map<String, dynamic>?;
    final nom = apprenant == null
        ? null
        : [
            apprenant['nom'] as String?,
            apprenant['prenom'] as String?,
          ].where((s) => s != null && s.trim().isNotEmpty).join(' ');

    return Depense(
      id: json['id'] as String,
      dateDepense: DateTime.parse(json['date_depense'] as String),
      type: typeDepenseFromString(json['type'] as String? ?? 'service'),
      categorie: categorieDepenseFromString(
        json['categorie'] as String? ?? 'autre',
      ),
      libelle: json['libelle'] as String,
      montant: (json['montant'] as num).toInt(),
      observations: json['observations'] as String?,
      consultationId: json['consultation_id'] as String?,
      dateConsultation: consultation?['date_souhaitee'] == null
          ? null
          : DateTime.parse(consultation!['date_souhaitee'] as String),
      apprenantNom: nom == null || nom.isEmpty ? null : nom,
      apprenantMatricule: apprenant?['matricule'] as String?,
      apprenantGrade: apprenant?['grade'] as String?,
    );
  }
}
