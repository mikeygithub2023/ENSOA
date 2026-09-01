/// Comment on se connecte à l'ERP unifié.
///
/// L'identifiant métier est le matricule — c'est sous cette forme qu'un
/// militaire se désigne, et c'est ce que porte sa fiche. Supabase Auth, lui,
/// veut un email : on le synthétise. L'utilisateur ne le voit jamais.
class Identite {
  Identite._();

  /// Domaine technique de l'ERP unifié.
  ///
  /// Volontairement distinct du `@stensoa.com` de l'ancienne application
  /// logistique : les deux jeux de comptes cohabitent dans le même
  /// `auth.users`, et un même matricule doit pouvoir être recréé ici sans
  /// buter sur l'unicité de l'email. L'ancienne application continue donc de
  /// fonctionner avec ses comptes tant qu'on ne l'a pas coupée.
  static const String domaine = 'sig.ensoa.ci';

  static String emailDepuisMatricule(String matricule) {
    final normalise = matricule.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );
    return '$normalise@$domaine';
  }

  /// Longueur minimale du mot de passe.
  ///
  /// L'ancienne application logistique combinait un PIN à 4 chiffres avec un
  /// préfixe fixe (`ST26-`) : quatre chiffres et un préfixe connu de tous,
  /// soit dix mille possibilités énumérables. On y renonce. Le compte s'ouvre
  /// avec un mot de passe posé par celui qui le crée, et le drapeau
  /// `doit_changer_mot_de_passe` impose son remplacement à la première
  /// connexion — celui qui a ouvert le compte connaît encore ce mot de passe.
  static const int longueurMinimaleMotDePasse = 8;
}
