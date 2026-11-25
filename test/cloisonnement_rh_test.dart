// Le bureau des ressources humaines, et qui y voit quoi.
//
// L'école a besoin d'un compte qui ne tienne que la Division de Commandement
// et Logistique — le personnel de la maison — sans toucher aux élèves des
// autres divisions. La base le borne déjà : `apprenants_select_division_staff`
// et `divisions_select` ne lui rendent que sa division, et les deux registres
// nés le 25 novembre font de même par `releve_de_ma_division`. Ce n'est donc
// pas la sécurité qui manquait, c'est la colonne de gauche : elle lui offrait
// « Élèves & Stagiaires », « Cours » et « Matières », trois écrans que sa
// division ne peut pas remplir.
//
// Ce qu'on garde sous contrôle ici : qu'une division qui n'instruit personne
// ferme l'instruction à son commandant, que l'administrateur n'y perde rien,
// et qu'un doute sur la nature de la division ne retire rien à personne —
// c'est la RLS qui borne, pas la barre.
import 'package:flutter_test/flutter_test.dart';

import 'package:sig_ensoa/core/postes.dart';
import 'package:sig_ensoa/core/roles.dart';
import 'package:sig_ensoa/features/shell/nav_items.dart';
import 'package:sig_ensoa/models/profil.dart';
import 'package:sig_ensoa/modules/scolarite/models/division.dart';

const _dcl = Division(
  id: 'd-dcl',
  code: codeDivisionCommandement,
  nom: 'Commandement et Logistique',
);
const _dfi = Division(id: 'd-dfi', code: 'formation_initiale', nom: 'DFI');
const _toutes = [_dcl, _dfi];

Profil _commandant(String? divisionId) => Profil(
  id: 'p1',
  nom: 'KONE',
  prenom: 'Ibrahim',
  roleScolarite: RoleScolarite.chefDivision,
  divisionId: divisionId,
);

const _administrateur = Profil(
  id: 'p2',
  nom: 'DJAMA',
  prenom: 'Yannick',
  roleScolarite: RoleScolarite.admin,
  roleLogistique: RoleLogistique.administrateur,
  // Un administrateur rattaché à la DCL : cela se voit à l'école, l'état-major
  // y étant inscrit. Il commande l'école entière pour autant.
  divisionId: 'd-dcl',
);

List<String> _chemins(Profil profil, {bool? instruit}) =>
    elementsPour(profil, divisionInstruit: instruit)
        .map((e) => e.chemin)
        .toList();

void main() {
  group('la nature d’une division', () {
    test("la Division de Commandement et Logistique n'instruit personne", () {
      expect(divisionInstruit('d-dcl', _toutes), isFalse);
    });

    test('toute autre division instruit', () {
      expect(divisionInstruit('d-dfi', _toutes), isTrue);
    });

    // Trois façons de ne pas savoir. Dans les trois, on ne retire rien :
    // mieux vaut une entrée de trop qu'une rubrique disparue sans raison.
    test('on ne sait pas dire sans division, sans liste, ou sans la trouver', () {
      expect(divisionInstruit(null, _toutes), isNull);
      expect(divisionInstruit('d-dcl', null), isNull);
      expect(divisionInstruit('d-inconnue', _toutes), isNull);
    });
  });

  group('la colonne du commandant de division', () {
    test('celui qui instruit garde les trois entrées de l’instruction', () {
      final chemins = _chemins(_commandant('d-dfi'), instruit: true);
      expect(chemins, contains('/scolarite/apprenants'));
      expect(chemins, contains('/scolarite/cours'));
      expect(chemins, contains('/scolarite/matieres'));
      expect(chemins, contains('/ressources-humaines'));
    });

    test('celui de la DCL ne garde que les ressources humaines', () {
      final profil = _commandant('d-dcl');
      final chemins = _chemins(profil, instruit: false);

      // Les trois écrans que sa division ne peut pas remplir.
      expect(chemins, isNot(contains('/scolarite/apprenants')));
      expect(chemins, isNot(contains('/scolarite/cours')));
      expect(chemins, isNot(contains('/scolarite/matieres')));

      // Son bureau, et ce que tout compte garde.
      expect(chemins, contains('/ressources-humaines'));
      expect(chemins, contains('/'));
      expect(chemins, contains('/notifications'));

      final sections = sectionsVues(
        elementsPour(profil, divisionInstruit: false),
      );
      expect(sections, isNot(contains(SectionNav.instruction)));
      expect(sections, contains(SectionNav.ressourcesHumaines));
    });

    // Le doute ne retranche rien : c'est le serveur qui refuse, pas le menu.
    test('tant qu’on ne sait pas, rien n’est retiré', () {
      expect(
        _chemins(_commandant('d-dcl')),
        containsAll(['/scolarite/apprenants', '/scolarite/cours']),
      );
    });
  });

  // La règle ne vise que celui qui est borné à sa division. L'administrateur
  // voit toutes les divisions, quelle que soit celle où son compte est
  // inscrit : lui fermer l'instruction serait fermer l'école.
  test("l'administrateur rattaché à la DCL ne perd rien", () {
    final chemins = _chemins(_administrateur, instruit: false);
    expect(chemins, contains('/instruction'));
    expect(chemins, contains('/ressources-humaines'));
    expect(chemins, contains('/administration'));
    expect(
      sectionsVues(elementsPour(_administrateur, divisionInstruit: false)),
      contains(SectionNav.instruction),
    );
  });

  group('le titre proposé à l’ouverture du compte', () {
    test('commander la DCL, c’est tenir le bureau RH', () {
      expect(
        titreDUsage(Poste.chefDivision, divisionInstruit: false),
        'Chef du bureau RH',
      );
    });

    test('commander une division qui instruit garde son libellé', () {
      expect(titreDUsage(Poste.chefDivision, divisionInstruit: true), isNull);
      expect(titreDUsage(Poste.chefDivision), isNull);
    });

    // Le poste ne change pas, ni ses droits : seul le nom à l'écran change.
    test('le poste et ses rôles restent ceux du commandant de division', () {
      expect(Poste.chefDivision.roleScolarite, RoleScolarite.chefDivision);
      expect(Poste.chefDivision.roleLogistique, isNull);
      expect(
        Poste.chefDivision.permissions,
        contains(Permission.consulterApprenants),
      );
      expect(
        Poste.chefDivision.permissions,
        contains(Permission.gererApprenants),
      );
    });

    test("le Commandant de l'école garde le sien", () {
      expect(
        titreDUsage(Poste.administrateur, divisionInstruit: false),
        "Commandant de l'école",
      );
    });
  });
}
