import 'dart:io';

/// Vrai pour les exceptions réseau de bas niveau de `dart:io` : coupure de
/// connexion, échec de résolution DNS, poignée de main TLS ratée. Sert à dire
/// à l'utilisateur « le serveur est hors d'atteinte, réessayez » plutôt que de
/// lui montrer le message brut.
bool estExceptionReseauBasNiveau(Object erreur) =>
    erreur is SocketException ||
    erreur is HttpException ||
    erreur is HandshakeException;

/// Vrai pour une coupure de socket nue. La reprise d'une requête ne vaut que
/// pour celle-là, et à elle seule — voir `reprise.dart`.
bool estCoupureSocket(Object erreur) => erreur is SocketException;
