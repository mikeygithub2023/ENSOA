import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/widgets.dart' as pw;

/// Arial lue dans le dossier des polices de Windows. Ses chasses sont celles
/// d'Helvetica, contre laquelle les documents ont été mis en page : le texte
/// occupe exactement la même place. Elle appartient à Microsoft — on la lit
/// là où elle est installée plutôt que de la redistribuer.
///
/// Renvoie `null` hors de Windows (la tablette), ou si les fichiers manquent :
/// l'appelant retombe alors sur Roboto embarquée.
Future<pw.ThemeData?> arialDeWindows() async {
  if (!Platform.isWindows) return null;
  try {
    final dossier =
        '${Platform.environment['WINDIR'] ?? r'C:\Windows'}'
        r'\Fonts';
    return pw.ThemeData.withFont(
      base: await _policeDuDisque('$dossier\\arial.ttf'),
      bold: await _policeDuDisque('$dossier\\arialbd.ttf'),
      italic: await _policeDuDisque('$dossier\\ariali.ttf'),
      boldItalic: await _policeDuDisque('$dossier\\arialbi.ttf'),
    );
  } catch (_) {
    return null;
  }
}

Future<pw.Font> _policeDuDisque(String chemin) async {
  final octets = await File(chemin).readAsBytes();
  return pw.Font.ttf(ByteData.view(octets.buffer));
}
