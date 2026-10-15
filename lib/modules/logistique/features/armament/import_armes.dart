import '../../data/models/armement.dart';

/// Lecture et contrôle d'un registre d'armes, avant importation.
///
/// Tout ce qui décide — ce qui est valide, ce qui existe déjà, ce qui sera
/// écrit — vit ici, hors de l'écran : c'est la partie qu'il faut pouvoir
/// mettre à l'épreuve sans ouvrir une fenêtre ni toucher la base.

/// Une colonne du modèle, dans l'ordre exact attendu dans la feuille.
class ColonneArme {
  const ColonneArme(this.cle, this.libelle, this.format, this.exemple);
  final String cle;
  final String libelle;
  final String format;
  final String exemple;
}

/// Les lignes sont lues **par position**, pas par nom d'en-tête : un
/// fichier dont les colonnes sont dans un autre ordre importerait des
/// marquages dans la case des numéros de série sans que rien ne le signale.
const colonnesArme = <ColonneArme>[
  ColonneArme(
    'designation',
    'Désignation',
    'Obligatoire — la nature de l\'arme',
    'Fusil d\'assaut',
  ),
  ColonneArme(
    'marquage',
    'Marquage',
    'Facultatif — le marquage porté par l\'arme',
    'AK 47',
  ),
  ColonneArme(
    'numero_serie',
    'Numéro de série',
    'Obligatoire — sert à reconnaître une arme déjà enregistrée',
    '1975-A-04412',
  ),
  ColonneArme(
    'position',
    'Position actuelle',
    'Libre, facultatif — où se trouve l\'arme',
    'Armurerie',
  ),
  ColonneArme(
    'etat',
    'État',
    'En armurerie, En dotation, En maintenance, Réformée — '
        '« Bon », « En service » valent En armurerie ; « Mauvais », '
        '« En réparation » valent En maintenance ; « HS » vaut Réformée. '
        'En armurerie si vide',
    'En armurerie',
  ),
  ColonneArme('observations', 'Observations', 'Libre, facultatif', ''),
];

int indiceColonneArme(String cle) =>
    colonnesArme.indexWhere((c) => c.cle == cle);

/// Ce qu'il advient d'une ligne du fichier.
enum StatutLigneArme {
  /// Elle sera créée.
  nouveau,

  /// Une arme porte déjà ce numéro de série au registre. On ne l'écrase
  /// pas : son état et sa position sont tenus à jour ici, ceux du fichier
  /// datent de son export.
  dejaPresent,

  /// Une arme RETIRÉE du registre porte ce numéro de série.
  ///
  /// Elle ne paraît plus nulle part, mais elle existe toujours — la
  /// suppression est douce, pour que ses bons de sortie restent rattachés
  /// à quelque chose. Et la contrainte d'unicité lui réserve toujours son
  /// numéro : en créer une seconde serait refusé par la base.
  ///
  /// On la rétablit donc, avec les données du fichier.
  aRetablir,

  /// Le même numéro de série paraît plus haut dans le fichier. La première
  /// ligne est retenue, les suivantes écartées.
  doublonDansLeFichier,

  /// Il manque une donnée obligatoire, ou l'une d'elles est illisible.
  erreur,
}

class LigneArme {
  LigneArme({
    required this.numero,
    required this.valeurs,
    required this.erreurs,
    required this.statut,
    this.existante,
  });

  /// Le numéro de ligne dans la feuille, en-tête comprise — celui
  /// qu'affiche le tableur, pour qu'on puisse aller la corriger.
  final int numero;
  final List<String> valeurs;
  final List<String> erreurs;
  final StatutLigneArme statut;

  /// L'arme de la base qui porte déjà ce numéro de série.
  final Arme? existante;

  String valeur(String cle) => valeurs[indiceColonneArme(cle)].trim();
}

/// Ce qui sera écrit en base pour une ligne retenue.
class ArmeAImporter {
  const ArmeAImporter({
    required this.numeroSerie,
    required this.designation,
    required this.marquage,
    required this.etat,
    this.positionActuelle,
    this.observations,
  });

  final String numeroSerie;
  final String designation;
  final String marquage;
  final EtatArme etat;
  final String? positionActuelle;
  final String? observations;
}

/// La forme sous laquelle deux numéros de série se comparent.
///
/// « 1975-A-04412 », « 1975 A 04412 » et « 1975a04412 » désignent la même
/// arme. Comparer les chaînes telles quelles ferait entrer trois fois le
/// même fusil au registre — et la contrainte d'unicité de la base, qui
/// porte sur le texte brut, ne s'y opposerait pas.
String normaliserNumeroSerie(String brut) =>
    brut.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

const _accents = {
  'à': 'a', 'â': 'a', 'ä': 'a',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'î': 'i', 'ï': 'i',
  'ô': 'o', 'ö': 'o',
  'ù': 'u', 'û': 'u', 'ü': 'u',
  'ç': 'c',
};

String _sansAccent(String s) {
  var r = s.toLowerCase();
  _accents.forEach((a, b) => r = r.replaceAll(a, b));
  return r.replaceAll(RegExp(r'[^a-z]'), '');
}

/// Les mots du registre, tels qu'on les écrit à la main, et l'état auquel
/// chacun correspond.
///
/// Un registre d'armurerie ne dit pas « en_armurerie » : il dit « BON »,
/// « EN SERVICE », « HS ». Refuser ces mots-là obligerait à réécrire le
/// fichier avant de l'importer — et c'est précisément ce qu'on veut
/// épargner. La correspondance est donc large, mais **annoncée** : le
/// modèle téléchargeable et l'aperçu la donnent mot pour mot.
const _etatsConnus = <String, EtatArme>{
  // En armurerie — l'arme est là, en état de servir.
  'enarmurerie': EtatArme.enArmurerie,
  'armurerie': EtatArme.enArmurerie,
  'bon': EtatArme.enArmurerie,
  'bonetat': EtatArme.enArmurerie,
  'tresbon': EtatArme.enArmurerie,
  'tresbonetat': EtatArme.enArmurerie,
  'enservice': EtatArme.enArmurerie,
  'service': EtatArme.enArmurerie,
  'disponible': EtatArme.enArmurerie,
  'enstock': EtatArme.enArmurerie,
  'stock': EtatArme.enArmurerie,
  'ras': EtatArme.enArmurerie,
  // En dotation — l'arme est sortie, entre les mains de quelqu'un.
  'endotation': EtatArme.enDotation,
  'dotation': EtatArme.enDotation,
  'percue': EtatArme.enDotation,
  'percu': EtatArme.enDotation,
  'attribuee': EtatArme.enDotation,
  'attribue': EtatArme.enDotation,
  'sortie': EtatArme.enDotation,
  // En maintenance — l'arme existe mais ne sert pas en l'état.
  'enmaintenance': EtatArme.enMaintenance,
  'maintenance': EtatArme.enMaintenance,
  'enreparation': EtatArme.enMaintenance,
  'reparation': EtatArme.enMaintenance,
  'areparer': EtatArme.enMaintenance,
  'mauvais': EtatArme.enMaintenance,
  'mauvaisetat': EtatArme.enMaintenance,
  'passable': EtatArme.enMaintenance,
  'moyen': EtatArme.enMaintenance,
  'defectueuse': EtatArme.enMaintenance,
  'defectueux': EtatArme.enMaintenance,
  'atelier': EtatArme.enMaintenance,
  // Réformée — l'arme ne reviendra pas au service.
  'reforme': EtatArme.reforme,
  'reformee': EtatArme.reforme,
  'horsservice': EtatArme.reforme,
  'hs': EtatArme.reforme,
  'detruite': EtatArme.reforme,
  'detruit': EtatArme.reforme,
  'perdue': EtatArme.reforme,
  'perdu': EtatArme.reforme,
};

/// L'état d'une arme, écrit comme on l'écrit à la main.
///
/// Nul si la valeur n'est pas reconnue — et c'est alors une erreur, non un
/// repli sur « en armurerie » : une arme réformée versée au registre actif
/// est une arme qu'on croit pouvoir distribuer.
EtatArme? lireEtatArme(String brut) {
  final v = _sansAccent(brut);
  if (v.isEmpty) return EtatArme.enArmurerie;
  return _etatsConnus[v];
}

/// Confronte les lignes du fichier au registre déjà enregistré.
///
/// [brutes] : les cellules telles que lues, une liste par ligne de données
/// (l'en-tête exclue). [numeroPremiereLigne] est le numéro qu'affiche le
/// tableur pour la première d'entre elles.
///
/// [registreRetire] : les armes retirées du registre. Les omettre serait le
/// défaut le plus coûteux de cet écran — invisibles partout ailleurs, elles
/// gardent pourtant leur numéro de série, et l'import entier se ferait
/// refuser par la contrainte d'unicité sur une ligne qu'on avait annoncée
/// « à créer ».
List<LigneArme> analyserLignesArmes({
  required List<List<String>> brutes,
  required List<Arme> registreExistant,
  List<Arme> registreRetire = const [],
  int numeroPremiereLigne = 2,
}) {
  final parRegistre = {
    for (final a in registreExistant) normaliserNumeroSerie(a.numeroSerie): a,
  };
  final parRetire = {
    for (final a in registreRetire) normaliserNumeroSerie(a.numeroSerie): a,
  };
  final vuesDansLeFichier = <String>{};

  final resultat = <LigneArme>[];
  for (var i = 0; i < brutes.length; i++) {
    final valeurs = List.generate(
      colonnesArme.length,
      (c) => c < brutes[i].length ? brutes[i][c] : '',
    );
    if (valeurs.every((v) => v.trim().isEmpty)) continue;

    final erreurs = _controler(valeurs);
    final cle = normaliserNumeroSerie(
      valeurs[indiceColonneArme('numero_serie')].trim(),
    );

    StatutLigneArme statut;
    Arme? existante;
    if (erreurs.isNotEmpty) {
      statut = StatutLigneArme.erreur;
    } else if (parRegistre.containsKey(cle)) {
      statut = StatutLigneArme.dejaPresent;
      existante = parRegistre[cle];
    } else if (vuesDansLeFichier.contains(cle)) {
      // Avant le rétablissement, et non après : deux lignes pour le même
      // numéro retiré feraient deux écritures sur la même arme, la seconde
      // effaçant la première sans rien dire.
      statut = StatutLigneArme.doublonDansLeFichier;
    } else if (parRetire.containsKey(cle)) {
      statut = StatutLigneArme.aRetablir;
      existante = parRetire[cle];
      vuesDansLeFichier.add(cle);
    } else {
      statut = StatutLigneArme.nouveau;
      vuesDansLeFichier.add(cle);
    }

    resultat.add(
      LigneArme(
        numero: numeroPremiereLigne + i,
        valeurs: valeurs,
        erreurs: erreurs,
        statut: statut,
        existante: existante,
      ),
    );
  }
  return resultat;
}

List<String> _controler(List<String> valeurs) {
  final erreurs = <String>[];
  String v(String cle) => valeurs[indiceColonneArme(cle)].trim();

  if (v('designation').isEmpty) erreurs.add('Désignation manquante');
  if (v('numero_serie').isEmpty) erreurs.add('Numéro de série manquant');

  if (lireEtatArme(v('etat')) == null) {
    erreurs.add('État inconnu : « ${v('etat')} »');
  }
  return erreurs;
}

/// Ce qui sera écrit pour une ligne retenue.
ArmeAImporter construireImportArme(LigneArme ligne) {
  String? libre(String cle) =>
      ligne.valeur(cle).isEmpty ? null : ligne.valeur(cle);

  return ArmeAImporter(
    // Le numéro est mis en capitales : c'est ainsi qu'il est frappé sur la
    // carcasse, et le registre reste lisible d'une ligne à l'autre.
    numeroSerie: ligne.valeur('numero_serie').toUpperCase(),
    designation: ligne.valeur('designation'),
    marquage: ligne.valeur('marquage'),
    etat: lireEtatArme(ligne.valeur('etat'))!,
    positionActuelle: libre('position'),
    observations: libre('observations'),
  );
}
