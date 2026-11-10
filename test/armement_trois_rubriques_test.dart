// Ce que le classement de l'armement doit garantir.
//
// Trois grandes rubriques — Armement, Munitions, Équipements — et, sous
// chacune, ses bons et son inventaire. Auparavant les cinq onglets étaient
// à plat : « Bons » ne désignait que ceux des armes, « Inventaire » mêlait
// les trois domaines. Un test de structure plutôt qu'une capture d'écran :
// c'est le classement qu'on vérifie, pas son habillage.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sig_ensoa/core/chargement.dart';
import 'package:sig_ensoa/core/roles.dart';
import 'package:sig_ensoa/features/auth/providers/auth_providers.dart';
import 'package:sig_ensoa/models/profil.dart';
import 'package:sig_ensoa/modules/logistique/data/models/armement.dart';
import 'package:sig_ensoa/modules/logistique/data/repositories/armament_providers.dart';
import 'package:sig_ensoa/modules/logistique/features/armament/armament_screen.dart';
import 'package:sig_ensoa/modules/logistique/shared/widgets/widgets.dart';

class _ToutCharge extends ChargementNotifier {
  @override
  Set<String> build() => {
    'armes',
    'dotations_armes',
    'munitions',
    'equipements',
    'mouvements_articles',
    'types_arme',
  };
}

/// Les doublures ne redescendent pas au réseau : `refresh()` est neutralisé,
/// sans quoi le changement de rubrique irait interroger Supabase.
class _RegistreFige extends ArmesNotifier {
  @override
  Future<void> refresh() async {}

  @override
  List<Arme> build() => const [
    Arme(
      id: '1',
      numeroSerie: '1975-A-04412',
      type: 'Fusil d\'assaut',
      modele: 'AK 47',
      etat: EtatArme.bon,
      positionActuelle: 'Armurerie',
    ),
    // Sans marquage : la fiche ne doit pas afficher un tiret suivi de rien.
    Arme(
      id: '2',
      numeroSerie: '1975-A-04413',
      type: 'Pistolet automatique',
      modele: '',
      etat: EtatArme.defectueux,
    ),
  ];
}

class _SansDotation extends DotationsNotifier {
  @override
  Future<void> refresh() async {}

  @override
  List<DotationArme> build() => const [];
}

class _StockMunitions extends MunitionsNotifier {
  @override
  Future<void> refresh() async {}

  @override
  List<StockMunition> build() => const [
    StockMunition(
      id: '1',
      calibre: '5.56x45mm',
      quantiteDisponible: 4000,
      seuilCritique: 1000,
      souteArmementId: '',
    ),
  ];
}

class _StockEquipements extends EquipementsNotifier {
  @override
  Future<void> refresh() async {}

  @override
  List<EquipementProtection> build() => const [
    EquipementProtection(
      id: '1',
      libelle: 'Gilet pare-balles',
      quantiteDisponible: 12,
      seuilCritique: 20,
    ),
  ];
}

class _JournalFige extends MouvementsArticleNotifier {
  @override
  Future<void> refresh() async {}

  @override
  List<MouvementArticle> build() => [
    MouvementArticle(
      id: '1',
      famille: FamilleArticle.munition,
      articleId: '1',
      sens: SensMouvement.sortie,
      quantite: 500,
      beneficiaireMatricule: '123456',
      beneficiaireNom: 'KOUASSI Rémi',
      motif: 'Séance de tir',
      date: DateTime(2026, 10, 14, 9),
    ),
  ];
}

class _TypesFiges extends TypesArmeNotifier {
  @override
  Future<void> refresh() async {}

  @override
  List<TypeArme> build() => const [
    TypeArme(id: '1', libelle: 'Fusil d\'assaut'),
  ];
}

Future<void> _ouvrir(
  WidgetTester tester, {
  RoleLogistique role = RoleLogistique.armurerie,
}) async {
  tester.view.physicalSize = const Size(1400, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        chargementProvider.overrideWith(_ToutCharge.new),
        armesProvider.overrideWith(_RegistreFige.new),
        dotationsProvider.overrideWith(_SansDotation.new),
        munitionsProvider.overrideWith(_StockMunitions.new),
        equipementsProvider.overrideWith(_StockEquipements.new),
        mouvementsArticleProvider.overrideWith(_JournalFige.new),
        typesArmeProvider.overrideWith(_TypesFiges.new),
        profilCourantProvider.overrideWith(
          (ref) async => Profil(
            id: 'p1',
            nom: 'KOUASSI',
            prenom: 'Rémi',
            grade: 'SGT',
            roleLogistique: role,
          ),
        ),
      ],
      child: const MaterialApp(
        home: Scaffold(body: Padding(padding: EdgeInsets.all(8), child: ArmamentScreen())),
      ),
    ),
  );
  await tester.pumpAndSettle();
  // L'écran ouvre sur son tableau de bord ; ces épreuves portent sur les
  // rubriques, on se place donc d'emblée sur la première.
  await _rubrique(tester, 'Armement');
}

/// Ouvre une grande rubrique par son nom.
Future<void> _rubrique(WidgetTester tester, String nom) async {
  await tester.tap(find.widgetWithText(Tab, nom));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('un tableau de bord et trois grandes rubriques', (tester) async {
    await _ouvrir(tester);
    expect(find.widgetWithText(Tab, 'Tableau de bord'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Armement'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Munitions'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Équipements'), findsOneWidget);
    // « Armes » était une rubrique de premier niveau ; elle est devenue le
    // « Registre » de l'Armement.
    expect(find.widgetWithText(Tab, 'Armes'), findsNothing);
  });

  testWidgets('l\'Armement porte registre, bons et inventaire', (
    tester,
  ) async {
    await _ouvrir(tester);
    expect(find.widgetWithText(Tab, 'Registre'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Bons'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Inventaire'), findsOneWidget);
  });

  testWidgets('les munitions portent stock, bons et inventaire', (
    tester,
  ) async {
    await _ouvrir(tester);
    await _rubrique(tester, 'Munitions');
    expect(find.widgetWithText(Tab, 'Stock'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Bons'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Inventaire'), findsOneWidget);
    expect(find.textContaining('5.56x45mm'), findsWidgets);
  });

  testWidgets('les équipements aussi', (tester) async {
    await _ouvrir(tester);
    await _rubrique(tester, 'Équipements');
    expect(find.widgetWithText(Tab, 'Stock'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Bons'), findsOneWidget);
    expect(find.textContaining('Gilet pare-balles'), findsWidgets);
  });

  testWidgets('les bons des munitions sont ceux des munitions', (
    tester,
  ) async {
    // La sous-rubrique « Bons » d'une famille ne montre que ses mouvements.
    // Le journal est commun aux deux familles en base ; s'il n'était pas
    // filtré, les sorties de cartouches paraîtraient sous les gilets.
    await _ouvrir(tester);
    await _rubrique(tester, 'Munitions');
    await tester.tap(find.widgetWithText(Tab, 'Bons'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Séance de tir'), findsOneWidget);

    await _rubrique(tester, 'Équipements');
    await tester.tap(find.widgetWithText(Tab, 'Bons'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Séance de tir'), findsNothing);
    expect(find.text('Aucun bon pour ce filtre'), findsOneWidget);
  });

  group("l'état d'une arme est celui du registre", () {
    // Le registre de l'école ne connaît que deux états : BON ou
    // DÉFECTUEUX. Les quatre anciennes valeurs mêlaient l'état de l'arme
    // et l'endroit où elle se trouve ; le second se lit sur « position
    // actuelle » et sur le bon de sortie en cours.
    testWidgets("les filtres n'offrent que ces deux-là", (tester) async {
      await _ouvrir(tester);
      expect(find.widgetWithText(FilterChipPill, 'Bon'), findsOneWidget);
      expect(
        find.widgetWithText(FilterChipPill, 'Défectueux'),
        findsOneWidget,
      );
      for (final ancien in [
        'En armurerie',
        'En dotation',
        'En maintenance',
        'Réformée',
      ]) {
        expect(
          find.widgetWithText(FilterChipPill, ancien),
          findsNothing,
          reason: "« $ancien » n'est plus un état",
        );
      }
    });

    testWidgets('chaque arme porte le sien', (tester) async {
      await _ouvrir(tester);
      expect(find.widgetWithText(StatusChip, 'Bon'), findsOneWidget);
      expect(find.widgetWithText(StatusChip, 'Défectueux'), findsOneWidget);
    });

    testWidgets("le filtre ne retient que ce qu'il nomme", (tester) async {
      await _ouvrir(tester);
      await tester.tap(find.widgetWithText(FilterChipPill, 'Défectueux'));
      await tester.pumpAndSettle();
      expect(find.text('Pistolet automatique'), findsOneWidget);
      expect(find.text("Fusil d'assaut — AK 47"), findsNothing);
    });
  });

  testWidgets('une arme sans marquage ne porte pas de tiret orphelin', (
    tester,
  ) async {
    await _ouvrir(tester);
    expect(find.text('Pistolet automatique'), findsOneWidget);
    expect(find.text('Fusil d\'assaut — AK 47'), findsOneWidget);
  });

  group('qui peut importer un registre', () {
    // La base n'ouvre l'écriture sur `arme` qu'à l'armurerie, au chef du
    // soutien technique et à l'administrateur. Un bouton offert à qui le
    // serveur refusera ne vaut pas mieux qu'une absence de bouton.
    for (final role in [
      RoleLogistique.armurerie,
      RoleLogistique.chefSoutienTechnique,
      RoleLogistique.administrateur,
    ]) {
      testWidgets('${role.name} voit le bouton', (tester) async {
        await _ouvrir(tester, role: role);
        expect(find.text('Importer depuis Excel'), findsOneWidget);
      });
    }

    for (final role in [
      RoleLogistique.garage,
      RoleLogistique.soutienPetrolier,
      RoleLogistique.postePolice,
      RoleLogistique.sante,
      RoleLogistique.officierAdjoint,
    ]) {
      testWidgets('${role.name} ne le voit pas', (tester) async {
        await _ouvrir(tester, role: role);
        expect(find.text('Importer depuis Excel'), findsNothing);
      });
    }
  });
}
