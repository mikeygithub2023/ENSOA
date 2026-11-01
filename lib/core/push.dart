import 'package:flutter/foundation.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../models/profil.dart';
import 'supabase_client.dart';

/// Les notifications poussées : celles qui arrivent sur l'écran verrouillé,
/// application fermée.
///
/// Elles doublent les notifications en base, elles ne les remplacent pas. Une
/// notification poussée peut se perdre — appareil éteint, jeton périmé, accord
/// refusé — tandis que celle en base attend sagement qu'on ouvre l'écran.
/// C'est cette dernière qui fait foi.
///
/// Deux registres, hérités des deux applications, et c'est voulu : le soutien
/// technique prévient ses agents par `socle.device_token`, la scolarité
/// prévient ses élèves par `socle.appareils`. Un agent qui relève des deux
/// domaines dépose son jeton dans les deux — il attend des nouvelles des deux
/// côtés.
///
/// Tout se désarme proprement là où le push n'existe pas : sur le poste de
/// travail Windows, ou sans `google-services.json`, l'application continue
/// sans notification plutôt que de refuser de démarrer.
class Push {
  Push._();

  static bool _demarre = false;

  /// Prépare Firebase. Appelée une fois au lancement, avant toute connexion.
  static Future<void> preparer() async {
    if (!supporte) return;
    try {
      await Firebase.initializeApp();
      _demarre = true;
    } catch (_) {
      // Sans configuration Firebase, on se passe de push.
    }
  }

  /// Dépose le jeton de cet appareil pour le profil connecté, dans le ou les
  /// registres qui le concernent. À rappeler à chaque connexion : le jeton
  /// peut avoir changé depuis la dernière fois.
  static Future<void> enregistrer(Profil profil) async {
    if (!_demarre) return;
    try {
      final messagerie = FirebaseMessaging.instance;
      await messagerie.requestPermission();

      final jeton = await messagerie.getToken();
      if (jeton != null) await _deposer(profil, jeton);

      messagerie.onTokenRefresh.listen((nouveau) => _deposer(profil, nouveau));
    } catch (_) {
      // L'absence des services Google — un émulateur nu, par exemple — ne doit
      // jamais empêcher de se servir de l'application.
    }
  }

  /// Détache le jeton, à la déconnexion : celui qui reprend la tablette ne
  /// doit pas recevoir les notifications du précédent.
  static Future<void> oublier() async {
    if (!_demarre) return;
    try {
      final jeton = await FirebaseMessaging.instance.getToken();
      if (jeton == null) return;
      await scolarite.rpc('oublier_appareil', params: {'p_jeton': jeton});
      await socle.from('device_token').delete().eq('token', jeton);
    } catch (_) {
      // Sans réseau, le jeton se périmera de lui-même.
    }
  }

  static Future<void> _deposer(Profil profil, String jeton) async {
    if (profil.releveDeLaScolarite) {
      // Par la fonction plutôt qu'en direct : `socle.appareils` n'ouvre
      // aucune politique d'écriture, c'est elle qui fait foi.
      await scolarite.rpc(
        'enregistrer_appareil',
        params: {'p_jeton': jeton, 'p_plateforme': _plateforme},
      );
    }
    if (profil.releveDuSoutienTechnique) {
      await socle.from('device_token').upsert({
        'utilisateur_id': profil.id,
        'token': jeton,
        'plateforme': _plateforme,
      }, onConflict: 'token');
    }
  }

  /// Firebase Messaging ne couvre ni Windows ni, pour l'instant, la version
  /// web (PWA) : le poste de travail et le navigateur reçoivent leurs
  /// notifications dans l'application, pas dans la barre système. Le push web
  /// demanderait un service worker dédié et une clé VAPID — reporté.
  static bool get supporte =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static String get _plateforme =>
      defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
}

/// Doit rester une fonction hors classe : c'est l'exigence de Firebase pour le
/// traitement en arrière-plan. Les notifications envoyées par les fonctions
/// serveur sont de type « notification » — Android les affiche lui-même sans
/// code Dart — ce gestionnaire ne sert qu'à satisfaire l'enregistrement.
Future<void> gestionnaireArrierePlan(RemoteMessage message) async {}
