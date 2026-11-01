import 'package:pdf/widgets.dart' as pw;

/// Pendant web : pas de système de fichiers dans le navigateur, donc pas
/// d'Arial installée à lire. On renvoie `null` et le thème retombe sur Roboto,
/// embarquée dans les ressources et redistribuable. Voir `pdf_fonts.dart`.
Future<pw.ThemeData?> arialDeWindows() async => null;
