/// Passerelle entre les écrans repris du soutien technique et le socle commun.
///
/// Ces écrans ont été écrits contre un `sessionProvider` qui portait un
/// `AppUser`. Plutôt que de retoucher trente fichiers — chaque retouche étant
/// une occasion de casser une règle d'accès — on leur redonne la même forme,
/// alimentée par le profil unifié. La dette tient en un fichier, et se
/// résorbe écran par écran quand l'occasion se présente.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sig_ensoa/core/postes.dart';
import 'package:sig_ensoa/core/roles.dart';
import 'package:sig_ensoa/features/auth/providers/auth_providers.dart';

import 'data/models/user.dart';

/// Le rôle « soutien technique » sous son ancien nom.
typedef UserRole = RoleLogistique;

extension UserRoleCompat on RoleLogistique {
  String get label => libelle;

  /// Les rôles que ce poste peut ouvrir. La chaîne de commandement vit
  /// désormais dans `postes.dart`, exprimée en postes.
  List<RoleLogistique> get rolesQuIlPeutCreer {
    final postes = postesCreables[_posteApparie(this)] ?? const <Poste>{};
    return postes
        .map((p) => p.roleLogistique)
        .whereType<RoleLogistique>()
        .toList();
  }

  bool aLaMainSur(RoleLogistique autre) => rolesQuIlPeutCreer.contains(autre);
}

/// Le poste correspondant à un rôle logistique. L'administrateur et
/// l'infirmerie en portent deux : on les retrouve par leur seule moitié
/// logistique.
Poste? _posteApparie(RoleLogistique role) {
  for (final e in rolesDuPoste.entries) {
    if (e.value.$2 == role) return e.key;
  }
  return null;
}

class SessionEtat {
  const SessionEtat(this.user);
  final AppUser user;
}

/// Le `sessionProvider` d'origine, adossé au profil unifié. Null tant que le
/// profil n'est pas chargé, ou si le compte n'est rattaché à aucun poste.
final sessionProvider = Provider<SessionEtat?>((ref) {
  final profil = ref.watch(profilCourantProvider).value;
  if (profil == null) return null;
  return SessionEtat(
    AppUser(
      id: profil.id,
      matricule: profil.matricule ?? '',
      nomComplet: profil.nomComplet,
      grade: profil.grade ?? '',
      // Un agent qui ne relève pas du soutien technique n'a pas de rôle ici.
      // Les écrans du module ne lui sont de toute façon pas ouverts : la
      // navigation les masque, et la RLS refuserait ses requêtes.
      role: profil.roleLogistique ?? RoleLogistique.soutienPetrolier,
      celluleId: profil.celluleId?.toString(),
      actif: profil.actif,
      doitChangerPin: profil.doitChangerMotDePasse,
    ),
  );
});
