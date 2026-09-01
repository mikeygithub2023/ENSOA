/// Nature d'un document pédagogique. Un exercice d'application et un devoir
/// se décrivent comme un cours — seul leur rôle diffère, d'où une simple
/// nature plutôt que trois tables.
enum TypeRessource { cours, exercice, devoir }

const _typeRessourceDbValues = {
  TypeRessource.cours: 'cours',
  TypeRessource.exercice: 'exercice',
  TypeRessource.devoir: 'devoir',
};

TypeRessource typeRessourceFromString(String value) {
  return _typeRessourceDbValues.entries
      .firstWhere(
        (e) => e.value == value,
        orElse: () => const MapEntry(TypeRessource.cours, 'cours'),
      )
      .key;
}

extension TypeRessourceValue on TypeRessource {
  String get value => _typeRessourceDbValues[this]!;

  /// Intitulé de la rubrique, au pluriel.
  String get label => switch (this) {
    TypeRessource.cours => 'Cours',
    TypeRessource.exercice => 'Exercices d\'application',
    TypeRessource.devoir => 'Devoirs',
  };

  /// Forme singulière, pour les phrases et les boutons.
  String get singulier => switch (this) {
    TypeRessource.cours => 'cours',
    TypeRessource.exercice => 'exercice d\'application',
    TypeRessource.devoir => 'devoir',
  };

  /// Ce que la rubrique contient, en une ligne.
  String get description => switch (this) {
    TypeRessource.cours => 'Les leçons dispensées à la phase ou au stage.',
    TypeRessource.exercice =>
      'Les applications proposées à la suite d\'un cours.',
    TypeRessource.devoir => 'Les travaux à rendre, avec leur échéance.',
  };
}

/// Un document pédagogique d'une classe/stage : un cours, un exercice
/// d'application ou un devoir.
///
/// [coursId] rattache un exercice ou un devoir au cours qu'il applique — il
/// reste nul pour un cours, et peut l'être pour un exercice donné hors de
/// tout cours enregistré. [fichierPath] est le chemin de l'objet dans le
/// bucket privé, jamais une URL : celle-ci est signée à la demande.
class Cours {
  const Cours({
    required this.id,
    required this.divisionId,
    required this.classeId,
    required this.type,
    required this.titre,
    required this.createdAt,
    this.matiereId,
    this.coursId,
    this.description,
    this.dateSeance,
    this.dateRemise,
    this.dureeMinutes,
    this.fichierPath,
    this.fichierNom,
    this.createdBy,
    this.resultatsPublies = false,
  });

  final String id;
  final String divisionId;
  final String classeId;
  final TypeRessource type;
  final String titre;
  final DateTime createdAt;
  final String? matiereId;
  final String? coursId;
  final String? description;
  final DateTime? dateSeance;
  final DateTime? dateRemise;

  /// Temps imparti à un devoir, en minutes. Nul : le devoir se compose sans
  /// montre. Le compte à rebours court à partir de l'ouverture du sujet par
  /// l'élève, relevée par le serveur (voir la migration 047).
  final int? dureeMinutes;

  final String? fichierPath;
  final String? fichierNom;

  /// Auteur du dépôt — chacun modifie ou supprime ce qu'il a déposé,
  /// l'encadrement gardant la main sur sa division.
  final String? createdBy;

  /// Un devoir dont les résultats sont publiés : chaque élève voit alors sa
  /// note. Tant qu'il ne l'est pas, elle ne quitte pas le serveur — les
  /// premiers à composer en déduiraient les réponses (voir la migration 041).
  final bool resultatsPublies;

  bool get aUnDocument => fichierPath != null && fichierPath!.isNotEmpty;

  /// Le temps imparti, dit comme on le dit à l'oral : « 1 h 30 » plutôt que
  /// « 90 minutes ».
  String? get dureeLabel {
    final minutes = dureeMinutes;
    if (minutes == null) return null;
    if (minutes < 60) return '$minutes min';
    final heures = minutes ~/ 60;
    final reste = minutes % 60;
    return reste == 0
        ? '$heures h'
        : '$heures h ${reste.toString().padLeft(2, '0')}';
  }

  /// Un devoir dont l'échéance est passée — le distinguer évite de le
  /// présenter comme encore à rendre.
  bool get echeanceDepassee {
    final remise = dateRemise;
    if (remise == null) return false;
    final aujourdhui = DateTime.now();
    return remise.isBefore(
      DateTime(aujourdhui.year, aujourdhui.month, aujourdhui.day),
    );
  }

  factory Cours.fromJson(Map<String, dynamic> json) {
    return Cours(
      id: json['id'] as String,
      divisionId: json['division_id'] as String,
      classeId: json['classe_id'] as String,
      type: typeRessourceFromString(json['type'] as String? ?? 'cours'),
      titre: json['titre'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      matiereId: json['matiere_id'] as String?,
      coursId: json['cours_id'] as String?,
      description: json['description'] as String?,
      dateSeance: json['date_seance'] == null
          ? null
          : DateTime.parse(json['date_seance'] as String),
      dateRemise: json['date_remise'] == null
          ? null
          : DateTime.parse(json['date_remise'] as String),
      dureeMinutes: json['duree_minutes'] as int?,
      fichierPath: json['fichier_path'] as String?,
      fichierNom: json['fichier_nom'] as String?,
      createdBy: json['created_by'] as String?,
      resultatsPublies: json['resultats_publies'] as bool? ?? false,
    );
  }
}

/// Barème d'un QCM, fixé par l'école. Il s'applique à chaque proposition
/// cochée par l'élève : une bonne réponse cochée rapporte un point, une
/// mauvaise en retranche un, une proposition laissée de côté ne compte ni
/// pour ni contre — s'abstenir n'est pas se tromper.
///
/// Une question vaut donc autant de points qu'elle compte de bonnes
/// réponses, et la note d'un devoir — la somme de ces maxima — peut être
/// négative.
const int pointBonneReponse = 1;
const int pointMauvaiseReponse = -1;

/// Une proposition de réponse à une question de QCM. Une seule par question
/// porte [correcte] — la base le garantit.
class QcmProposition {
  const QcmProposition({
    required this.id,
    required this.questionId,
    required this.ordre,
    required this.texte,
    required this.correcte,
  });

  final String id;
  final String questionId;
  final int ordre;
  final String texte;
  final bool correcte;

  factory QcmProposition.fromJson(Map<String, dynamic> json) {
    return QcmProposition(
      id: json['id'] as String,
      questionId: json['question_id'] as String,
      ordre: json['ordre'] as int? ?? 0,
      texte: json['texte'] as String,
      correcte: json['correcte'] as bool? ?? false,
    );
  }
}

/// Une question de QCM et ses propositions, dans l'ordre voulu par son
/// auteur.
class QcmQuestion {
  const QcmQuestion({
    required this.id,
    required this.devoirId,
    required this.ordre,
    required this.enonce,
    required this.propositions,
  });

  final String id;
  final String devoirId;
  final int ordre;
  final String enonce;
  final List<QcmProposition> propositions;

  /// Les propositions justes — une question peut en compter plusieurs.
  /// Vide tant que l'auteur n'en a désigné aucune : la question est alors
  /// incomplète et ne peut pas être notée.
  List<QcmProposition> get bonnesReponses =>
      propositions.where((p) => p.correcte).toList();

  /// Points maximum de la question : autant que de bonnes réponses.
  int get bareme => bonnesReponses.length * pointBonneReponse;

  bool get estComplete => enonce.trim().isNotEmpty && bonnesReponses.isNotEmpty;

  factory QcmQuestion.fromJson(Map<String, dynamic> json) {
    final propositions =
        (json['qcm_propositions'] as List<dynamic>? ?? const [])
            .map((e) => QcmProposition.fromJson(e as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.ordre.compareTo(b.ordre));

    return QcmQuestion(
      id: json['id'] as String,
      devoirId: json['devoir_id'] as String,
      ordre: json['ordre'] as int? ?? 0,
      enonce: json['enonce'] as String,
      propositions: propositions,
    );
  }
}

/// Le résultat d'un élève à un devoir. Ces notes vivent à part des contrôles
/// et des examens : elles n'entrent pas dans les moyennes du bulletin (voir
/// `moyennes.dart`, qui ne connaît que les `controles`). Un QCM mesure
/// l'assimilation d'un cours, il ne sanctionne pas.
class ResultatDevoir {
  const ResultatDevoir({
    required this.apprenantId,
    required this.note,
    required this.bareme,
    this.terminee,
    this.horsDelai = false,
  });

  final String apprenantId;
  final int note;
  final int bareme;
  final DateTime? terminee;

  /// La copie est arrivée après le temps imparti, battement de deux minutes
  /// compris (voir la migration 047). Elle est notée comme les autres :
  /// c'est à l'instructeur d'apprécier, la base ne tranche pas à sa place.
  final bool horsDelai;

  /// Une copie ouverte mais jamais remise : l'élève a lancé le devoir puis
  /// disparu — coupure, batterie vide. Elle n'a pas de note.
  bool get enCours => terminee == null;

  /// Note ramenée sur vingt, pour se comparer aux autres évaluations. Une
  /// note négative est ramenée à zéro : on ne descend pas sous la copie
  /// blanche.
  double get sur20 {
    if (bareme <= 0) return 0;
    final valeur = note * 20 / bareme;
    return valeur < 0 ? 0 : valeur;
  }

  factory ResultatDevoir.fromJson(Map<String, dynamic> json) {
    return ResultatDevoir(
      apprenantId: json['apprenant_id'] as String,
      note: json['note'] as int? ?? 0,
      bareme: json['bareme'] as int? ?? 0,
      terminee: json['terminee_at'] == null
          ? null
          : DateTime.parse(json['terminee_at'] as String),
      horsDelai: json['hors_delai'] as bool? ?? false,
    );
  }
}
