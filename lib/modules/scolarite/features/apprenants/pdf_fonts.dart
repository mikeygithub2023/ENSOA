import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/widgets.dart' as pw;

/// Thème typographique commun à tous les documents imprimés : Arial,
/// embarquée dans le PDF.
///
/// Les polices intégrées au format PDF (Helvetica & consorts) ne couvrent
/// qu'un jeu de caractères restreint : le tiret cadratin « — », l'apostrophe
/// typographique « ’ » ou les points de suspension « … » s'y impriment en
/// carré vide, aussi bien dans les libellés fixes que dans le texte saisi
/// par l'utilisateur. Embarquer une vraie police règle le problème à la
/// source.
///
/// Arial de préférence à toute autre : ses chasses sont celles d'Helvetica,
/// la police contre laquelle les documents ont été mis en page. Le texte
/// occupe donc exactement la même place qu'avant — rien ne se décale, rien
/// ne déborde —, seuls les carrés vides disparaissent. Une police plus large
/// (Verdana, dessinée pour l'écran) ferait grossir les cellules des tableaux
/// et menacerait le bulletin, qui tient sur une page unique et non paginée.
///
/// Elle est lue dans les polices installées de Windows plutôt qu'embarquée
/// dans les ressources du programme : elle appartient à Microsoft et est
/// présente sur toute machine Windows — la seule plateforme visée par
/// l'application —, la redistribuer n'aurait donc pas lieu d'être. Si elle
/// venait à manquer, les documents restent imprimables avec les polices
/// intégrées au PDF (le thème vaut alors `null`), au prix des carrés vides
/// d'origine.
///
/// Le chargement (plusieurs mégaoctets de fichiers) n'a lieu qu'une fois par
/// exécution : le résultat est mémorisé, y compris l'échec.
Future<pw.ThemeData?> chargerThemePdf() async {
  if (_charge) return _theme;
  _charge = true;
  try {
    final dossier =
        '${Platform.environment['WINDIR'] ?? r'C:\Windows'}'
        r'\Fonts';
    _theme = pw.ThemeData.withFont(
      base: await _police('$dossier\\arial.ttf'),
      bold: await _police('$dossier\\arialbd.ttf'),
      italic: await _police('$dossier\\ariali.ttf'),
      boldItalic: await _police('$dossier\\arialbi.ttf'),
    );
  } catch (_) {
    _theme = null;
  }
  return _theme;
}

pw.ThemeData? _theme;
bool _charge = false;

Future<pw.Font> _police(String chemin) async {
  final octets = await File(chemin).readAsBytes();
  return pw.Font.ttf(ByteData.view(octets.buffer));
}
