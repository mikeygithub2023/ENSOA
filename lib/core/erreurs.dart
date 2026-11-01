import 'package:supabase_flutter/supabase_flutter.dart'
    show FunctionException, PostgrestException, StorageException;

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
  if (estExceptionReseauBasNiveau(erreur) || _estCoupureClient(erreur)) {
    return 'Connexion au serveur interrompue. Vérifiez votre accès Internet, '
        'puis réessayez.';
  }
  // Le message brut de PostgreSQL s'adresse à qui tient la base, pas à qui
  // saisit un véhicule : « violates foreign key constraint
  // "vehicule_type_vhl_id_fkey" » n'apprend rien et inquiète. Voir
  // `erreurs_base.dart`.
  if (erreur is PostgrestException) {
    return messageBaseDeDonnees(erreur);
  }
  if (erreur is StorageException) {
    return erreur.message;
  }
  // Une fonction serveur qui refuse lève cette exception, dont le
  // `toString()` ne montre qu'un code — « FunctionException(status: 400) ».
  // Le motif du refus, lui, est dans les détails : c'est lui qui apprend
  // quelque chose à l'utilisateur.
  if (erreur is FunctionException) {
    final details = erreur.details;
    if (details is Map && details['error'] != null) {
      return details['error'].toString();
    }
    if (details is String && details.trim().isNotEmpty) return details;
    final reason = erreur.reasonPhrase;
    return reason == null || reason.trim().isEmpty
        ? 'Le serveur a refusé l\'opération (code ${erreur.status}).'
        : reason;
  }
  return erreur.toString();
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
  return texte.contains('failed host lookup') ||
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
