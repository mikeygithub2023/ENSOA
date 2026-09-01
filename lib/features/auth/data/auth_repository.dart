import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/identite.dart';
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
  Future<void> changerMotDePasse(String nouveau) async {
    await supabase.auth.updateUser(UserAttributes(password: nouveau));
    final id = supabase.auth.currentUser?.id;
    if (id == null) return;
    await socle
        .from('profiles')
        .update({'doit_changer_mot_de_passe': false})
        .eq('id', id);
  }

  Future<void> deconnexion() => supabase.auth.signOut();

  Stream<AuthState> get changementsDeSession => supabase.auth.onAuthStateChange;

  Session? get sessionCourante => supabase.auth.currentSession;
}
