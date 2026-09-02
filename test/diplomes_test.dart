// Rejoue, sans serveur ni écran, la séquence qui échoue à l'usage : ouvrir
// le sélecteur de diplômes, en saisir un qui n'existe pas au catalogue,
// l'ajouter, valider.
//
// Un test plutôt qu'un essai à la main sur l'émulateur : il est reproductible,
// il s'exécute en deux secondes, et il restera là pour empêcher la panne de
// revenir.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sig_ensoa/modules/scolarite/models/classe.dart';
import 'package:sig_ensoa/modules/scolarite/models/diplome.dart';
import 'package:sig_ensoa/modules/scolarite/models/division.dart';
import 'package:sig_ensoa/modules/scolarite/features/apprenants/register_apprenant_dialog.dart';

const _division = Division(id: 'div-1', code: 'DFI', nom: 'Division test');

final _classe = Classe(
  id: 'cls-1',
  divisionId: 'div-1',
  nom: 'FCB',
  type: ClasseType.phase,
);

void main() {
  testWidgets('un diplôme absent du catalogue s\'ajoute et se retient', (
    tester,
  ) async {
    // La boîte fait 660 x 700 : dans la fenêtre de 800 x 600 du banc d'essai,
    // elle déborderait, et Flutter compte un débordement comme un échec.
    tester.view.physicalSize = const Size(1400, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Catalogue volontairement pauvre : le diplôme saisi n'y figure
          // pas, ce qui est le cas qui échoue.
          diplomesProvider.overrideWith(
            (ref) async => const [Diplome(id: 'd1', nom: 'BAC')],
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showRegisterApprenantDialog(
                  context,
                  division: _division,
                  classe: _classe,
                ),
                child: const Text('ouvrir'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();

    // --- Franchir les étapes qui précèdent la formation civile ------------
    // Nom et Prénoms sont obligatoires : sans eux, « Suivant » ne passe pas.
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nom'),
      'KOUASSI',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Prénoms'),
      'Gérard',
    );
    await tester.pump();

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.widgetWithText(FilledButton, 'Suivant'));
      await tester.pumpAndSettle();
    }

    // --- Atteindre la section « Diplôme(s) » ------------------------------
    final bouton = find.widgetWithText(OutlinedButton, 'Ajouter un diplôme');
    expect(bouton, findsOneWidget, reason: 'la section Diplômes doit exister');
    await tester.ensureVisible(bouton);
    await tester.pumpAndSettle();
    await tester.tap(bouton);
    await tester.pumpAndSettle();

    // --- Saisir un diplôme qui n'existe pas encore ------------------------
    await tester.enterText(
      find.widgetWithText(TextField, 'Nouveau diplôme...'),
      'BTS Comptabilité',
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(CheckboxListTile, 'BTS Comptabilité'),
      findsOneWidget,
      reason: 'le diplôme saisi doit rejoindre la liste à cocher',
    );

    // --- Valider ----------------------------------------------------------
    await tester.tap(find.widgetWithText(FilledButton, 'Valider'));
    await tester.pumpAndSettle();

    // Il doit maintenant figurer parmi les diplômes retenus de la fiche.
    // Il doit maintenant figurer parmi les diplômes retenus de la fiche.
    expect(find.widgetWithText(InputChip, 'BTS Comptabilité'), findsOneWidget);
    expect(find.text('Aucun diplôme sélectionné.'), findsNothing);
  });
}
