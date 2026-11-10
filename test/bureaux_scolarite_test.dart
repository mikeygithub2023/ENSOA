// La scolarité se partage entre deux bureaux.
//
// L'écran de l'effectif portait sept onglets pour tout le monde ; chacun n'y
// avait affaire qu'à trois ou quatre. L'instruction tient la notation, les
// ressources humaines tiennent la personne.
//
// Ce qu'on garde sous contrôle ici : qu'aucun bureau ne reçoive le travail de
// l'autre, que la liste nominative reste aux deux, et que le rangement du menu
// par section reste vrai — même s'il ne s'écrit nulle part dans la colonne.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sig_ensoa/core/roles.dart';
import 'package:sig_ensoa/features/auth/providers/auth_providers.dart';
import 'package:sig_ensoa/features/shell/app_shell.dart';
import 'package:sig_ensoa/features/shell/nav_items.dart';
import 'package:sig_ensoa/models/profil.dart';
import 'package:sig_ensoa/modules/logistique/data/models/notification_item.dart';
import 'package:sig_ensoa/modules/logistique/data/repositories/misc_providers.dart';
import 'package:sig_ensoa/modules/scolarite/features/apprenants/bureaux.dart';
import 'package:sig_ensoa/modules/scolarite/features/apprenants/entity_tabs.dart';

class _SansNotification extends NotificationsNotifier {
  @override
  Future<void> refresh() async {}

  @override
  List<AppNotification> build() => const [];
}

const _administrateur = Profil(
  id: 'p1',
  nom: 'DJAMA',
  prenom: 'Yannick',
  roleLogistique: RoleLogistique.administrateur,
);

Profil _profil(RoleScolarite role) =>
    Profil(id: 'p2', nom: 'KOUAME', prenom: 'Yao', roleScolarite: role);

List<SectionNav> _sections(Profil profil) => sectionsVues(elementsPour(profil));

Future<void> _ouvrirLeMenu(WidgetTester tester, Size taille) async {
  tester.view.physicalSize = taille;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        notificationsProvider.overrideWith(_SansNotification.new),
        profilCourantProvider.overrideWith((ref) async => _administrateur),
      ],
      child: const MaterialApp(
        // Un chemin hors des modules : le cadre ne déclenche alors aucun
        // rechargement, et la barre se dessine seule.
        home: AppShell(location: '/administration', child: SizedBox.shrink()),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  group('les onglets de chaque bureau', () {
    test("l'instruction ne reçoit que la notation", () {
      expect(ongletsDuBureau(Bureau.instruction, avecClasse: true), [
        OngletEffectif.effectif,
        OngletEffectif.resultats,
        OngletEffectif.controles,
      ]);
    });

    test('les ressources humaines ne reçoivent aucune note', () {
      final onglets = ongletsDuBureau(
        Bureau.ressourcesHumaines,
        avecClasse: true,
      );
      expect(onglets, [
        OngletEffectif.priseArmes,
        OngletEffectif.effectif,
        OngletEffectif.statistiques,
        OngletEffectif.consultations,
        OngletEffectif.permissions,
        OngletEffectif.absences,
      ]);
      expect(onglets, isNot(contains(OngletEffectif.resultats)));
      expect(onglets, isNot(contains(OngletEffectif.controles)));
    });

    // Elle est le chemin vers la fiche de chacun : la retirer à un bureau
    // l'empêcherait d'ouvrir le dossier de l'élève qu'il cherche.
    test('la liste nominative reste aux deux', () {
      for (final bureau in Bureau.values) {
        for (final avecClasse in [true, false]) {
          expect(
            ongletsDuBureau(bureau, avecClasse: avecClasse),
            contains(OngletEffectif.effectif),
            reason: '$bureau doit garder sa liste nominative',
          );
        }
      }
    });

    // Sous « toutes phases / stages », ni les résultats ni les contrôles ni
    // les statistiques n'ont de portée définie : ils ne paraissent pas.
    test("sans phase retenue, ce qui n'a pas de portée s'efface", () {
      expect(ongletsDuBureau(Bureau.instruction, avecClasse: false), [
        OngletEffectif.effectif,
      ]);
      expect(
        ongletsDuBureau(Bureau.ressourcesHumaines, avecClasse: false),
        isNot(contains(OngletEffectif.statistiques)),
      );
    });
  });

  group('les sections du menu', () {
    // Le rangement reste vrai même s'il ne s'écrit nulle part : c'est lui qui
    // décide de l'ordre des entrées dans la colonne.
    test("l'administrateur voit les quatre bureaux, dans l'ordre", () {
      expect(_sections(_administrateur), [
        SectionNav.commun,
        SectionNav.instruction,
        SectionNav.ressourcesHumaines,
        SectionNav.sante,
        SectionNav.soutienTechnique,
      ]);
    });

    test('une section sans entrée visible n’apparaît pas', () {
      // Le médecin ne tient que la santé.
      expect(_sections(_profil(RoleScolarite.medecin)), [
        SectionNav.commun,
        SectionNav.sante,
      ]);

      // Le commandant de division tient l'instruction et le personnel de sa
      // division, rien de la santé ni du soutien technique.
      final sections = _sections(_profil(RoleScolarite.chefDivision));
      expect(sections, contains(SectionNav.instruction));
      expect(sections, contains(SectionNav.ressourcesHumaines));
      expect(sections, isNot(contains(SectionNav.sante)));
      expect(sections, isNot(contains(SectionNav.soutienTechnique)));
    });

    test('les ressources humaines s’ouvrent à qui consulte les apprenants', () {
      final chemins = elementsPour(
        _profil(RoleScolarite.chefDivision),
      ).map((e) => e.chemin);
      expect(chemins, contains('/ressources-humaines'));

      // L'élève n'a pas à lire la situation de ses camarades.
      final eleve = elementsPour(
        _profil(RoleScolarite.eleveStagiaire),
      ).map((e) => e.chemin);
      expect(eleve, isNot(contains('/ressources-humaines')));
    });
  });

  group('la barre', () {
    // Les sections ne s'écrivent pas dans la colonne : on les avait posées en
    // intertitres, et elles hachaient la lecture plus qu'elles n'éclairaient.
    testWidgets('elle ne porte aucun intertitre de section', (tester) async {
      await _ouvrirLeMenu(tester, const Size(1600, 1400));
      for (final libelle in [
        'INSTRUCTION',
        'RESSOURCES HUMAINES',
        'SANTÉ',
        'SOUTIEN TECHNIQUE',
        'GÉNÉRAL',
      ]) {
        expect(
          find.text(libelle),
          findsNothing,
          reason: '« $libelle » ne doit pas coiffer la colonne',
        );
      }
    });

    testWidgets('chaque bureau y porte son entrée', (tester) async {
      await _ouvrirLeMenu(tester, const Size(1600, 1400));
      expect(find.text('Instruction'), findsOneWidget);
      expect(find.text('Ressources humaines'), findsOneWidget);
    });

    testWidgets('repliée, elle ne garde que les icônes', (tester) async {
      await _ouvrirLeMenu(tester, const Size(800, 1400));
      expect(find.text('Ressources humaines'), findsNothing);
      expect(
        find.byWidgetPredicate(
          (w) => w is Tooltip && w.message == 'Ressources humaines',
        ),
        findsOneWidget,
      );
    });
  });
}
