// La liste des tâches : comment les deux sortes de tâches se rangent, et si
// l'écran tient de l'écran de bureau au téléphone.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:sig_ensoa/core/chargement.dart';
import 'package:sig_ensoa/core/roles.dart';
import 'package:sig_ensoa/core/theme.dart';
import 'package:sig_ensoa/features/auth/providers/auth_providers.dart';
import 'package:sig_ensoa/models/profil.dart';
import 'package:sig_ensoa/modules/logistique/data/models/oa.dart';
import 'package:sig_ensoa/modules/logistique/data/repositories/oa_providers.dart';
import 'package:sig_ensoa/modules/logistique/features/tasks/taches_screen.dart';
import 'package:sig_ensoa/modules/logistique/features/tasks/taches_vue.dart';

final _maintenant = DateTime(2026, 11, 6, 10);

class _Taches extends TachesNotifier {
  @override
  List<TacheActivite> build() => [
    TacheActivite(
      id: '1',
      activiteId: 'a1',
      acteur: ActeurTache.garage,
      description: 'Préparer les véhicules du défilé',
      dateLimite: DateTime.now().add(const Duration(days: 4)),
    ),
    TacheActivite(
      id: '2',
      activiteId: 'a1',
      acteur: ActeurTache.armurerie,
      description: 'Contrôler les armes de la garde',
      dateLimite: DateTime.now().subtract(const Duration(days: 2)),
    ),
    TacheActivite(
      id: '3',
      activiteId: 'a1',
      acteur: ActeurTache.st,
      description: 'Livrer le carburant',
      dateLimite: DateTime.now().add(const Duration(days: 1)),
      statut: StatutTache.terminee,
    ),
  ];
}

class _Activites extends ActivitesNotifier {
  @override
  List<Activite> build() => [
    Activite(
      id: 'a1',
      titre: "Fête de l'école",
      dateActivite: DateTime.now().add(const Duration(days: 8)),
      creePar: 'p1',
      creeLe: DateTime.now(),
    ),
  ];
}

class _Quotidiennes extends TachesQuotidiennesNotifier {
  @override
  List<TacheQuotidienne> build() => [
    TacheQuotidienne(
      id: '10',
      description: 'Signer le rapport hebdomadaire',
      echeance: DateTime.now(),
      priorite: PrioriteTache.urgente,
      assigneA: 'p1',
      creePar: 'p1',
      assigneNom: 'LCL DJAMA Yannick',
    ),
    TacheQuotidienne(
      id: '11',
      description: 'Relire le planning des gardes',
      priorite: PrioriteTache.importante,
      assigneA: 'p2',
      creePar: 'p1',
      assigneNom: 'CNE KOUAME Yao',
      creeParNom: 'LCL DJAMA Yannick',
    ),
    TacheQuotidienne(
      id: '12',
      description: 'Appeler le service de santé',
      assigneA: 'p1',
      creePar: 'p1',
      assigneNom: 'LCL DJAMA Yannick',
      termineeLe: DateTime.now(),
    ),
  ];
}

class _ToutCharge extends ChargementNotifier {
  @override
  Set<String> build() => {'taches', 'activites', 'taches_quotidiennes'};
}

Future<void> _ouvrir(WidgetTester tester, Size taille) async {
  tester.view.physicalSize = taille;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        profilCourantProvider.overrideWith(
          (ref) async => const Profil(
            id: 'p1',
            nom: 'DJAMA',
            prenom: 'Yannick',
            roleLogistique: RoleLogistique.administrateur,
          ),
        ),
        chargementProvider.overrideWith(_ToutCharge.new),
        tachesProvider.overrideWith(_Taches.new),
        activitesProvider.overrideWith(_Activites.new),
        tachesQuotidiennesProvider.overrideWith(_Quotidiennes.new),
      ],
      child: MaterialApp(
        theme: ThemeData(
          fontFamily: 'Roboto',
          scaffoldBackgroundColor: AppColors.cardBg,
          cardTheme: CardThemeData(
            elevation: 0,
            margin: EdgeInsets.zero,
            color: AppColors.blueMist,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.card),
              side: const BorderSide(color: AppColors.border),
            ),
          ),
        ),
        home: const Scaffold(
          body: Padding(padding: EdgeInsets.all(32), child: TachesScreen()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

LigneTache _ligne(
  String cle, {
  DateTime? echeance,
  bool faite = false,
  bool visa = false,
  String? activite,
  String personne = 'Garage',
  bool aMoi = false,
  PrioriteTache priorite = PrioriteTache.normale,
}) => LigneTache(
  cle: cle,
  titre: cle,
  echeance: echeance,
  faite: faite,
  enAttenteVisa: visa,
  contexte: activite ?? 'Tâche quotidienne',
  activiteId: activite,
  personne: personne,
  aMoi: aMoi,
  priorite: priorite,
);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR');
    final police = FontLoader('Roboto')
      ..addFont(rootBundle.load('assets/fonts/roboto-regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/roboto-bold.ttf'));
    await police.load();
  });

  group('le rangement', () {
    test('ce qui presse passe devant, ce qui est fait à la fin', () {
      final sections = sectionsDe([
        _ligne('sans'),
        _ligne('faite', faite: true, echeance: DateTime(2026, 11, 1)),
        _ligne('tard', echeance: DateTime(2026, 11, 20)),
        _ligne('jour', echeance: DateTime(2026, 11, 6)),
        _ligne('retard', echeance: DateTime(2026, 11, 2)),
      ], _maintenant);

      expect(sections.map((s) => s.$1), [
        'En retard',
        "Aujourd'hui",
        'Plus tard',
        'Sans échéance',
        'Terminées',
      ]);
      expect(sections.first.$2.single.cle, 'retard');
    });

    test("une échéance sans heure court jusqu'au soir", () {
      expect(
        _ligne('l', echeance: DateTime(2026, 11, 6)).enRetard(_maintenant),
        isFalse,
      );
      expect(
        _ligne('l', echeance: DateTime(2026, 11, 6, 8)).enRetard(_maintenant),
        isTrue,
      );
    });

    test("une tâche en attente de visa n'est plus en retard", () {
      final l = _ligne('l', echeance: DateTime(2026, 11, 1), visa: true);
      expect(l.enRetard(_maintenant), isFalse);
    });

    test("à date égale, l'urgent passe d'abord", () {
      final jour = DateTime(2026, 11, 6);
      final sections = sectionsDe([
        _ligne('normale', echeance: jour),
        _ligne('urgente', echeance: jour, priorite: PrioriteTache.urgente),
      ], _maintenant);
      expect(sections.single.$2.first.cle, 'urgente');
    });
  });

  group('les filtres', () {
    final lignes = [
      _ligne('a', activite: 'a1', echeance: DateTime(2026, 11, 6)),
      _ligne('b', personne: 'KOUAME', aMoi: true),
      _ligne('c', echeance: DateTime(2026, 11, 9)),
    ];

    List<String> cles(List<LigneTache> l) => l.map((x) => x.cle).toList();

    test('sépare les tâches quotidiennes de celles des activités', () {
      expect(
        cles(
          filtrerLignes(
            lignes,
            maintenant: _maintenant,
            activite: cleTachesQuotidiennes,
          ),
        ),
        ['b', 'c'],
      );
      expect(
        cles(filtrerLignes(lignes, maintenant: _maintenant, activite: 'a1')),
        ['a'],
      );
    });

    test('retrouve mes tâches, ou celles de quelqu\'un', () {
      expect(
        cles(filtrerLignes(lignes, maintenant: _maintenant, personne: cleMoi)),
        ['b'],
      );
      expect(
        cles(
          filtrerLignes(lignes, maintenant: _maintenant, personne: 'Garage'),
        ),
        ['a', 'c'],
      );
    });

    test("distingue aujourd'hui, à venir, et un jour du calendrier", () {
      expect(
        cles(
          filtrerLignes(
            lignes,
            maintenant: _maintenant,
            segment: SegmentTaches.aujourdhui,
          ),
        ),
        ['a'],
      );
      expect(
        cles(
          filtrerLignes(
            lignes,
            maintenant: _maintenant,
            segment: SegmentTaches.aVenir,
          ),
        ),
        ['c'],
      );
      expect(
        cles(
          filtrerLignes(
            lignes,
            maintenant: _maintenant,
            jour: DateTime(2026, 11, 9),
          ),
        ),
        ['c'],
      );
    });
  });

  test('une tâche annulée ne paraît pas', () {
    final lignes = construireLignes(
      taches: const [
        TacheActivite(
          id: '1',
          activiteId: 'a',
          acteur: ActeurTache.garage,
          description: 'x',
          statut: StatutTache.annulee,
        ),
      ],
      mesTaches: const {},
      activites: const [],
      quotidiennes: const [],
      moi: 'p1',
    );
    expect(lignes, isEmpty);
  });

  for (final (nom, taille) in [
    ('le poste de bureau', const Size(1680, 1000)),
    ('la tablette', const Size(1000, 800)),
    ('le téléphone', const Size(420, 800)),
  ]) {
    testWidgets("l'écran tient sur $nom", (tester) async {
      await _ouvrir(tester, taille);

      expect(find.text('Ajouter une tâche'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
