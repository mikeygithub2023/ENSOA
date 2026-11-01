/// Reconnaissance des exceptions réseau de bas niveau, sans dépendre de
/// `dart:io` partout.
///
/// Les types `SocketException`, `HttpException` et `HandshakeException`
/// viennent de `dart:io`, qui n'existe pas sur le web : importer la
/// bibliothèque là-bas empêche la compilation. On la cantonne donc à une seule
/// implémentation, choisie à la compilation — la vraie sur le poste de travail
/// et la tablette (`exceptions_reseau_io.dart`), un stub sur le web
/// (`exceptions_reseau_stub.dart`) où l'on s'en remet au repli par texte,
/// déjà présent dans `erreurs.dart`.
library;

export 'exceptions_reseau_stub.dart'
    if (dart.library.io) 'exceptions_reseau_io.dart';
