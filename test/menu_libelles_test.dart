// Le menu dit le nom de chaque entrée, pas seulement son icône.
//
// Une icône seule se devine ; elle ne se lit pas. L'infobulle, elle, oblige à
// s'arrêter dessus et ne paraît pas au doigt. Dès que la fenêtre en a la
// place, le nom s'écrit à côté de l'icône ; sous 900 pixels de large, la
// barre se referme et l'infobulle reprend son office.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sig_ensoa/core/roles.dart';
import 'package:sig_ensoa/features/auth/providers/auth_providers.dart';
import 'package:sig_ensoa/features/shell/app_shell.dart';
import 'package:sig_ensoa/models/profil.dart';
import 'package:sig_ensoa/modules/logistique/data/models/notification_item.dart';
import 'package:sig_ensoa/modules/logistique/data/repositories/misc_providers.dart';

class _SansNotification extends NotificationsNotifier {
  @override
  Future<void> refresh() async {}

  @override
  List<AppNotification> build() => const [];
}

Future<void> _ouvrir(WidgetTester tester, Size taille) async {
  tester.view.physicalSize = taille;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        notificationsProvider.overrideWith(_SansNotification.new),
        profilCourantProvider.overrideWith(
          (ref) async => const Profil(
            id: 'p1',
            nom: 'DJAMA',
            prenom: 'Yannick',
            roleLogistique: RoleLogistique.administrateur,
          ),
        ),
      ],
      child: const MaterialApp(
        // Un chemin hors des modules : le cadre ne déclenche alors aucun
        // rechargement, et la barre se dessine seule.
        home: AppShell(
          location: '/scolarite/apprenants',
          child: SizedBox.shrink(),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('sur un écran large, chaque entrée porte son nom', (
    tester,
  ) async {
    await _ouvrir(tester, const Size(1600, 1200));
    for (final libelle in [
      'Tableau de bord',
      'Notifications',
      'Activités',
      'Poste de Police',
      'Administration',
      'Déconnexion',
    ]) {
      expect(
        find.text(libelle),
        findsOneWidget,
        reason: '« $libelle » doit se lire dans le menu',
      );
    }
  });

  testWidgets('« Tâches » a cédé la place à « Activités »', (tester) async {
    await _ouvrir(tester, const Size(1600, 1200));
    expect(find.text('Activités'), findsOneWidget);
    expect(find.text('Tâches'), findsNothing);
  });

  testWidgets('sur un écran étroit, la barre se referme sur ses icônes', (
    tester,
  ) async {
    // La place y vaut mieux au contenu ; l'infobulle porte alors le nom.
    await _ouvrir(tester, const Size(800, 1200));
    expect(find.text('Activités'), findsNothing);
    expect(
      find.byWidgetPredicate((w) => w is Tooltip && w.message == 'Activités'),
      findsOneWidget,
    );
  });
}
