/// Configuration Supabase de l'ERP unifié.
///
/// La clé publishable (anon) est prévue pour être embarquée côté client :
/// ce sont les politiques RLS, côté serveur, qui protègent réellement les
/// données — pas le secret de cette clé.
class Env {
  Env._();

  static const String supabaseUrl = 'https://alsglftuvvefxaadfzsj.supabase.co';
  static const String supabasePublishableKey =
      'sb_publishable_LCO8wMw7w7PFx56E1iH_LA_260paEgC';

  static const String appName = 'SIG ENSOA';
  static const String appFullName = "Système de Gestion Intégrée de L'ENSOA";
  static const String appVersion = 'v1.0';
}
