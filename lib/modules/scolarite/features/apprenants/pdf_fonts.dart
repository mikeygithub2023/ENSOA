import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;

/// Thème typographique commun à tous les documents imprimés.
///
/// Les polices intégrées au format PDF (Helvetica & consorts) ne couvrent
/// qu'un jeu de caractères restreint : le tiret cadratin « — », l'apostrophe
/// typographique « ’ », les points de suspension « … » et **toute lettre
/// accentuée** s'y impriment en carré vide, aussi bien dans les libellés fixes
/// que dans le texte saisi par l'utilisateur. Un nom ivoirien correctement
/// accentué devenait illisible. Embarquer une vraie police règle le problème
/// à la source.
///
/// Deux polices, dans cet ordre.
///
/// **Arial d'abord, sur le poste de travail.** Ses chasses sont celles
/// d'Helvetica, la police contre laquelle les documents ont été mis en page :
/// le texte occupe exactement la même place, rien ne se décale, rien ne
/// déborde. Elle est lue dans les polices installées de Windows plutôt
/// qu'embarquée — elle appartient à Microsoft, la redistribuer n'aurait pas
/// lieu d'être.
///
/// **Roboto ensuite, sur la tablette.** Android n'a pas Arial, et les
/// documents y retombaient sur les polices intégrées, carrés vides compris.
/// Roboto est publiée sous licence Apache 2.0 : elle se redistribue
/// librement, et voyage donc dans l'application (`assets/fonts/`, licence
/// jointe). Ses chasses sont légèrement plus étroites que celles d'Arial — le
/// texte prend un peu moins de place, jamais plus : les tableaux ne risquent
/// pas de déborder, et le bulletin, qui tient sur une page unique et non
/// paginée, tient toujours.
///
/// Ce n'est qu'en dernier recours, si les deux manquent, que le thème vaut
/// `null` et que les carrés reviennent.
///
/// Le chargement (près d'un mégaoctet de fichiers) n'a lieu qu'une fois par
/// exécution : le résultat est mémorisé, y compris l'échec.
Future<pw.ThemeData?> chargerThemePdf() async {
  if (_charge) return _theme;
  _charge = true;
  _theme = await _arialDeWindows() ?? await _robotoEmbarquee();
  return _theme;
}

pw.ThemeData? _theme;
bool _charge = false;

Future<pw.ThemeData?> _arialDeWindows() async {
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

Future<pw.ThemeData?> _robotoEmbarquee() async {
  try {
    return pw.ThemeData.withFont(
      base: await _policeDesRessources('assets/fonts/roboto-regular.ttf'),
      bold: await _policeDesRessources('assets/fonts/roboto-bold.ttf'),
      italic: await _policeDesRessources('assets/fonts/roboto-italic.ttf'),
      boldItalic: await _policeDesRessources(
        'assets/fonts/roboto-bolditalic.ttf',
      ),
    );
  } catch (_) {
    return null;
  }
}

Future<pw.Font> _policeDuDisque(String chemin) async {
  final octets = await File(chemin).readAsBytes();
  return pw.Font.ttf(ByteData.view(octets.buffer));
}

Future<pw.Font> _policeDesRessources(String chemin) async =>
    pw.Font.ttf(await rootBundle.load(chemin));
