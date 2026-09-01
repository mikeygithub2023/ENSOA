import 'classe.dart';

/// [module] ne concerne que les classes (élèves) ; [continu] et [examen]
/// concernent les deux, avec un libellé qui varie selon le type de
/// classe/stage (voir [ControleTypeLabels]).
enum ControleType { module, sport, continu, examen }

ControleType controleTypeFromString(String value) {
  return switch (value) {
    'module' => ControleType.module,
    'sport' => ControleType.sport,
    'intermediaire' => ControleType.examen,
    _ => ControleType.continu,
  };
}

extension ControleTypeLabels on ControleType {
  /// Valeur stockée en base — inchangée pour ne pas nécessiter de migration
  /// de données malgré le renommage d'affichage ('examen' reste
  /// 'intermediaire' en base).
  String get value => switch (this) {
    ControleType.module => 'module',
    ControleType.sport => 'sport',
    ControleType.continu => 'continu',
    ControleType.examen => 'intermediaire',
  };

  /// Libellé de section/onglet ("Modules", "Contrôle continu", "Examen
  /// final" pour un stage ou "Examen" pour une classe).
  String sectionLabel(ClasseType classeType) => switch (this) {
    ControleType.module => 'Modules',
    ControleType.sport => 'Sport',
    ControleType.continu => 'Contrôle continu',
    ControleType.examen =>
      classeType == ClasseType.stage ? 'Examen final' : 'Examen',
  };

  /// Forme nominale singulière, pour les phrases ("Enregistrer un module",
  /// "Aucun examen enregistré.").
  String noun(ClasseType classeType) => switch (this) {
    ControleType.module => 'module',
    ControleType.sport => 'séance sportive',
    ControleType.continu => 'contrôle continu',
    ControleType.examen =>
      classeType == ClasseType.stage ? 'examen final' : 'examen',
  };
}

/// Évaluation (module, continu ou examen) d'une classe/stage, avec son
/// propre coefficient. [type] détermine à la fois la valeur stockée et,
/// combiné au type de classe/stage, le libellé affiché (voir
/// [ControleTypeLabels]). Un module EST une matière : [matiereId] identifie
/// celle-ci (nul pour un contrôle continu/examen, qui n'est rattaché à
/// aucune matière précise) et [libelle] reprend alors son nom.
class Controle {
  const Controle({
    required this.id,
    required this.divisionId,
    required this.classeId,
    required this.type,
    required this.libelle,
    required this.coefficient,
    this.matiereId,
    this.inclusBulletin = false,
  });

  final String id;
  final String divisionId;
  final String classeId;
  final ControleType type;
  final String libelle;
  final num coefficient;
  final String? matiereId;

  /// Coché par l'administrateur (menu "Bulletins") pour que ce contrôle
  /// entre dans le calcul des bulletins — voir [ControlesRepository.setInclusBulletin].
  final bool inclusBulletin;

  factory Controle.fromJson(Map<String, dynamic> json) {
    return Controle(
      id: json['id'] as String,
      divisionId: json['division_id'] as String,
      classeId: json['classe_id'] as String,
      type: controleTypeFromString(json['type'] as String? ?? 'continu'),
      libelle: json['libelle'] as String? ?? '',
      coefficient: json['coefficient'] as num,
      matiereId: json['matiere_id'] as String?,
      inclusBulletin: json['inclus_bulletin'] as bool? ?? false,
    );
  }
}

extension ControleLibelleQualifie on Controle {
  /// Le libellé de l'évaluation, suivi de sa nature quand celle-ci ne se
  /// devine pas au nom.
  ///
  /// Sans cette mention, une liste d'évaluations mêle sans les distinguer
  /// une note de module — moyenne de ses sous-modules — et une note de
  /// contrôle ou d'examen, portée par des matières. Or les deux ne se
  /// forment pas de la même façon. Un module reprend le nom de sa matière,
  /// « Transmissions » ne dit donc pas s'il s'agit du module ou du contrôle.
  ///
  /// Le Sport n'a pas besoin de la mention : il ne porte pas de nom de
  /// matière et ne se confond avec rien.
  String get libelleQualifie => switch (type) {
    ControleType.module => '$libelle (module)',
    ControleType.sport ||
    ControleType.continu ||
    ControleType.examen => libelle,
  };
}
