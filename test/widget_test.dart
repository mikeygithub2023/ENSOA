import 'package:flutter_test/flutter_test.dart';

import 'package:sig_ensoa/core/identite.dart';
import 'package:sig_ensoa/core/roles.dart';

void main() {
  test('le matricule devient un email technique du domaine unifié', () {
    expect(Identite.emailDepuisMatricule('12 345/AB'), '12345ab@sig.ensoa.ci');
  });

  test('un profil cumule les permissions de ses deux rôles', () {
    final permissions = permissionsDe(
      scolarite: RoleScolarite.instructeur,
      logistique: RoleLogistique.armurerie,
    );
    expect(permissions.contains(Permission.consulterApprenants), isTrue);
    expect(permissions.contains(Permission.gererArmement), isTrue);
    // Ce qu'aucun des deux rôles ne donne reste fermé.
    expect(permissions.contains(Permission.gererCarburant), isFalse);
  });

  test('sans rôle, aucune permission', () {
    expect(permissionsDe(), isEmpty);
  });
}
