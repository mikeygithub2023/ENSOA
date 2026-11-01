import 'dart:math';

import 'exceptions_reseau.dart';

/// Rejoue une requête une fois lorsque la connexion a été coupée avant
/// qu'aucune réponse n'arrive.
///
/// Le client HTTP garde ses connexions ouvertes entre deux requêtes pour ne
/// pas refaire la poignée de main à chaque appel. Le serveur, lui, ferme
/// celles qui dorment. Quand l'utilisateur passe une minute à remplir un
/// formulaire puis valide, la connexion réutilisée a souvent déjà été
/// fermée à l'autre bout : la requête part dans le vide et échoue sur
/// « Connection closed before full header was received ».
///
/// Dans ce cas, le serveur n'a rien lu ni rien exécuté : rejouer la requête
/// est sans danger. C'est la raison pour laquelle la reprise est réservée à
/// cette erreur-là, et à elle seule — une requête qui a reçu ne serait-ce
/// qu'un début de réponse a pu être appliquée, et la rejouer créerait un
/// doublon.
///
/// Une seule reprise : si la deuxième tentative échoue aussi, le problème
/// n'est plus la connexion qui dort, et l'utilisateur doit le savoir.
Future<T> avecReprise<T>(Future<T> Function() action) async {
  try {
    return await action();
  } catch (erreur) {
    if (!_estConnexionDormante(erreur)) rethrow;
    return action();
  }
}

bool _estConnexionDormante(Object erreur) {
  if (estCoupureSocket(erreur)) return true;
  if (erreur.runtimeType.toString() != 'ClientException') return false;
  final texte = erreur.toString().toLowerCase();
  return texte.contains('connection closed before full header') ||
      texte.contains('connection reset by peer') ||
      texte.contains('software caused connection abort');
}

final _alea = Random.secure();

/// Identifiant UUID v4 engendré côté client.
///
/// Il permet d'insérer une ligne sans redemander son identifiant au serveur
/// — un aller-retour de moins — et surtout rend l'insertion rejouable : si
/// la requête est reprise alors qu'elle avait malgré tout abouti, la clé
/// primaire refuse le doublon au lieu de créer une seconde ligne en
/// silence.
String nouvelIdentifiant() {
  final octets = List<int>.generate(16, (_) => _alea.nextInt(256));
  // Version 4, variante RFC 4122.
  octets[6] = (octets[6] & 0x0f) | 0x40;
  octets[8] = (octets[8] & 0x3f) | 0x80;

  final hex = octets.map((o) => o.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}
