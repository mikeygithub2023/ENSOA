import 'package:supabase_flutter/supabase_flutter.dart';

import 'env.dart';

Future<void> initSupabase() async {
  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabasePublishableKey,
  );
}

SupabaseClient get supabase => Supabase.instance.client;

/// Les trois schémas de la base. Passer par ces accesseurs plutôt que par
/// `supabase.from(...)` : la table nue viserait `public`, où ne dorment que
/// les anciennes tables du soutien technique, conservées jusqu'à la bascule.
///
///   socle.from('profiles')        — l'identité, commune aux deux modules
///   scolarite.from('apprenants')  — élèves et stagiaires
///   logistique.from('vehicule')   — soutien technique
SupabaseQuerySchema get socle => supabase.schema('socle');
SupabaseQuerySchema get scolarite => supabase.schema('scolarite');
SupabaseQuerySchema get logistique => supabase.schema('logistique');
