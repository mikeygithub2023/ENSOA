enum VisiteType {
  incorporation,
  periodique,
  aptitudeSport,
  reprise,
  contreVisite,
}

const _visiteTypeDbValues = {
  VisiteType.incorporation: 'incorporation',
  VisiteType.periodique: 'periodique',
  VisiteType.aptitudeSport: 'aptitude_sport',
  VisiteType.reprise: 'reprise',
  VisiteType.contreVisite: 'contre_visite',
};

VisiteType visiteTypeFromString(String value) {
  return _visiteTypeDbValues.entries
      .firstWhere(
        (e) => e.value == value,
        orElse: () => const MapEntry(VisiteType.periodique, 'periodique'),
      )
      .key;
}

extension VisiteTypeValue on VisiteType {
  String get value => _visiteTypeDbValues[this]!;

  String get label => switch (this) {
    VisiteType.incorporation => 'Visite d\'incorporation',
    VisiteType.periodique => 'Visite périodique',
    VisiteType.aptitudeSport => 'Aptitude sport',
    VisiteType.reprise => 'Reprise d\'activité',
    VisiteType.contreVisite => 'Contre-visite',
  };
}

enum VisiteResultat { apte, inapteTemporaire, inapteDefinitif, aRevoir }

const _visiteResultatDbValues = {
  VisiteResultat.apte: 'apte',
  VisiteResultat.inapteTemporaire: 'inapte_temporaire',
  VisiteResultat.inapteDefinitif: 'inapte_definitif',
  VisiteResultat.aRevoir: 'a_revoir',
};

VisiteResultat visiteResultatFromString(String value) {
  return _visiteResultatDbValues.entries
      .firstWhere(
        (e) => e.value == value,
        orElse: () => const MapEntry(VisiteResultat.apte, 'apte'),
      )
      .key;
}

extension VisiteResultatValue on VisiteResultat {
  String get value => _visiteResultatDbValues[this]!;

  String get label => switch (this) {
    VisiteResultat.apte => 'Apte',
    VisiteResultat.inapteTemporaire => 'Inapte temporaire',
    VisiteResultat.inapteDefinitif => 'Inapte définitif',
    VisiteResultat.aRevoir => 'À revoir',
  };
}

/// Les sept lettres du profil médical SIGYCOP, dans l'ordre du cachet
/// d'examen — chacune est cotée de 1 à 6 (0 = non coté).
enum SigycopLettre { s, i, g, y, c, o, p }

extension SigycopLettreLabel on SigycopLettre {
  String get lettre => switch (this) {
    SigycopLettre.s => 'S',
    SigycopLettre.i => 'I',
    SigycopLettre.g => 'G',
    SigycopLettre.y => 'Y',
    SigycopLettre.c => 'C',
    SigycopLettre.o => 'O',
    SigycopLettre.p => 'P',
  };

  String get description => switch (this) {
    SigycopLettre.s => 'Ceinture scapulaire et membres supérieurs',
    SigycopLettre.i => 'Membres inférieurs',
    SigycopLettre.g => 'État général',
    SigycopLettre.y => 'Yeux et vision',
    SigycopLettre.c => 'Sens chromatique',
    SigycopLettre.o => 'Oreilles et audition',
    SigycopLettre.p => 'Psychisme',
  };
}

/// Visite médicale : une campagne convoquant une classe/stage à une date
/// donnée. Les apprenants qui l'ont passée, avec leur examen, sont des
/// [VisiteMedicaleApprenant] rattachés à elle.
class VisiteMedicale {
  const VisiteMedicale({
    required this.id,
    required this.titre,
    required this.divisionId,
    required this.classeId,
    required this.dateVisite,
    required this.type,
  });

  final String id;
  final String titre;
  final String divisionId;
  final String classeId;
  final DateTime dateVisite;
  final VisiteType type;

  factory VisiteMedicale.fromJson(Map<String, dynamic> json) {
    return VisiteMedicale(
      id: json['id'] as String,
      titre: json['titre'] as String,
      divisionId: json['division_id'] as String,
      classeId: json['classe_id'] as String,
      dateVisite: DateTime.parse(json['date_visite'] as String),
      type: visiteTypeFromString(json['type'] as String? ?? 'periodique'),
    );
  }
}

/// Passage d'un apprenant à une visite médicale : le résultat de l'examen
/// tel qu'il figure sur le cachet apposé au dossier médical — mensurations
/// (avec l'indice de Pignet calculé par la base), constantes, acuité
/// visuelle et auditive, analyse d'urine, examen clinique, profil SIGYCOP
/// et conclusion d'aptitude.
class VisiteMedicaleApprenant {
  const VisiteMedicaleApprenant({
    required this.id,
    required this.visiteId,
    required this.apprenantId,
    required this.resultat,
    required this.sigycop,
    this.observations,
    this.tailleCm,
    this.poidsKg,
    this.ptmCm,
    this.pignet,
    this.tensionArterielle,
    this.pouls,
    this.vod,
    this.vog,
    this.aod,
    this.aog,
    this.urineSucre,
    this.urineAlbumine,
    this.clinique,
  });

  final String id;
  final String visiteId;
  final String apprenantId;
  final VisiteResultat resultat;
  final String? observations;

  /// Taille en centimètres, poids en kilogrammes, périmètre thoracique
  /// moyen en centimètres.
  final num? tailleCm;
  final num? poidsKg;
  final num? ptmCm;

  /// Indice de Pignet — colonne calculée côté base à partir des trois
  /// mensurations ci-dessus, jamais saisie directement.
  final num? pignet;

  final String? tensionArterielle;
  final int? pouls;
  final String? vod;
  final String? vog;
  final String? aod;
  final String? aog;
  final String? urineSucre;
  final String? urineAlbumine;
  final String? clinique;

  /// Cotation SIGYCOP, lettre par lettre — une lettre absente n'a pas été
  /// cotée.
  final Map<SigycopLettre, int> sigycop;

  /// Profil complet sous sa forme usuelle (ex. « 2 1 1 2 1 1 1 »), ou
  /// `null` tant que les sept lettres ne sont pas toutes cotées.
  String? get sigycopProfil {
    if (sigycop.length != SigycopLettre.values.length) return null;
    return SigycopLettre.values.map((l) => sigycop[l]).join(' ');
  }

  factory VisiteMedicaleApprenant.fromJson(Map<String, dynamic> json) {
    final sigycop = <SigycopLettre, int>{};
    for (final lettre in SigycopLettre.values) {
      final cote = json['sigycop_${lettre.name}'] as int?;
      if (cote != null) sigycop[lettre] = cote;
    }
    return VisiteMedicaleApprenant(
      id: json['id'] as String,
      visiteId: json['visite_id'] as String,
      apprenantId: json['apprenant_id'] as String,
      resultat: visiteResultatFromString(json['resultat'] as String? ?? 'apte'),
      observations: json['observations'] as String?,
      tailleCm: json['taille_cm'] as num?,
      poidsKg: json['poids_kg'] as num?,
      ptmCm: json['ptm_cm'] as num?,
      pignet: json['pignet'] as num?,
      tensionArterielle: json['tension_arterielle'] as String?,
      pouls: json['pouls'] as int?,
      vod: json['vod'] as String?,
      vog: json['vog'] as String?,
      aod: json['aod'] as String?,
      aog: json['aog'] as String?,
      urineSucre: json['urine_sucre'] as String?,
      urineAlbumine: json['urine_albumine'] as String?,
      clinique: json['clinique'] as String?,
      sigycop: sigycop,
    );
  }
}
