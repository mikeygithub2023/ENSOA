import '../../data/models/vehicule.dart';

/// Lecture et contrôle d'un fichier de parc automobile, avant importation.
///
/// Tout ce qui décide — ce qui est valide, ce qui existe déjà, ce qui sera
/// écrit — vit ici, hors de l'écran : c'est la partie qu'il faut pouvoir
/// mettre à l'épreuve sans ouvrir une fenêtre ni toucher la base.

/// Une colonne du modèle, dans l'ordre exact attendu dans la feuille.
class ColonneVehicule {
  const ColonneVehicule(this.cle, this.libelle, this.format, this.exemple);
  final String cle;
  final String libelle;
  final String format;
  final String exemple;
}

/// Les lignes sont lues **par position**, pas par nom d'en-tête : un fichier
/// dont les colonnes sont dans un autre ordre importerait des châssis dans
/// la case des immatriculations sans que rien ne le signale.
const colonnesVehicule = <ColonneVehicule>[
  ColonneVehicule(
    'immatriculation',
    'Immatriculation',
    'Obligatoire — sert à reconnaître un véhicule déjà enregistré',
    '1234 AA 01',
  ),
  ColonneVehicule('chassis', 'Châssis', 'Obligatoire', 'JTEBH9FJ70K123456'),
  ColonneVehicule('marque', 'Marque', 'Obligatoire', 'Toyota'),
  ColonneVehicule('modele', 'Modèle', 'Obligatoire', 'Land Cruiser'),
  ColonneVehicule('type', 'Type', 'Obligatoire', 'Station Wagon'),
  ColonneVehicule('kilometrage', 'Kilométrage', 'Nombre — 0 si vide', '125000'),
  ColonneVehicule('places', 'Places', 'Nombre — 5 si vide', '5'),
  ColonneVehicule(
    'vidange_prochaine',
    'Prochaine vidange (km)',
    'Nombre — kilométrage + 5 000 si vide',
    '130000',
  ),
  ColonneVehicule(
    'etat',
    'État',
    'Disponible, En mission, En réparation, Hors service — Disponible si vide',
    'Disponible',
  ),
  ColonneVehicule(
    'position',
    'Position actuelle',
    'Libre, facultatif',
    'ENSOA',
  ),
  ColonneVehicule('observations', 'Observations', 'Libre, facultatif', ''),
];

int indiceColonne(String cle) =>
    colonnesVehicule.indexWhere((c) => c.cle == cle);

/// Ce qu'il advient d'une ligne du fichier.
enum StatutLigne {
  /// Elle sera créée.
  nouveau,

  /// Un véhicule porte déjà cette immatriculation dans la base. On ne
  /// l'écrase pas : le kilométrage et l'état enregistrés ici sont à jour,
  /// ceux du fichier datent de son export.
  dejaPresent,

  /// Un véhicule RETIRÉ du parc porte cette immatriculation.
  ///
  /// Il ne paraît plus nulle part, mais il existe toujours — la suppression
  /// est douce, pour que ses réparations, vidanges et mouvements restent
  /// rattachés à quelque chose. Et l'index unique lui réserve toujours sa
  /// plaque : créer un second véhicule avec la même serait refusé par la
  /// base.
  ///
  /// On le rétablit donc, avec les données du fichier. C'est ce que veut
  /// celui qui réimporte son parc : le véhicule est sur son état, il doit
  /// être au parc — et son passé le suit.
  aRetablir,

  /// La même immatriculation paraît plus haut dans le fichier. La première
  /// est retenue, les suivantes écartées.
  doublonDansLeFichier,

  /// Il manque une donnée obligatoire, ou l'une d'elles est illisible.
  erreur,
}

class LigneVehicule {
  LigneVehicule({
    required this.numero,
    required this.valeurs,
    required this.erreurs,
    required this.statut,
    this.existant,
  });

  /// Le numéro de ligne dans la feuille, en-tête comprise — celui qu'affiche
  /// le tableur, pour qu'on puisse aller la corriger.
  final int numero;
  final List<String> valeurs;
  final List<String> erreurs;
  final StatutLigne statut;

  /// Le véhicule de la base qui porte déjà cette immatriculation.
  final Vehicule? existant;

  String valeur(String cle) => valeurs[indiceColonne(cle)].trim();
}

/// Ce qui sera écrit en base pour une ligne retenue.
class VehiculeAImporter {
  const VehiculeAImporter({
    required this.immatriculation,
    required this.chassis,
    required this.marque,
    required this.modele,
    required this.type,
    required this.kilometrage,
    required this.nbrePlaces,
    required this.kilometrageVidangeProchaine,
    required this.etat,
    this.positionActuelle,
    this.observations,
  });

  final String immatriculation;
  final String chassis;
  final String marque;
  final String modele;
  final String type;
  final int kilometrage;
  final int nbrePlaces;
  final int kilometrageVidangeProchaine;
  final EtatVehicule etat;
  final String? positionActuelle;
  final String? observations;
}

/// La forme sous laquelle deux immatriculations se comparent.
///
/// « 1234 AA 01 », « 1234AA01 » et « 1234-aa-01 » désignent le même véhicule.
/// Comparer les chaînes telles quelles ferait entrer trois fois le même
/// camion dans le parc — et la contrainte d'unicité de la base, qui porte
/// sur le texte brut, ne s'y opposerait pas.
String normaliserImmatriculation(String brut) =>
    brut.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

/// Lit un nombre tel qu'un tableur l'écrit : avec des espaces de milliers,
/// parfois une décimale résiduelle (« 125000.0 »).
int? lireNombre(String brut) {
  final net = brut.replaceAll(RegExp(r'[\s ]'), '').replaceAll(',', '.');
  if (net.isEmpty) return null;
  final entier = int.tryParse(net);
  if (entier != null) return entier;
  final decimal = double.tryParse(net);
  return decimal?.round();
}

const _accents = {
  'à': 'a',
  'â': 'a',
  'ä': 'a',
  'é': 'e',
  'è': 'e',
  'ê': 'e',
  'ë': 'e',
  'î': 'i',
  'ï': 'i',
  'ô': 'o',
  'ö': 'o',
  'ù': 'u',
  'û': 'u',
  'ü': 'u',
  'ç': 'c',
};

String _sansAccent(String s) {
  var r = s.toLowerCase();
  _accents.forEach((a, b) => r = r.replaceAll(a, b));
  return r.replaceAll(RegExp(r'[^a-z]'), '');
}

/// L'état d'un véhicule, écrit comme on l'écrit à la main.
///
/// Nul si la valeur n'est pas reconnue — et c'est alors une erreur, non un
/// repli sur « disponible » : un camion hors service versé au parc
/// disponible est une mission qu'on croit pouvoir monter.
EtatVehicule? lireEtat(String brut) {
  final v = _sansAccent(brut);
  if (v.isEmpty) return EtatVehicule.disponible;
  if (v == 'disponible') return EtatVehicule.disponible;
  if (v == 'enmission' || v == 'mission') return EtatVehicule.enMission;
  if (v == 'enreparation' || v == 'reparation') {
    return EtatVehicule.enReparation;
  }
  if (v == 'horsservice' || v == 'hs') return EtatVehicule.horsService;
  return null;
}

/// Confronte les lignes du fichier au parc déjà enregistré.
///
/// [brutes] : les cellules telles que lues, une liste par ligne de données
/// (l'en-tête exclue). [numeroPremiereLigne] est le numéro qu'affiche le
/// tableur pour la première d'entre elles.
///
/// [parcRetire] : les véhicules retirés du parc. Les omettre serait le
/// défaut le plus coûteux de cet écran — invisibles partout ailleurs, ils
/// gardent pourtant leur immatriculation, et l'import entier se ferait
/// refuser par l'index unique sur une ligne qu'on avait annoncée « à
/// créer ».
List<LigneVehicule> analyserLignes({
  required List<List<String>> brutes,
  required List<Vehicule> parcExistant,
  List<Vehicule> parcRetire = const [],
  int numeroPremiereLigne = 2,
}) {
  final parParc = {
    for (final v in parcExistant)
      normaliserImmatriculation(v.immatriculation): v,
  };
  final parRetire = {
    for (final v in parcRetire) normaliserImmatriculation(v.immatriculation): v,
  };
  final vuesDansLeFichier = <String>{};

  final resultat = <LigneVehicule>[];
  for (var i = 0; i < brutes.length; i++) {
    final valeurs = List.generate(
      colonnesVehicule.length,
      (c) => c < brutes[i].length ? brutes[i][c] : '',
    );
    if (valeurs.every((v) => v.trim().isEmpty)) continue;

    final erreurs = _controler(valeurs);
    final immat = valeurs[indiceColonne('immatriculation')].trim();
    final cle = normaliserImmatriculation(immat);

    StatutLigne statut;
    Vehicule? existant;
    if (erreurs.isNotEmpty) {
      statut = StatutLigne.erreur;
    } else if (parParc.containsKey(cle)) {
      statut = StatutLigne.dejaPresent;
      existant = parParc[cle];
    } else if (vuesDansLeFichier.contains(cle)) {
      // Avant le rétablissement, et non après : deux lignes pour la même
      // plaque retirée feraient deux écritures sur le même véhicule, la
      // seconde effaçant la première sans rien dire.
      statut = StatutLigne.doublonDansLeFichier;
    } else if (parRetire.containsKey(cle)) {
      statut = StatutLigne.aRetablir;
      existant = parRetire[cle];
      vuesDansLeFichier.add(cle);
    } else {
      statut = StatutLigne.nouveau;
      vuesDansLeFichier.add(cle);
    }

    resultat.add(
      LigneVehicule(
        numero: numeroPremiereLigne + i,
        valeurs: valeurs,
        erreurs: erreurs,
        statut: statut,
        existant: existant,
      ),
    );
  }
  return resultat;
}

List<String> _controler(List<String> valeurs) {
  final erreurs = <String>[];
  String v(String cle) => valeurs[indiceColonne(cle)].trim();

  if (v('immatriculation').isEmpty) erreurs.add('Immatriculation manquante');
  if (v('chassis').isEmpty) erreurs.add('Châssis manquant');
  if (v('marque').isEmpty) erreurs.add('Marque manquante');
  if (v('modele').isEmpty) erreurs.add('Modèle manquant');
  if (v('type').isEmpty) erreurs.add('Type manquant');

  for (final c in ['kilometrage', 'places', 'vidange_prochaine']) {
    final brut = v(c);
    if (brut.isEmpty) continue;
    final n = lireNombre(brut);
    if (n == null) {
      erreurs.add(
        '${colonnesVehicule[indiceColonne(c)].libelle} : '
        '« $brut » n\'est pas un nombre',
      );
    } else if (n < 0) {
      erreurs.add('${colonnesVehicule[indiceColonne(c)].libelle} négatif');
    }
  }

  if (lireEtat(v('etat')) == null) {
    erreurs.add('État inconnu : « ${v('etat')} »');
  }
  return erreurs;
}

/// Ce qui sera écrit pour une ligne retenue. Les conventions appliquées ici
/// sont celles annoncées dans le modèle : 0 km, 5 places, et une prochaine
/// vidange à 5 000 km — l'intervalle que l'écran de saisie propose déjà.
VehiculeAImporter construireImport(LigneVehicule ligne) {
  final kilometrage = lireNombre(ligne.valeur('kilometrage')) ?? 0;
  String? libre(String cle) =>
      ligne.valeur(cle).isEmpty ? null : ligne.valeur(cle);

  return VehiculeAImporter(
    // L'immatriculation est mise en capitales : c'est ainsi qu'elle est
    // peinte sur la plaque, et le parc reste lisible d'une ligne à l'autre.
    immatriculation: ligne.valeur('immatriculation').toUpperCase(),
    chassis: ligne.valeur('chassis'),
    marque: ligne.valeur('marque'),
    modele: ligne.valeur('modele'),
    type: ligne.valeur('type'),
    kilometrage: kilometrage,
    nbrePlaces: lireNombre(ligne.valeur('places')) ?? 5,
    kilometrageVidangeProchaine:
        lireNombre(ligne.valeur('vidange_prochaine')) ?? kilometrage + 5000,
    etat: lireEtat(ligne.valeur('etat'))!,
    positionActuelle: libre('position'),
    observations: libre('observations'),
  );
}
