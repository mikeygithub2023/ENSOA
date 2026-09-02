// Fabrique la sonnerie des notifications : deux notes brèves, montantes.
//
// Un outil d'amorçage, à lancer une fois — le fichier produit est versionné
// avec l'application. On l'engendre plutôt que d'en télécharger un : pas de
// licence à démêler, pas de dépendance à une source qui peut disparaître, et
// le timbre se règle ici en une ligne si le commandement le trouve trop sec.
//
//   dart run outils/engendrer_sonnerie.dart
//
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

const _frequenceEchantillonnage = 44100;

/// La 5 puis ré 6 : un intervalle montant, qui s'entend comme une question
/// à laquelle on doit répondre, plutôt que comme une alarme.
const _notes = <(double frequence, double duree)>[(880, 0.10), (1174.66, 0.14)];

void main() {
  final echantillons = <int>[];

  for (final (frequence, duree) in _notes) {
    final nombre = (duree * _frequenceEchantillonnage).round();
    for (var i = 0; i < nombre; i++) {
      final t = i / _frequenceEchantillonnage;

      // Une enveloppe : attaque immédiate, extinction douce. Sans elle, la
      // coupure nette produit un claquement désagréable au casque.
      final progression = i / nombre;
      final enveloppe = progression < 0.05
          ? progression / 0.05
          : pow(1 - (progression - 0.05) / 0.95, 1.8).toDouble();

      final valeur = sin(2 * pi * frequence * t) * enveloppe * 0.45;
      echantillons.add((valeur * 32767).round().clamp(-32768, 32767));
    }
  }

  final donnees = Int16List.fromList(echantillons);
  final octets = donnees.buffer.asUint8List();
  final fichier = File('assets/sons/notification.wav');
  fichier.parent.createSync(recursive: true);
  fichier.writeAsBytesSync(_enveloppeWav(octets));

  stdout.writeln(
    'Écrit : ${fichier.path} '
    '(${(octets.length / 1024).toStringAsFixed(1)} Ko, '
    '${(echantillons.length / _frequenceEchantillonnage * 1000).round()} ms)',
  );
}

/// L'en-tête WAV canonique : PCM 16 bits, mono. Quarante-quatre octets.
Uint8List _enveloppeWav(Uint8List pcm) {
  final entete = BytesBuilder();
  void ascii(String s) => entete.add(s.codeUnits);
  void entier32(int v) =>
      entete.add(Uint8List(4)..buffer.asByteData().setUint32(0, v, Endian.little));
  void entier16(int v) =>
      entete.add(Uint8List(2)..buffer.asByteData().setUint16(0, v, Endian.little));

  ascii('RIFF');
  entier32(36 + pcm.length);
  ascii('WAVE');
  ascii('fmt ');
  entier32(16); // taille du bloc de format
  entier16(1); // PCM non compressé
  entier16(1); // mono
  entier32(_frequenceEchantillonnage);
  entier32(_frequenceEchantillonnage * 2); // octets par seconde
  entier16(2); // alignement
  entier16(16); // bits par échantillon
  ascii('data');
  entier32(pcm.length);
  entete.add(pcm);

  return entete.toBytes();
}
