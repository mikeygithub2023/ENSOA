/// Passerelle entre les écrans repris de la scolarité et le socle commun.
///
/// Comme pour le soutien technique : ces écrans ont été écrits contre un
/// `Profile` à rôle unique et un `currentProfileProvider`. On leur redonne la
/// même forme, alimentée par le profil unifié, plutôt que de retoucher cent
/// quarante fichiers — chaque retouche étant une occasion de casser une règle
/// d'accès. La dette tient en un fichier.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sig_ensoa/core/roles.dart';
import 'package:sig_ensoa/features/auth/providers/auth_providers.dart';
import 'package:sig_ensoa/models/profil.dart';

/// Le rôle « scolarité » sous son ancien nom.
typedef AppRole = RoleScolarite;

extension AppRoleCompat on RoleScolarite {
  String get label => libelle;
  String get dbValue => valeurDb;
}

/// Un rôle inconnu retombe sur le moins ouvert des rôles du personnel, comme
/// dans l'application d'origine.
AppRole appRoleFromString(String? valeur) =>
    roleScolariteDepuisDb(valeur) ?? RoleScolarite.instructeur;

/// Le profil tel que le connaissent les écrans de la scolarité : un rôle,
/// une division, éventuellement une promotion.
class Profile {
  const Profile({
    required this.id,
    required this.nom,
    required this.prenom,
    required this.role,
    this.grade,
    this.divisionId,
    this.promotionId,
    this.doitChangerMotDePasse = false,
  });

  final String id;
  final String nom;
  final String prenom;
  final AppRole role;
  final String? grade;
  final String? divisionId;

  /// La promotion que commande un Commandant de Brigade — elle borne ce
  /// qu'il voit et note. Nulle pour tous les autres.
  final String? promotionId;

  final bool doitChangerMotDePasse;

  String get nomComplet => '$prenom $nom'.trim();

  /// L'identité telle qu'on désigne un militaire : le grade, puis le nom.
  String get identiteComplete => grade == null || grade!.trim().isEmpty
      ? nomComplet
      : '${grade!.trim()} $nomComplet';

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    id: json['id'] as String,
    nom: json['nom'] as String? ?? '',
    prenom: json['prenom'] as String? ?? '',
    role: appRoleFromString(json['role'] as String?),
    grade: json['grade'] as String?,
    divisionId: json['division_id'] as String?,
    promotionId: json['promotion_id'] as String?,
    doitChangerMotDePasse: json['doit_changer_mot_de_passe'] as bool? ?? false,
  );

  /// Depuis le profil unifié. Un agent sans rôle de scolarité n'a rien à
  /// faire dans ces écrans — la navigation les lui masque et la RLS
  /// refuserait ses requêtes — mais le type, lui, exige un rôle : on prend
  /// le moins ouvert.
  factory Profile.depuisProfil(Profil p) => Profile(
    id: p.id,
    nom: p.nom,
    prenom: p.prenom,
    role: p.roleScolarite ?? RoleScolarite.instructeur,
    grade: p.grade,
    divisionId: p.divisionId,
    promotionId: p.promotionId,
    doitChangerMotDePasse: p.doitChangerMotDePasse,
  );
}

/// Le `currentProfileProvider` d'origine, adossé au profil unifié.
final currentProfileProvider = FutureProvider<Profile?>((ref) async {
  final profil = await ref.watch(profilCourantProvider.future);
  return profil == null ? null : Profile.depuisProfil(profil);
});
