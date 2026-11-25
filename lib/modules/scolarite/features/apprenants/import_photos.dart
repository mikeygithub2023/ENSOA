// Le rapprochement des photos : à qui appartient ce fichier.
//
// Poser 256 photos une par une, c'est ouvrir 256 fiches. L'école a ses
// photos dans un dossier, nommées par matricule ou par numéro
// mécanographique — c'est ainsi qu'elles sortent du fichier de la DORH et
// des scanners du bureau. Le rapprochement se fait donc sur le nom du
// fichier, et rien d'autre : aucune ressemblance de visage, aucune
// supposition.
//
// POURQUOI UN FICHIER SÉPARÉ DU DIALOGUE. Désigner la mauvaise personne,
// c'est mettre le visage d'un homme sur la fiche d'un autre — et la
// prochaine prise d'armes appellera le mauvais nom. Cette règle-là doit
// pouvoir être éprouvée sans interface : elle l'est dans
// `test/import_photos_test.dart`.

import '../../models/apprenant.dart';

/// Les accents que portent les noms de l'école, repliés sur leur lettre
/// nue. Même table que les imports du parc et de l'armement : un nom de
/// fichier tapé « DIABATÉ » doit retrouver la fiche « DIABATE ».
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

/// La clé d'identité d'une chaîne : majuscules, sans accents, sans rien
/// que des lettres et des chiffres.
///
/// « 001 06 0467 », « 001-06-0467 » et « 001060467 » désignent le même
/// matricule ; « N'GUESSAN » et « NGUESSAN », le même homme. Les trois
/// identifiants que porte un militaire s'écrivent avec des espaces dans
/// l'état nominatif et sans dans les noms de fichiers — comparer le texte
/// brut ne rapprocherait rien.
String normaliserCle(String brut) {
  var r = brut.toLowerCase();
  _accents.forEach((a, b) => r = r.replaceAll(a, b));
  return r.replaceAll(RegExp(r'[^a-z0-9]'), '').toUpperCase();
}

/// Le nom d'un fichier débarrassé de son extension et des suffixes que les
/// systèmes ajoutent d'eux-mêmes.
///
/// Windows écrit « 39287 (1).jpg » quand le même fichier est copié deux
/// fois, et un appareil photo « 39287 - Copie.jpg ». Sans cette coupe, la
/// clé devient « 392871 » et le fichier ne retrouve personne — alors que
/// c'est bien la photo du mécano 39287.
String baseDuFichier(String nomFichier) {
  var base = nomFichier;
  final point = base.lastIndexOf('.');
  if (point > 0) base = base.substring(0, point);
  base = base.replaceAll(RegExp(r'\s*\(\d+\)\s*$'), '');
  base = base.replaceAll(
    RegExp(r'\s*-?\s*cop(ie|y)\s*$', caseSensitive: false),
    '',
  );
  return base.trim();
}

/// Tout ce par quoi un fichier peut désigner ce militaire.
///
/// Les trois identifiants, et le nom complet — parce qu'un bureau qui
/// scanne des photos les nomme aussi bien « KOUAME KOUASSI CELESTIN.jpg »
/// que « 33137.jpg ».
Set<String> clesDuMilitaire(Apprenant a) {
  final cles = <String>{};
  for (final brut in [
    a.matricule,
    a.matriculeSolde,
    a.numeroMecano,
    a.nomComplet,
  ]) {
    if (brut == null) continue;
    final cle = normaliserCle(brut);
    if (cle.isNotEmpty) cles.add(cle);
  }
  return cles;
}

/// Pourquoi un fichier n'a trouvé personne.
enum MotifNonRapproche {
  /// Aucun militaire de la portée ne porte cet identifiant ni ce nom.
  introuvable,

  /// Deux militaires au moins y répondent — deux homonymes, ou le même
  /// homme saisi deux fois. On ne devine pas lequel.
  ambigu,

  /// Le fichier dépasse ce que le dépôt de l'école accepte.
  tropLourd,
}

String libelleDuMotif(MotifNonRapproche motif) => switch (motif) {
  MotifNonRapproche.introuvable => 'Aucun militaire de cette liste',
  MotifNonRapproche.ambigu => 'Plusieurs militaires y répondent',
  MotifNonRapproche.tropLourd => 'Fichier trop lourd',
};

/// Le poids maximal d'une photo, en octets.
///
/// Le dépôt de l'école n'est pas sans fond : 256 photos sorties d'un
/// téléphone sans réduction suffiraient à le remplir. Trois mégaoctets
/// laissent passer un scan confortable et arrêtent la photo brute de
/// douze mégapixels.
const int poidsMaxPhoto = 3 * 1024 * 1024;

/// Un fichier choisi et ce qu'il est devenu.
class RapprochementPhoto {
  const RapprochementPhoto.trouve({
    required this.fichier,
    required this.octets,
    required Apprenant this.apprenant,
  }) : motif = null;

  const RapprochementPhoto.manque({
    required this.fichier,
    required this.octets,
    required MotifNonRapproche this.motif,
  }) : apprenant = null;

  /// Le nom du fichier, tel que l'utilisateur le voit dans son dossier.
  final String fichier;

  /// Son poids, pour l'annoncer avant l'envoi.
  final int octets;

  /// Le militaire désigné, quand il n'y a pas de doute.
  final Apprenant? apprenant;

  /// Pourquoi il n'en désigne aucun, sinon.
  final MotifNonRapproche? motif;

  bool get estTrouve => apprenant != null;

  /// Cette photo en remplacerait une déjà posée.
  bool get remplaceUnePhoto => apprenant?.photoPath != null;
}

/// Un fichier à rapprocher : son nom et son poids.
///
/// Les octets ne passent pas ici — le rapprochement ne les regarde pas, et
/// les faire traverser une fonction pure obligerait à charger tout le
/// dossier en mémoire pour l'éprouver.
class FichierPhoto {
  const FichierPhoto(this.nom, this.octets);
  final String nom;
  final int octets;
}

/// Rapproche chaque fichier d'un militaire de [effectif], par son nom.
///
/// L'ordre de sortie suit celui des fichiers : l'utilisateur relit sa
/// propre liste. Les doublons d'identité dans [effectif] — deux fiches
/// pour le même matricule — rendent la clé ambiguë plutôt que d'en
/// choisir une : mieux vaut une photo non posée qu'une photo mal posée.
List<RapprochementPhoto> rapprocherLesPhotos({
  required List<FichierPhoto> fichiers,
  required List<Apprenant> effectif,
}) {
  final parCle = <String, Set<String>>{};
  final parId = <String, Apprenant>{};
  for (final a in effectif) {
    parId[a.id] = a;
    for (final cle in clesDuMilitaire(a)) {
      parCle.putIfAbsent(cle, () => <String>{}).add(a.id);
    }
  }

  final resultats = <RapprochementPhoto>[];
  for (final f in fichiers) {
    if (f.octets > poidsMaxPhoto) {
      resultats.add(
        RapprochementPhoto.manque(
          fichier: f.nom,
          octets: f.octets,
          motif: MotifNonRapproche.tropLourd,
        ),
      );
      continue;
    }
    final cle = normaliserCle(baseDuFichier(f.nom));
    final ids = cle.isEmpty ? null : parCle[cle];
    if (ids == null || ids.isEmpty) {
      resultats.add(
        RapprochementPhoto.manque(
          fichier: f.nom,
          octets: f.octets,
          motif: MotifNonRapproche.introuvable,
        ),
      );
    } else if (ids.length > 1) {
      resultats.add(
        RapprochementPhoto.manque(
          fichier: f.nom,
          octets: f.octets,
          motif: MotifNonRapproche.ambigu,
        ),
      );
    } else {
      resultats.add(
        RapprochementPhoto.trouve(
          fichier: f.nom,
          octets: f.octets,
          apprenant: parId[ids.first]!,
        ),
      );
    }
  }
  return resultats;
}

/// Deux fichiers qui désignent le même militaire : le second écraserait le
/// premier sans qu'on sache lequel est resté.
///
/// Rendu à part du rapprochement, qui juge chaque fichier isolément.
/// L'écran le signale avant l'envoi — c'est une erreur de dossier, pas une
/// erreur de nommage, et elle se corrige en retirant le fichier en trop.
Set<String> militairesServisDeuxFois(List<RapprochementPhoto> rapprochements) {
  final vus = <String>{};
  final doubles = <String>{};
  for (final r in rapprochements) {
    final id = r.apprenant?.id;
    if (id == null) continue;
    if (!vus.add(id)) doubles.add(id);
  }
  return doubles;
}

/// Un poids, dit comme on le dit.
String formatPoids(int octets) {
  if (octets >= 1024 * 1024) {
    return '${(octets / (1024 * 1024)).toStringAsFixed(1)} Mo';
  }
  if (octets >= 1024) return '${(octets / 1024).round()} Ko';
  return '$octets o';
}
