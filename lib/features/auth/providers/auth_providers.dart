import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_client.dart';
import '../../../models/profil.dart';
import '../data/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(),
);

final changementsDeSessionProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).changementsDeSession;
});

/// Le profil de l'utilisateur connecté — ses deux rôles, donc ses
/// permissions. Null s'il n'est pas connecté, ou si son compte existe sans
/// profil : un compte sans profil n'ouvre rien, ni ici ni côté RLS.
final profilCourantProvider = FutureProvider<Profil?>((ref) async {
  final session =
      ref.watch(changementsDeSessionProvider).value?.session ??
      supabase.auth.currentSession;
  if (session == null) return null;

  final donnees = await socle
      .from('profiles')
      .select()
      .eq('id', session.user.id)
      .maybeSingle();
  if (donnees == null) return null;
  return Profil.fromJson(donnees);
});
