/// Ce qu'une cellule de fichier veut dire.
///
/// Un classeur de renseignement n'arrive jamais normalisé : la taille s'y
/// écrit « 1,73 M » ou « 173 », le groupe sanguin « o+ » ou « O +  », la
/// situation matrimoniale « CELIBATAIRE SANS ENFANT ». Ces fonctions
/// ramènent tout cela à ce que la fiche de l'apprenant sait porter.
///
/// Règle commune : devant une valeur qu'on ne comprend pas, on rend `null`
/// plutôt que de trancher. Une case vide se complète ; une case fausse se
/// croit.
library;

/// Sans accents ni casse : « MARIE » et « Marié(e) » désignent la même
/// situation.
String aplatir(String valeur) {
  const accents = {
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
  final tampon = StringBuffer();
  for (final rune in valeur.trim().toLowerCase().runes) {
    final caractere = String.fromCharCode(rune);
    tampon.write(accents[caractere] ?? caractere);
  }
  return tampon.toString();
}

/// Le sexe attendu est « M » ou « F ». On accepte les formes courantes
/// — « m », « Masculin », « H », « Homme », « f », « Féminin » — parce qu'un
/// fichier vient rarement normalisé, et on laisse vide plutôt que de
/// trancher : mieux vaut une fiche à compléter qu'un barème sportif
/// appliqué au mauvais sexe.
String? sexeDepuisCellule(String valeur) {
  final v = aplatir(valeur);
  if (v.isEmpty) return null;
  if (v.startsWith('m') || v.startsWith('h')) return 'M';
  if (v.startsWith('f')) return 'F';
  return null;
}

/// La situation matrimoniale est une liste fermée dans la fiche : on y
/// ramène ce que le fichier dit. « CELIBATAIRE SANS ENFANT » est une
/// célibataire — le nombre d'enfants a sa propre colonne.
///
/// L'état nominatif de la DORH ne l'écrit pas en mots mais en codes : CEL,
/// M, V, CCB. Ils se lisent ici aussi, exactement — « M » seul ne commence
/// pas par « marie », et sans cette table 60 militaires mariés arrivaient
/// sans situation.
String? situationDepuisCellule(String valeur) {
  final v = aplatir(valeur);
  if (v.isEmpty) return null;
  const codes = {
    'cel': 'Célibataire',
    'm': 'Marié(e)',
    'v': 'Veuf(ve)',
    'd': 'Divorcé(e)',
    'ccb': 'Concubinage',
  };
  final code = codes[v];
  if (code != null) return code;
  if (v.startsWith('celibataire')) return 'Célibataire';
  if (v.startsWith('marie')) return 'Marié(e)';
  if (v.startsWith('divorce')) return 'Divorcé(e)';
  if (v.startsWith('veu')) return 'Veuf(ve)';
  if (v.startsWith('concub')) return 'Concubinage';
  return null;
}

/// Les situations que la fiche sait porter, dans l'ordre où elles se
/// proposent.
///
/// « Concubinage » n'était pas de la liste : la fiche signalétique de
/// l'école n'en parlait pas. L'état nominatif de la DORH, lui, le compte —
/// 80 militaires de l'école sur 255 — et c'est une situation à part, qui ne
/// se range ni chez les célibataires ni chez les mariés.
const List<String> situationsMatrimoniales = [
  'Célibataire',
  'Marié(e)',
  'Concubinage',
  'Divorcé(e)',
  'Veuf(ve)',
];

/// Le patronyme et les prénoms, tirés d'une seule cellule.
///
/// L'état nominatif de la DORH ne tient qu'une colonne « NOM ET PRENOMS »,
/// et rien n'y marque où le nom s'arrête : « DJAMA DJAMA YANNICK JOCELYN »
/// porte un patronyme de deux mots, « EDI FABRICE » d'un seul. Le nom du
/// père, qui a sa propre colonne, le dit : le fils de « DJAMA DJAMA
/// FELICIEN » s'appelle DJAMA DJAMA, celui d'« EDI KOUASSI BARTHELEMY »
/// s'appelle EDI. On prend donc les mots que les deux cellules ont en
/// commun au début — deux au plus, un patronyme n'en compte pas trois.
///
/// Quand le père ne dit rien — « PND », ou son nom écrit dans l'autre sens,
/// comme « SIRIKI ALI » pour « ALI GNAMIEN KOUAKOU » —, le premier mot fait
/// le nom, selon l'usage militaire.
///
/// Recollés, nom et prénoms rendent exactement la cellule d'origine : rien
/// ne se perd, et une coupure malheureuse se corrige sur la fiche.
({String nom, String prenoms}) couperNomEtPrenoms(String complet, String pere) {
  final mots = _mots(complet);
  if (mots.isEmpty) return (nom: '', prenoms: '');
  if (mots.length == 1) return (nom: mots.first, prenoms: '');

  final motsPere = _mots(pere);
  var n = 0;
  while (n < mots.length - 1 &&
      n < motsPere.length &&
      n < 2 &&
      mots[n].toUpperCase() == motsPere[n].toUpperCase()) {
    n++;
  }
  if (n == 0) n = 1;

  return (nom: mots.take(n).join(' '), prenoms: mots.skip(n).join(' '));
}

List<String> _mots(String valeur) =>
    valeur.trim().split(RegExp(r'\s+')).where((m) => m.isNotEmpty).toList();

const Set<String> groupesSanguins = {
  'A+',
  'A-',
  'B+',
  'B-',
  'AB+',
  'AB-',
  'O+',
  'O-',
};

/// Un groupe sanguin hors de la liste n'est pas un groupe sanguin : on ne
/// l'invente pas. « o +  » et « O+ » sont le même, en revanche, et le zéro
/// se tape souvent à la place du O.
String? groupeSanguinDepuisCellule(String valeur) {
  final v = valeur
      .replaceAll(RegExp(r'\s+'), '')
      .toUpperCase()
      .replaceAll('0', 'O');
  if (v.isEmpty) return null;
  return groupesSanguins.contains(v) ? v : null;
}

/// Le premier nombre de la cellule, virgule ou point. « 68 KG » vaut 68.
num? premierNombre(String valeur) {
  final m = RegExp(r'(\d+(?:[.,]\d+)?)').firstMatch(valeur);
  if (m == null) return null;
  return num.tryParse(m.group(1)!.replaceAll(',', '.'));
}

/// La taille en centimètres. Les fiches de l'école l'écrivent aussi bien
/// « 173 » que « 1,73 M » : sous trois, c'est que la cellule parle en
/// mètres — personne ne mesure deux centimètres.
num? tailleDepuisCellule(String valeur) {
  final nombre = premierNombre(valeur);
  if (nombre == null) return null;
  return nombre < 3 ? (nombre * 100).round() : nombre;
}

/// Le premier entier de la cellule. « SANS ENFANT » n'en porte aucun : la
/// case reste vide, et non zéro — on ne sait pas, on ne dit pas.
int? entierDepuisCellule(String valeur) {
  final m = RegExp(r'(\d+)').firstMatch(valeur);
  return m == null ? null : int.tryParse(m.group(1)!);
}

/// Un militaire que l'état nominatif porte dans une autre unité que l'école
/// y a été reversé. Une cellule vide ne dit rien : on ne reverse personne
/// sur un oubli.
bool estReverse(String unite) {
  final u = unite.trim().toUpperCase();
  return u.isNotEmpty && u != 'ENSOA';
}
