import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/identite.dart';
import '../../../core/push.dart';
import '../../../core/supabase_client.dart';

class AuthRepository {
  /// On se connecte avec son matricule. L'email attendu par Supabase Auth est
  /// synthétisé à partir de lui : l'utilisateur ne le voit jamais.
  Future<AuthResponse> connexion({
    required String matricule,
    required String motDePasse,
  }) {
    return supabase.auth.signInWithPassword(
      email: Identite.emailDepuisMatricule(matricule),
      password: motDePasse,
    );
  }

  /// Change le mot de passe du compte connecté et baisse le drapeau qui
  /// imposait ce changement — les deux vont ensemble : tant que le mot de
  /// passe posé à l'ouverture du compte n'a pas été remplacé, deux personnes
  /// peuvent entrer sous la même identité, et le journal d'audit attribuerait
  /// à l'une ce que l'autre a fait.
  Future<void> changerMotDePasse({
    required String actuel,
    required String nouveau,
  }) async {
    // `currentPassword` n'est pas décoratif, mais il ne sert que si le
    // projet exige la vérification — réglage « Require current password
    // when updating », côté serveur. C'est LUI qui protège : un jeton volé
    // suffisait sinon à s'approprier le compte définitivement, puisque le
    // jeton de rafraîchissement vit plusieurs jours.
    //
    // L'écran le demande donc dans tous les cas, et le serveur tranche.
    await supabase.auth.updateUser(
      UserAttributes(password: nouveau, currentPassword: actuel),
    );
    final id = supabase.auth.currentUser?.id;
    if (id == null) return;
    // Le `select` n'est pas décoratif : sans lui, une mise à jour que la RLS
    // refuserait passerait pour un succès — PostgREST répond « aucune ligne
    // touchée », sans erreur —, et le compte garderait éternellement la
    // mention « Mot de passe à changer ».
    final baissees = await socle
        .from('profiles')
        .update({'doit_changer_mot_de_passe': false})
        .eq('id', id)
        .select('id');

    if (baissees.isEmpty) {
      throw Exception(
        'Le mot de passe a bien été changé, mais le compte reste marqué '
        "« à changer » : signalez-le à l'administrateur.",
      );
    }
  }

  /// Ferme la session, et retire d'abord l'appareil des destinataires de
  /// notifications.
  ///
  /// `Push.oublier()` n'était appelé qu'au bouton « se déconnecter ». Les
  /// trois autres sorties — le verrou d'inactivité, la session devenue
  /// irrécupérable, le changement de mot de passe — l'oubliaient, et c'est
  /// le verrou d'inactivité qui est précisément le cas de la tablette
  /// posée puis reprise. L'agent suivant recevait les notifications du
  /// précédent sur l'écran verrouillé, que FLAG_SECURE ne couvre pas.
  ///
  /// Posé ici, aucun chemin ne peut plus l'oublier.
  Future<void> deconnexion() async {
    // Si le retrait échoue — réseau coupé —, la déconnexion doit avoir
    // lieu quand même : mieux vaut un jeton orphelin qu'une session qui
    // reste ouverte.
    try {
      await Push.oublier();
    } catch (_) {}
    await supabase.auth.signOut();
  }

  Stream<AuthState> get changementsDeSession => supabase.auth.onAuthStateChange;

  Session? get sessionCourante => supabase.auth.currentSession;
}
