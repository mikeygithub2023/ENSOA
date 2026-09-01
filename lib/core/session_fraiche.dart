import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_client.dart';

/// Rejoue une requête une fois après avoir renouvelé le jeton de session,
/// lorsque le serveur l'a refusée parce qu'il avait expiré.
///
/// Le jeton d'accès vaut une heure. La bibliothèque le renouvelle toute
/// seule tant que l'application vit normalement — mais pas si le poste s'est
/// mis en veille, ni si la machine a dormi plus longtemps que cette heure.
/// L'utilisateur retrouve alors son écran intact, ses données affichées, et
/// chaque bouton qui échoue sur « JWT expired ». Rien ne lui dit que sa
/// session est morte.
///
/// Deux réponses, dans cet ordre :
///
///   1. Renouveler le jeton et rejouer. Le jeton de rafraîchissement, lui,
///      vaut plusieurs jours : dans l'immense majorité des cas, cela suffit
///      et l'utilisateur ne voit rien.
///   2. Si ce renouvellement échoue à son tour, la session est réellement
///      perdue : on la ferme, ce qui ramène l'application à l'écran de
///      connexion plutôt que de la laisser dans un état où plus rien ne
///      fonctionne.
///
/// Une seule reprise : le serveur avait refusé la requête sans l'exécuter,
/// la rejouer ne crée donc pas de doublon.
Future<T> avecSessionFraiche<T>(Future<T> Function() action) async {
  try {
    return await action();
  } catch (erreur) {
    if (!estSessionExpiree(erreur)) rethrow;

    try {
      await supabase.auth.refreshSession();
    } catch (_) {
      // Le jeton de rafraîchissement est mort lui aussi : il n'y a plus de
      // session à sauver. On la ferme proprement pour que l'aiguillage
      // ramène à la connexion.
      await supabase.auth.signOut();
      rethrow;
    }

    return action();
  }
}

/// Le serveur a-t-il refusé la requête faute de jeton valide ?
///
/// PostgREST répond `PGRST301` ; l'authentification lève une
/// `AuthException`. Le texte est examiné en dernier recours, les
/// bibliothèques n'exposant pas toujours de code.
bool estSessionExpiree(Object erreur) {
  if (erreur is AuthException) return true;
  if (erreur is PostgrestException && erreur.code == 'PGRST301') return true;

  final texte = erreur.toString().toLowerCase();
  return texte.contains('jwt expired') ||
      texte.contains('jwt is expired') ||
      texte.contains('invalid jwt') ||
      texte.contains('token is expired');
}
