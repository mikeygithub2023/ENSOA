// Les comptes du personnel se cherchent par cellule, puis par nom.
import 'package:flutter_test/flutter_test.dart';

import 'package:sig_ensoa/core/roles.dart';
import 'package:sig_ensoa/features/administration/regroupement_comptes.dart';
import 'package:sig_ensoa/models/profil.dart';

Profil _p(
  String nom,
  String prenom, {
  RoleScolarite? s,
  RoleLogistique? l,
  String? service,
}) => Profil(
  id: '$nom$prenom',
  nom: nom,
  prenom: prenom,
  roleScolarite: s,
  roleLogistique: l,
  profilPersonnaliseId: service,
);

void main() {
  final groupes = regrouperComptes(
    [
      _p('TOUMAN', 'Pierre', l: RoleLogistique.soutienPetrolier),
      _p('KONE', 'Mola', s: RoleScolarite.medecin, l: RoleLogistique.sante),
      _p('COULIBALY', 'Gon', l: RoleLogistique.garage),
      _p(
        'ADJE',
        'Merveille',
        s: RoleScolarite.medecin,
        l: RoleLogistique.sante,
      ),
      _p(
        'DJAMA',
        'Yannick',
        s: RoleScolarite.admin,
        l: RoleLogistique.administrateur,
      ),
      _p('Élie', 'Jean', l: RoleLogistique.profilPersonnalise, service: 's1'),
      _p('BOUA', 'Kassy', l: RoleLogistique.profilPersonnalise, service: 's2'),
      _p(
        'EDI',
        'Fabrice',
        s: RoleScolarite.admin,
        l: RoleLogistique.administrateur,
      ),
      _p('ZORRO', 'Inconnu'),
    ],
    {'s1': 'Transmissions', 's2': 'Bureau courrier'},
  );

  test("les cellules suivent l'organisation de l'école", () {
    expect(groupes.map((g) => g.$1), [
      'Commandement et administration',
      'Service de santé',
      'Soutien pétrolier',
      'Garage',
      'Bureau courrier',
      'Transmissions',
      'Poste non reconnu',
    ]);
  });

  test('dans une cellule, les noms vont par ordre alphabétique', () {
    final noms = {
      for (final (cellule, membres) in groupes)
        cellule: membres.map((m) => m.nom).toList(),
    };
    expect(noms['Commandement et administration'], ['DJAMA', 'EDI']);
    expect(noms['Service de santé'], ['ADJE', 'KONE']);
  });

  test('un accent ne fait pas sortir un nom de sa lettre', () {
    final ordre = regrouperComptes([
      _p('FOFANA', 'A', l: RoleLogistique.garage),
      _p('Élie', 'B', l: RoleLogistique.garage),
      _p('DIALLO', 'C', l: RoleLogistique.garage),
    ], const {}).single.$2.map((m) => m.nom);
    expect(ordre, ['DIALLO', 'Élie', 'FOFANA']);
  });
}
