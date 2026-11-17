import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthException, FunctionException, PostgrestException, StorageException;

import 'erreurs_base.dart';
import 'exceptions_reseau.dart';
import 'session_fraiche.dart';

/// Traduit une exception en une phrase que l'utilisateur peut comprendre et
/// sur laquelle il peut agir.
///
/// Les exceptions brutes (« ClientException: Connection closed before full
/// header was received, uri=https://... ») n'apprennent rien à un
/// utilisateur : elles ne disent ni ce qui s'est passé, ni quoi faire. La
/// distinction qui compte ici est celle entre une coupure réseau — on
/// réessaie — et un refus du serveur — on ne réessaiera pas utilement.
String messageErreur(Object erreur) {
  // Placé avant tout le reste : un jeton expiré remonte tantôt en
  // `AuthException`, tantôt en `PostgrestException`, et son message brut
  // (« JWT expired ») n'apprend rien à qui n'a pas écrit le serveur.
  if (estSessionExpiree(erreur)) {
    return 'Votre session a expiré. Reconnectez-vous pour continuer.';
  }
  if (estProblemeReseau(erreur)) return messageReseau;
  // Le message brut de PostgreSQL s'adresse à qui tient la base, pas à qui
  // saisit un véhicule : « violates foreign key constraint
  // "vehicule_type_vhl_id_fkey" » n'apprend rien et inquiète. Voir
  // `erreurs_base.dart`.
  if (erreur is PostgrestException) {
    return messageBaseDeDonnees(erreur);
  }
  if (erreur is StorageException) {
    return _lisible(erreur.message) ?? messageServeurGenerique;
  }
  // Une fonction serveur qui refuse lève cette exception. Le motif du refus,
  // quand la fonction l'a rédigé pour l'utilisateur, est dans les détails.
  if (erreur is FunctionException) {
    final details = erreur.details;
    final motif = details is Map ? details['error']?.toString() : '$details';
    final lisible = _lisible(motif);
    if (lisible != null) return lisible;
    return switch (erreur.status) {
      401 => 'Votre session a expiré. Reconnectez-vous pour continuer.',
      403 => 'Vous n\'avez pas le droit d\'effectuer cette opération.',
      _ => messageServeurGenerique,
    };
  }
  if (erreur is AuthException) {
    return _lisible(erreur.message) ?? messageServeurGenerique;
  }
  // Nos propres `throw Exception('…')` portent une phrase écrite pour
  // l'utilisateur ; tout le reste est un détail technique.
  return _lisible('$erreur') ?? messageServeurGenerique;
}

const messageReseau =
    'Connexion au serveur impossible. Vérifiez votre accès Internet, '
    'puis réessayez.';

/// Ce qui trahit un message écrit pour le technicien : une adresse, le nom
/// d'un service, d'une exception, d'une table ou d'un code d'erreur.
final _technique = RegExp(
  r'https?:|www\.|\.co\b|\.ts\b|\.dart\b|uri=|supabase|postgres|postgrest|'
  r'pgrst|jwt|sql|schema|relation |column |constraint|function |'
  r'exception|error:|status:|statuscode|reasonphrase|minified|'
  r'stack|null\)|\{|\}|#\d|typeerror|nosuchmethod|instance of',
  caseSensitive: false,
);

/// Les refus courants du service d'authentification, qui répond en anglais.
const _traductions = <String, String>{
  'already been registered':
      'Cet identifiant est déjà utilisé par un autre compte.',
  'already registered': 'Cet identifiant est déjà utilisé par un autre compte.',
  'invalid login credentials': 'Identifiant ou mot de passe incorrect.',
  'password should be at least': 'Le mot de passe est trop court.',
  'user not found': 'Ce compte est introuvable.',
  'new password should be different':
      'Le nouveau mot de passe doit différer de l\'ancien.',
  'email rate limit': 'Trop de tentatives. Patientez quelques minutes.',
  'rate limit': 'Trop de tentatives. Patientez quelques minutes.',
};

/// La phrase, si elle peut être montrée telle quelle ; sinon `null`.
String? _lisible(String? brut) {
  if (brut == null) return null;
  var texte = brut.trim();
  for (final prefixe in [
    'Exception: ',
    'Bad state: ',
    'Invalid argument(s): ',
  ]) {
    if (texte.startsWith(prefixe)) texte = texte.substring(prefixe.length);
  }
  if (texte.isEmpty || texte == 'null') return null;
  final minuscule = texte.toLowerCase();
  for (final MapEntry(:key, :value) in _traductions.entries) {
    if (minuscule.contains(key)) return value;
  }
  if (_technique.hasMatch(texte)) return null;
  return texte;
}

/// `ClientException` vient du paquet `http` et n'est pas exposée par
/// supabase_flutter : on la reconnaît à son nom plutôt que de l'importer,
/// et à la coupure de connexion qu'elle signale.
/// Le serveur est-il simplement hors d'atteinte ?
///
/// Sert à choisir la façon de le dire : une panne de réseau mérite un message
/// discret et passager, pas un pavé rouge sous le formulaire. L'utilisateur
/// n'a rien fait de mal et n'a rien à corriger — il n'a qu'à réessayer.
///
/// Le cas le plus fréquent sur tablette n'arrive pas en `SocketException`
/// nue : la bibliothèque d'authentification l'enveloppe dans une
/// `AuthRetryableFetchException`, dont le message porte encore le
/// « Failed host lookup » d'origine. On regarde donc aussi le texte.
bool estProblemeReseau(Object erreur) {
  if (estExceptionReseauBasNiveau(erreur) || _estCoupureClient(erreur)) {
    return true;
  }
  final texte = erreur.toString().toLowerCase();
  // Sur le web, une requête que le navigateur n'a pas pu envoyer (serveur
  // injoignable, refus CORS) remonte avec le statut 0 et « Failed to fetch ».
  if (erreur is FunctionException && erreur.status == 0) return true;
  return texte.contains('failed host lookup') ||
      texte.contains('failed to fetch') ||
      texte.contains('xmlhttprequest error') ||
      texte.contains('socketexception') ||
      texte.contains('clientexception') ||
      texte.contains('network is unreachable') ||
      texte.contains('connection timed out');
}

bool _estCoupureClient(Object erreur) {
  if (erreur.runtimeType.toString() != 'ClientException') return false;
  final texte = erreur.toString().toLowerCase();
  return texte.contains('connection closed') ||
      texte.contains('connection reset') ||
      texte.contains('connection refused') ||
      texte.contains('software caused connection abort');
}
