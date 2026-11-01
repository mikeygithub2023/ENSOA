/// Charge Arial depuis les polices installées de Windows, pour que les
/// documents imprimés gardent la mise en page dessinée contre Helvetica.
///
/// Cantonnée derrière un import conditionnel : la lecture d'un fichier passe
/// par `dart:io`, absent du web. Sur le web (`pdf_arial_stub.dart`) comme sur
/// la tablette, la fonction renvoie `null` et le thème retombe sur Roboto,
/// embarquée dans les ressources. Voir `pdf_fonts.dart`.
library;

export 'pdf_arial_stub.dart' if (dart.library.io) 'pdf_arial_io.dart';
