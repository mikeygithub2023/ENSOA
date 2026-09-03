import 'package:sig_ensoa/core/roles.dart';

/// UTILISATEUR — compte applicatif (distinct de PERSONNEL, la fiche militaire).
/// FONCTION_UTILISATEUR (chaîne HFSQL) porte le rôle applicatif ; mappé ici
/// vers [RoleLogistique] pour la sécurité de type côté Flutter.
class AppUser {
  final String id; // IDUTILISATEUR
  final String matricule;
  final String nomComplet; // NOM_UTILISATEUR
  final String grade; // GRADE_UTILISATEUR
  final RoleLogistique role; // FONCTION_UTILISATEUR
  final String? celluleId; // IDCELLULE
  final bool actif; // ETAT_ACTIF_UTILISATEUR

  /// Le PIN posé à l'ouverture du compte n'a pas encore été remplacé.
  /// Tant que c'est vrai, l'application ne donne accès qu'à l'écran de
  /// changement : celui qui a ouvert le compte connaît encore ce PIN.
  final bool doitChangerPin;

  const AppUser({
    required this.id,
    required this.matricule,
    required this.nomComplet,
    required this.grade,
    required this.role,
    this.celluleId,
    this.actif = true,
    this.doitChangerPin = false,
  });

  bool can(Permission permission) =>
      permissionsDe(logistique: role).contains(permission);
}
