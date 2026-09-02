import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart' show HapticFeedback;

/// La sonnerie qui accompagne l'arrivée d'une notification.
///
/// Deux notes brèves et montantes, engendrées par
/// `outils/engendrer_sonnerie.dart` et embarquées avec l'application.
///
/// Pourquoi pas `SystemSound.play` : l'alerte système n'existe que sur les
/// plateformes de bureau — la documentation Flutter le dit, et
/// l'implémentation Windows se contente d'un `MessageBeep`. Sur Android,
/// l'appel est ignoré. Or c'est justement la tablette qu'il faut prévenir.
///
/// Le lecteur est unique et réutilisé : en créer un par sonnerie laisserait
/// derrière lui autant de ressources natives ouvertes.
class Sonnerie {
  static final AudioPlayer _lecteur = AudioPlayer();
  static bool _prepare = false;

  /// Sonner. Une notification qu'on ne peut pas faire entendre n'est pas une
  /// raison d'interrompre ce que l'utilisateur est en train de faire : tout
  /// échec est avalé.
  static Future<void> notification() async {
    try {
      // La vibration double la sonnerie plutôt qu'elle ne la remplace : une
      // tablette posée sur un bureau, dans un service où l'on parle, ne se
      // fait pas toujours entendre.
      await HapticFeedback.mediumImpact();
    } catch (_) {}

    try {
      if (!_prepare) {
        await _lecteur.setReleaseMode(ReleaseMode.stop);
        _prepare = true;
      }
      await _lecteur.stop();
      await _lecteur.play(AssetSource('sons/notification.wav'));
    } catch (_) {
      // Pas de son sur cette machine, pas de périphérique audio, fichier
      // absent : la notification s'affiche quand même, et c'est l'essentiel.
    }
  }
}
