// L'onglet « Activités » des cellules : ce qu'il retient, et s'il tient de
// l'écran de bureau au téléphone.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:sig_ensoa/core/chargement.dart';
import 'package:sig_ensoa/core/roles.dart';
import 'package:sig_ensoa/features/auth/providers/auth_providers.dart';
import 'package:sig_ensoa/models/profil.dart';
import 'package:sig_ensoa/modules/logistique/data/models/oa.dart';
import 'package:sig_ensoa/modules/logistique/data/repositories/oa_providers.dart';
import 'package:sig_ensoa/modules/logistique/features/oa/activites_cellule_tab.dart';

final _demain = DateTime.now().add(const Duration(days: 1));
final _aujourdhui = DateTime(
  DateTime.now().year,
  DateTime.now().month,
  DateTime.now().day,
);

Activite _activite(String id, DateTime date, {StatutActivite? statut}) =>
    Activite(
      id: id,
      titre: 'Activité $id',
      dateActivite: date,
      lieu: 'Zambakro',
      statut: statut ?? StatutActivite.planifiee,
      creePar: 'p1',
      creeLe: DateTime.now(),
    );

class _Activites extends ActivitesNotifier {
  @override
  List<Activite> build() => [
    _activite('hier', _aujourdhui.subtract(const Duration(hours: 2))),
    _activite('future', _demain),
    // Ce matin à 0 h 01 : passée d'heure, mais du jour — elle reste.
    _activite('matin', _aujourdhui.add(const Duration(minutes: 1))),
    _activite('close', _demain, statut: StatutActivite.terminee),
    _activite('annulee', _demain, statut: StatutActivite.annulee),
  ];
}

class _Taches extends TachesNotifier {
  @override
  List<TacheActivite> build() => [
    TacheActivite(
      id: '1',
      activiteId: 'future',
      acteur: ActeurTache.garage,
      description: 'Préparer les véhicules du défilé',
      dateLimite: _demain,
    ),
    TacheActivite(
      id: '2',
      activiteId: 'future',
      acteur: ActeurTache.armurerie,
      description: 'Contrôler les armes de la garde',
    ),
    TacheActivite(
      id: '3',
      activiteId: 'matin',
      acteur: ActeurTache.garage,
      assigneA: 'p9',
      assigneNom: 'SGT KONE Ali',
      description: 'Ramener le car',
      statut: StatutTache.terminee,
    ),
  ];
}

class _ToutCharge extends ChargementNotifier {
  @override
  Set<String> build() => {'taches', 'activites'};
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
            nom: 'KOFFI',
            prenom: 'Jean',
            roleLogistique: RoleLogistique.garage,
          ),
        ),
        chargementProvider.overrideWith(_ToutCharge.new),
        tachesProvider.overrideWith(_Taches.new),
        activitesProvider.overrideWith(_Activites.new),
        mesTachesProvider.overrideWith(
          (ref) => ref
              .watch(tachesProvider)
              .where((t) => t.acteur == ActeurTache.garage)
              .toList(),
        ),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: ActivitesCelluleTab(
            acteur: ActeurTache.garage,
            cellule: 'le Garage',
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  test('une tâche de la cellule, ou nommément à soi', () {
    final taches = [
      const TacheActivite(
        id: 'a',
        activiteId: 'x',
        acteur: ActeurTache.garage,
        description: 'A',
      ),
      const TacheActivite(
        id: 'b',
        activiteId: 'x',
        acteur: ActeurTache.armurerie,
        description: 'B',
      ),
      const TacheActivite(
        id: 'c',
        activiteId: 'x',
        assigneA: 'moi',
        assigneNom: 'Moi',
        description: 'C',
      ),
      const TacheActivite(
        id: 'd',
        activiteId: 'x',
        acteur: ActeurTache.garage,
        description: 'D',
        statut: StatutTache.annulee,
      ),
      const TacheActivite(
        id: 'e',
        activiteId: 'y',
        acteur: ActeurTache.garage,
        description: 'E',
      ),
    ];
    expect(
      tachesDeLaCellule(
        taches,
        activiteId: 'x',
        acteur: ActeurTache.garage,
        mesTaches: {'c'},
      ).map((t) => t.id),
      ['a', 'c'],
    );
    // Le Poste de Police n'a pas de tâche de service : seulement les siennes.
    expect(
      tachesDeLaCellule(
        taches,
        activiteId: 'x',
        mesTaches: {'c'},
      ).map((t) => t.id),
      ['c'],
    );
  });

  test("d'aujourd'hui ou plus tard, de la plus proche à la plus loin", () {
    final maintenant = _aujourdhui.add(const Duration(hours: 15));
    final retenues = activitesDeLaCellule([
      _activite('loin', _aujourdhui.add(const Duration(days: 30))),
      _activite('hier', _aujourdhui.subtract(const Duration(minutes: 1))),
      _activite('ce matin', _aujourdhui.add(const Duration(hours: 8))),
      _activite('demain', _aujourdhui.add(const Duration(days: 1))),
      _activite(
        'annulee',
        _aujourdhui.add(const Duration(days: 2)),
        statut: StatutActivite.annulee,
      ),
    ], maintenant);
    expect(retenues.map((a) => a.id), ['ce matin', 'demain', 'loin']);
  });

  for (final (nom, taille) in [
    ('le poste de bureau', const Size(1400, 1000)),
    ('le téléphone', const Size(390, 844)),
  ]) {
    testWidgets("l'onglet tient sur $nom", (tester) async {
      await _ouvrir(tester, taille);
      expect(tester.takeException(), isNull);

      expect(find.text('Activités à venir (2)'), findsOneWidget);
      // Ni celle d'hier, ni la terminée, ni l'annulée.
      expect(find.text('Activité hier'), findsNothing);
      expect(find.text('Activité close'), findsNothing);
      expect(find.text('Activité annulee'), findsNothing);

      // La tâche du Garage paraît, celle de l'Armurerie non.
      expect(find.text('Préparer les véhicules du défilé'), findsOneWidget);
      expect(find.text('Contrôler les armes de la garde'), findsNothing);
      expect(find.text('Terminée'), findsOneWidget);
      expect(find.textContaining('SGT KONE Ali'), findsOneWidget);
    });
  }
}
