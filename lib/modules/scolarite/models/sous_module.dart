/// Ce qui distingue un sous-module ordinaire d'une séance sportive : la
/// provenance de sa note.
enum NatureSousModule {
  /// La note est saisie par l'instructeur, comme partout ailleurs.
  note,

  /// La note est calculée depuis une performance et le barème de l'activité
  /// — c'est une séance du module Sport.
  sport,
}

NatureSousModule natureSousModuleFromString(String? value) =>
    value == 'sport' ? NatureSousModule.sport : NatureSousModule.note;

extension NatureSousModuleValue on NatureSousModule {
  String get value => this == NatureSousModule.sport ? 'sport' : 'note';

  String get label =>
      this == NatureSousModule.sport ? 'Séance sportive' : 'Sous-module';
}

/// Un sous-module d'un module de la phase, avec son coefficient.
///
/// La note du module est la moyenne pondérée de ses sous-modules — c'est
/// désormais la seule façon dont un module reçoit une note. Les séances du
/// module Sport en sont aussi : leur coefficient vaut toujours 1, puisque
/// toutes les séances pèsent le même poids.
class SousModule {
  const SousModule({
    required this.id,
    required this.moduleId,
    required this.nom,
    required this.coefficient,
    required this.nature,
    this.ordre = 0,
  });

  final String id;
  final String moduleId;
  final String nom;
  final num coefficient;
  final NatureSousModule nature;
  final int ordre;

  bool get estSeance => nature == NatureSousModule.sport;

  factory SousModule.fromJson(Map<String, dynamic> json) {
    return SousModule(
      id: json['id'] as String,
      moduleId: json['module_id'] as String,
      nom: json['nom'] as String,
      coefficient: json['coefficient'] as num? ?? 1,
      nature: natureSousModuleFromString(json['nature'] as String?),
      ordre: json['ordre'] as int? ?? 0,
    );
  }
}

/// L'unité dans laquelle se mesure une activité sportive.
enum UniteEpreuve { secondes, metres, repetitions, points }

UniteEpreuve uniteEpreuveFromString(String? value) => switch (value) {
  'metres' => UniteEpreuve.metres,
  'repetitions' => UniteEpreuve.repetitions,
  'points' => UniteEpreuve.points,
  _ => UniteEpreuve.secondes,
};

extension UniteEpreuveLabel on UniteEpreuve {
  String get value => name;

  String get label => switch (this) {
    UniteEpreuve.secondes => 'Temps (secondes)',
    UniteEpreuve.metres => 'Distance (mètres)',
    UniteEpreuve.repetitions => 'Répétitions',
    UniteEpreuve.points => 'Points',
  };

  String get abreviation => switch (this) {
    UniteEpreuve.secondes => 's',
    UniteEpreuve.metres => 'm',
    UniteEpreuve.repetitions => 'rép.',
    UniteEpreuve.points => 'pts',
  };

  /// Une performance chronométrée se lit « 12′30″ », pas « 750 s ».
  String formater(num valeur) {
    if (this != UniteEpreuve.secondes) {
      final entier = valeur == valeur.roundToDouble();
      return '${entier ? valeur.toInt() : valeur.toStringAsFixed(1)} '
          '$abreviation';
    }
    final total = valeur.round();
    final minutes = total ~/ 60;
    final secondes = total % 60;
    if (minutes == 0) return '$secondes s';
    return '$minutes′${secondes.toString().padLeft(2, '0')}″';
  }
}

/// Le sens de l'activité : au 3000 mètres la meilleure performance est la
/// plus petite, à la traction la plus grande.
enum SensEpreuve { minimum, maximum }

SensEpreuve sensEpreuveFromString(String? value) =>
    value == 'maximum' ? SensEpreuve.maximum : SensEpreuve.minimum;

extension SensEpreuveLabel on SensEpreuve {
  String get value => name;

  String get label => switch (this) {
    SensEpreuve.minimum => 'La plus petite valeur est la meilleure',
    SensEpreuve.maximum => 'La plus grande valeur est la meilleure',
  };
}

/// Une activité sportive du catalogue de l'école — le 3000 mètres, la
/// traction, la corde — avec l'unité dans laquelle elle se mesure et le
/// sens de cette mesure.
///
/// Elle se paramètre une fois pour toute l'école (Matières › Activités
/// sportives), barème compris, puis chaque phase la convoque autant de fois
/// qu'elle veut par des séances.
class ActiviteSportive {
  const ActiviteSportive({
    required this.id,
    required this.nom,
    required this.unite,
    required this.meilleur,
    this.consigne,
  });

  final String id;
  final String nom;
  final UniteEpreuve unite;
  final SensEpreuve meilleur;

  /// Les conditions de l'activité, telles qu'on les dicte avant le départ.
  final String? consigne;

  factory ActiviteSportive.fromJson(Map<String, dynamic> json) {
    return ActiviteSportive(
      id: json['id'] as String,
      nom: json['nom'] as String,
      unite: uniteEpreuveFromString(json['unite'] as String?),
      meilleur: sensEpreuveFromString(json['meilleur'] as String?),
      consigne: json['consigne'] as String?,
    );
  }
}

/// Une séance sportive : une activité du catalogue, passée devant une phase
/// un jour donné. C'est un sous-module du module Sport — d'où la clé
/// primaire partagée.
class SeanceSportive {
  const SeanceSportive({
    required this.sousModuleId,
    required this.activiteId,
    required this.dateSeance,
  });

  final String sousModuleId;
  final String activiteId;
  final DateTime dateSeance;

  factory SeanceSportive.fromJson(Map<String, dynamic> json) {
    return SeanceSportive(
      sousModuleId: json['sous_module_id'] as String,
      activiteId: json['activite_id'] as String,
      dateSeance: DateTime.parse(json['date_seance'] as String),
    );
  }
}

/// Un palier du barème d'une activité : « cette performance vaut cette
/// note », pour ce sexe.
class BaremePalier {
  const BaremePalier({
    required this.id,
    required this.activiteId,
    required this.sexe,
    required this.performance,
    required this.note,
  });

  final String id;
  final String activiteId;
  final String sexe;
  final num performance;
  final num note;

  factory BaremePalier.fromJson(Map<String, dynamic> json) {
    return BaremePalier(
      id: json['id'] as String,
      activiteId: json['activite_id'] as String,
      sexe: json['sexe'] as String,
      performance: json['performance'] as num,
      note: json['note'] as num,
    );
  }
}

/// La performance réalisée par un apprenant à une séance.
///
/// [note] est calculée par la base depuis le barème de l'activité : elle
/// n'est jamais saisie, sinon le barème ne servirait à rien. La date
/// appartient à la séance, pas à la performance.
class PerformanceSportive {
  const PerformanceSportive({
    required this.id,
    required this.sousModuleId,
    required this.apprenantId,
    required this.valeur,
    this.note,
    this.notePrecedente,
    this.suppressionDemandeeLe,
    this.observations,
  });

  final String id;
  final String sousModuleId;
  final String apprenantId;
  final num valeur;
  final num? note;

  /// Ce que la note valait avant le dernier recalcul — performance
  /// corrigée, barème repris, sexe rectifié. Comme pour une note saisie,
  /// on garde la trace de ce qui a changé.
  final num? notePrecedente;

  /// Renseigné quand un non-administrateur a demandé la suppression de
  /// cette performance : elle attend une confirmation.
  final DateTime? suppressionDemandeeLe;

  final String? observations;

  /// Nulle quand l'activité n'a pas de barème pour le sexe de l'apprenant,
  /// ou quand ce sexe n'est pas renseigné. Mieux vaut pas de note qu'une
  /// note inventée — une performance en deçà du dernier palier vaut zéro,
  /// elle, pas rien (voir la migration 061).
  bool get noteConnue => note != null;

  bool get noteModifiee => notePrecedente != null;
  bool get suppressionDemandee => suppressionDemandeeLe != null;

  factory PerformanceSportive.fromJson(Map<String, dynamic> json) {
    return PerformanceSportive(
      id: json['id'] as String,
      sousModuleId: json['sous_module_id'] as String,
      apprenantId: json['apprenant_id'] as String,
      valeur: json['valeur'] as num,
      note: json['note'] as num?,
      notePrecedente: json['previous_note'] as num?,
      suppressionDemandeeLe: json['deletion_requested_at'] == null
          ? null
          : DateTime.parse(json['deletion_requested_at'] as String),
      observations: json['observations'] as String?,
    );
  }
}
