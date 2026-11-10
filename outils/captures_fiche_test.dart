// Prend les captures d'écran de la fiche de mises à jour.
//
// Ce n'est pas un test : c'est un outil, rangé hors de `test/` pour que
// `flutter test` ne le ramasse pas. Il s'exécute sous le harnais de test
// parce que c'est le seul endroit où l'on peut dessiner un écran réel sans
// base de données derrière — les mêmes doublures que les tests, les mêmes
// polices, et une image en sortie.
//
//   flutter test outils/captures_fiche_test.dart
//
// Les images vont dans `docs/captures/`.
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// `Override` n'est pas dans l'export principal de Riverpod 3.
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:sig_ensoa/core/chargement.dart';
import 'package:sig_ensoa/core/roles.dart';
import 'package:sig_ensoa/core/theme.dart';
import 'package:sig_ensoa/features/accueil/accueil_screen.dart';
import 'package:sig_ensoa/features/accueil/providers/apercu_providers.dart';
import 'package:sig_ensoa/features/auth/providers/auth_providers.dart';
import 'package:sig_ensoa/features/shell/app_shell.dart';
import 'package:sig_ensoa/models/profil.dart';
import 'package:sig_ensoa/modules/logistique/data/models/armement.dart';
import 'package:sig_ensoa/modules/logistique/data/models/carburant.dart';
import 'package:sig_ensoa/modules/logistique/data/models/maintenance.dart';
import 'package:sig_ensoa/modules/logistique/data/models/notification_item.dart';
import 'package:sig_ensoa/modules/logistique/data/models/oa.dart';
import 'package:sig_ensoa/modules/logistique/data/models/vehicule.dart';
import 'package:sig_ensoa/modules/logistique/data/repositories/armament_providers.dart';
import 'package:sig_ensoa/modules/logistique/data/repositories/fleet_providers.dart';
import 'package:sig_ensoa/modules/logistique/data/repositories/fuel_providers.dart';
import 'package:sig_ensoa/modules/logistique/data/repositories/misc_providers.dart';
import 'package:sig_ensoa/modules/logistique/data/repositories/oa_providers.dart';
import 'package:sig_ensoa/modules/logistique/features/dashboard/soutien_technique_screen.dart';
import 'package:sig_ensoa/modules/logistique/features/tasks/taches_screen.dart';
import 'package:sig_ensoa/modules/scolarite/features/dashboard/providers/dashboard_providers.dart';
import 'package:sig_ensoa/modules/scolarite/features/sante_screen.dart';
import 'package:sig_ensoa/modules/scolarite/features/instruction_screen.dart';
import 'package:sig_ensoa/modules/scolarite/models/division.dart';

const _dossier = 'docs/captures';
final _cadre = GlobalKey();

const _profil = Profil(
  id: 'p1',
  nom: 'DJAMA',
  prenom: 'Yannick',
  roleScolarite: RoleScolarite.admin,
  roleLogistique: RoleLogistique.administrateur,
);

// --- Les doublures, reprises des tests de chaque écran ---------------------

class _Vehicules extends VehiculesNotifier {
  @override
  List<Vehicule> build() => [
    for (var i = 0; i < 22; i++)
      Vehicule(
        id: '$i',
        chassis: 'C$i',
        immatriculation: 'I$i',
        kilometrage: 1000,
        etat: i < 12
            ? EtatVehicule.disponible
            : (i < 18 ? EtatVehicule.enMission : EtatVehicule.enReparation),
        typeVehiculeId: 't${i % 4}',
        kilometrageVidangeProchaine: i < 2 ? 900 : 9000,
        marque: 'TOYOTA',
        modele: 'HILUX',
        typeVehicule: const ['Pick-up', 'Bus', 'Camion', 'Ambulance'][i % 4],
      ),
  ];

  @override
  Future<void> refresh() async {}
}

class _Armes extends ArmesNotifier {
  @override
  List<Arme> build() => const [];

  @override
  Future<void> refresh() async {}
}

class _ChargeAccueil extends ChargementNotifier {
  @override
  Set<String> build() => {
    'vehicules',
    'soutes',
    'soute_stocks',
    'depotages',
    'distributions',
  };
}

SouteVue _soute(String nom, int litres) => SouteVue(
  soute: Soute(id: nom, libelle: nom),
  stock: SouteStock(
    id: nom,
    souteId: nom,
    typeStockId: 't',
    repartitionId: 'r',
    repartitionLibelle: 'r',
    qteGasoil: litres,
    qteSuper: 0,
    seuilNominal: 0,
    seuilCritique: 0,
  ),
);

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

  @override
  Future<void> refresh() async {}
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

  @override
  Future<void> refresh() async {}
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

  @override
  Future<void> refresh() async {}
}

class _ChargeTaches extends ChargementNotifier {
  @override
  Set<String> build() => {'taches', 'activites', 'taches_quotidiennes'};
}

// --- Le soutien technique : les trois services et leurs onglets ------------

class _ChargeSoutien extends ChargementNotifier {
  @override
  Set<String> build() => {
    'vehicules',
    'reparations',
    'soutes',
    'soute_stocks',
    'depotages',
    'distributions',
    'armes',
    'dotations_armes',
    'munitions',
    'equipements',
  };
}

class _Reparations extends ReparationsNotifier {
  @override
  Future<void> refresh() async {}

  @override
  List<Reparation> build() => const [];
}

class _Soutes extends SoutesNotifier {
  @override
  Future<void> refresh() async {}

  @override
  List<Soute> build() => const [
    Soute(id: 's1', libelle: 'BOUAKE'),
    Soute(id: 's2', libelle: 'ABIDJAN'),
    Soute(id: 's3', libelle: 'KATIOLA'),
  ];
}

class _SouteStocks extends SouteStocksNotifier {
  @override
  Future<void> refresh() async {}

  @override
  List<SouteStock> build() => const [
    SouteStock(
      id: 's1',
      souteId: 's1',
      typeStockId: 't',
      repartitionId: 'r',
      repartitionLibelle: 'r',
      qteGasoil: 4360,
      qteSuper: 0,
      seuilNominal: 0,
      seuilCritique: 0,
    ),
    SouteStock(
      id: 's2',
      souteId: 's2',
      typeStockId: 't',
      repartitionId: 'r',
      repartitionLibelle: 'r',
      qteGasoil: 1000,
      qteSuper: 0,
      seuilNominal: 0,
      seuilCritique: 0,
    ),
    SouteStock(
      id: 's3',
      souteId: 's3',
      typeStockId: 't',
      repartitionId: 'r',
      repartitionLibelle: 'r',
      qteGasoil: 185,
      qteSuper: 0,
      seuilNominal: 0,
      seuilCritique: 0,
    ),
  ];
}

class _Depotages extends DepotagesNotifier {
  @override
  Future<void> refresh() async {}

  @override
  List<Depotage> build() => const [];
}

class _Distributions extends DistributionsNotifier {
  @override
  Future<void> refresh() async {}

  @override
  List<Distribution> build() => const [];
}

class _Repartitions extends RepartitionsNotifier {
  @override
  Future<void> refresh() async {}

  @override
  List<Repartition> build() => const [];
}

class _DepotagesInternes extends DepotagesInternesNotifier {
  @override
  Future<void> refresh() async {}

  @override
  List<DepotageInterne> build() => const [];
}

class _Registre extends ArmesNotifier {
  @override
  Future<void> refresh() async {}

  @override
  List<Arme> build() => const [
    Arme(
      id: '1',
      type: "Fusil d'assaut",
      modele: 'AK-47',
      numeroSerie: 'FA-104 235',
      etat: EtatArme.bon,
      positionActuelle: '1re compagnie',
    ),
    Arme(
      id: '2',
      type: "Fusil d'assaut",
      modele: 'AK-47',
      numeroSerie: 'FA-104 236',
      etat: EtatArme.bon,
      positionActuelle: 'Armurerie',
    ),
    Arme(
      id: '3',
      type: 'Pistolet automatique',
      modele: 'PA MAC 50',
      numeroSerie: 'PA-07 118',
      etat: EtatArme.defectueux,
      positionActuelle: 'Atelier',
      observations: 'Percuteur à changer',
    ),
  ];
}

class _SansDotation extends DotationsNotifier {
  @override
  Future<void> refresh() async {}

  @override
  List<DotationArme> build() => const [];
}

class _Munitions extends MunitionsNotifier {
  @override
  Future<void> refresh() async {}

  @override
  List<StockMunition> build() => const [
    StockMunition(
      id: '1',
      calibre: '7.62x54mm',
      quantiteDisponible: 6920,
      seuilCritique: 1000,
      souteArmementId: 'sa1',
    ),
    StockMunition(
      id: '2',
      calibre: '7.62x39mm',
      quantiteDisponible: 4200,
      seuilCritique: 1000,
      souteArmementId: 'sa1',
    ),
    StockMunition(
      id: '3',
      calibre: '9x19mm',
      quantiteDisponible: 1000,
      seuilCritique: 1200,
      souteArmementId: 'sa1',
    ),
  ];
}

class _Equipements extends EquipementsNotifier {
  @override
  Future<void> refresh() async {}

  @override
  List<EquipementProtection> build() => const [
    EquipementProtection(
      id: '1',
      libelle: 'Gilet pare-balles',
      quantiteDisponible: 40,
      seuilCritique: 5,
    ),
    EquipementProtection(
      id: '2',
      libelle: 'Casque lourd',
      quantiteDisponible: 62,
      seuilCritique: 10,
    ),
  ];
}

class _SansNotification extends NotificationsNotifier {
  @override
  Future<void> refresh() async {}

  @override
  List<AppNotification> build() => const [];
}

class _Mouvements extends MouvementsArticleNotifier {
  @override
  Future<void> refresh() async {}

  @override
  List<MouvementArticle> build() => const [];
}

/// Les doublures du soutien technique, communes aux trois services.
/// Les doublures du tableau de bord : les mêmes chiffres servent à la
/// capture de l'écran seul et à celle de la fenêtre entière.
List<Override> _doublureAccueil(DateTime hier) => [
        profilCourantProvider.overrideWith((ref) async => _profil),
        apercuScolariteProvider.overrideWith(
          (ref) async =>
              const ApercuScolarite(apprenants: 203, promotions: 4, classes: 2, cours: 2),
        ),
        apercuLogistiqueProvider.overrideWith(
          (ref) async => const ApercuLogistique(
            vehicules: 22,
            vehiculesDisponibles: 12,
            litresEnSoute: 5620,
            armes: 254,
            armesEnDotation: 0,
          ),
        ),
        dashboardStatsProvider.overrideWith(
          (ref) async => DashboardStats(
            total: 203,
            parDivision: [
              DivisionCount(
                division: Division(
                  id: 'd1',
                  code: 'DFI',
                  nom: 'Division de Formation Initiale',
                ),
                count: 203,
              ),
            ],
          ),
        ),
        chargementProvider.overrideWith(_ChargeAccueil.new),
        vehiculesProvider.overrideWith(_Vehicules.new),
        armesProvider.overrideWith(_Armes.new),
        soutesAvecStockProvider.overrideWith(
          (ref) => [
            _soute('BOUAKE', 4360),
            _soute('ABIDJAN', 1000),
            _soute('KATIOLA', 185),
            _soute('DALOA', 75),
          ],
        ),
        soutesEnAlerteProvider.overrideWith((ref) => []),
        dotationsEnRetardProvider.overrideWith((ref) => []),
        armesInspectionEnRetardProvider.overrideWith((ref) => []),
        journalCarburantProvider.overrideWith(
          (ref) => [
            JournalCarburantEntry(
              date: hier,
              description: 'Dépotage',
              quantite: 5520,
              entree: true,
              auteurId: 'a',
            ),
            JournalCarburantEntry(
              date: DateTime.now(),
              description: 'Distribution',
              quantite: 500,
              entree: false,
              auteurId: 'a',
            ),
          ],
        ),
];

List<Override> _doublureSoutien() => [
  profilCourantProvider.overrideWith((ref) async => _profil),
  chargementProvider.overrideWith(_ChargeSoutien.new),
  vehiculesProvider.overrideWith(_Vehicules.new),
  reparationsProvider.overrideWith(_Reparations.new),
  soutesProvider.overrideWith(_Soutes.new),
  souteStocksProvider.overrideWith(_SouteStocks.new),
  depotagesProvider.overrideWith(_Depotages.new),
  distributionsProvider.overrideWith(_Distributions.new),
  repartitionsProvider.overrideWith(_Repartitions.new),
  depotagesInternesProvider.overrideWith(_DepotagesInternes.new),
  armesProvider.overrideWith(_Registre.new),
  dotationsProvider.overrideWith(_SansDotation.new),
  munitionsProvider.overrideWith(_Munitions.new),
  equipementsProvider.overrideWith(_Equipements.new),
  mouvementsArticleProvider.overrideWith(_Mouvements.new),
];

// --- Le harnais ------------------------------------------------------------

/// Le thème de l'application, tel que `main.dart` le pose : une capture qui
/// ne porterait pas les mêmes couleurs ne montrerait pas l'application.
ThemeData _theme() {
  // Le thème de l'application, moins sa police : `AppTheme` la prend chez
  // Google Fonts, qui la télécharge — impossible sous le harnais, et un
  // texte sans police se dessine en carrés. On garde donc Roboto, chargée
  // au démarrage, et tout le reste de l'application : les couleurs des
  // boutons en particulier, qui sortaient au violet de Material.
  final base = AppTheme.light();
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.cardBg,
    textTheme: base.textTheme.apply(fontFamily: 'Roboto'),
    primaryTextTheme: base.primaryTextTheme.apply(fontFamily: 'Roboto'),
  );
}

Future<void> _dessiner(
  WidgetTester tester, {
  required Size taille,
  required List<Override> doublures,
  required Widget ecran,
  Future<void> Function(WidgetTester)? apres,
}) async {
  tester.view.physicalSize = taille;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await _prechargerImages(tester);

  await tester.pumpWidget(
    RepaintBoundary(
      key: _cadre,
      child: ProviderScope(
        overrides: doublures,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: _theme(),
          home: Scaffold(
            backgroundColor: Colors.white,
            body: Padding(padding: const EdgeInsets.all(28), child: ecran),
          ),
        ),
      ),
    ),
  );
  // Des pompes bornées plutôt que `pumpAndSettle` : un scintillement de
  // chargement ou une animation qui se rejoue indéfiniment ne rend jamais la
  // main, et la capture n'arriverait pas.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(seconds: 1));

  // De quoi ouvrir l'onglet que la capture doit montrer, une fois l'écran
  // dessiné. Les pompes se rejouent après, pour que la bascule s'achève.
  if (apres != null) {
    await apres(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 1));
  }
}

/// Les images d'`assets/` se décodent de façon asynchrone, et le harnais de
/// test ne fait pas tourner la vraie boucle d'évènements : sans cela, l'icône
/// du fusil — un dessin, non une police — n'arrive jamais et laisse un vide.
/// On la décode donc à l'avance, dans `runAsync`, pour que le cache d'images
/// la rende d'un seul coup à la première image dessinée.
Future<void> _prechargerImages(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (final chemin in const ['assets/images/fusil_assaut.png']) {
      final fini = Completer<void>();
      final flux = AssetImage(chemin).resolve(ImageConfiguration.empty);
      late ImageStreamListener ecouteur;
      void termine() {
        flux.removeListener(ecouteur);
        if (!fini.isCompleted) fini.complete();
      }

      ecouteur = ImageStreamListener(
        (_, _) => termine(),
        onError: (erreur, _) {
          stderr.writeln('image $chemin introuvable : $erreur');
          termine();
        },
      );
      flux.addListener(ecouteur);
      await fini.future;
    }
  });
}

/// Enregistre ce qui est dessiné. [hauteurUtile] coupe l'image en bas : pour
/// les rubriques à onglets, seul le bandeau nous intéresse — le corps de
/// l'onglet est un écran que la fiche montre ailleurs.
Future<void> _enregistrer(
  String nom, {
  double? hauteurUtile,
  double? largeurUtile,
}) async {
  final limite =
      _cadre.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await limite.toImage(pixelRatio: 2);
  final octets = await image.toByteData(format: ui.ImageByteFormat.png);
  final fichier = File('$_dossier/$nom.png');
  fichier.parent.createSync(recursive: true);
  fichier.writeAsBytesSync(octets!.buffer.asUint8List());
  // La hauteur utile est écrite à côté : le découpage se fait à la
  // composition de la fiche, qui sait déjà manipuler des images.
  if (hauteurUtile != null) {
    File('$_dossier/$nom.coupe').writeAsStringSync('${hauteurUtile * 2}');
  }
  if (largeurUtile != null) {
    File('$_dossier/$nom.coupel').writeAsStringSync('${largeurUtile * 2}');
  }
  stdout.writeln('capture $nom : ${image.width}x${image.height}');
}

/// Le harnais de test ne charge pas la police des icones Material : sans
/// elle, chaque icone se dessine en carre vide, et la capture ne montre plus
/// l'application. On la lit dans le SDK, a cote du dart qui nous execute.
Future<void> _chargerIconesMaterial() async {
  var dossier = File(Platform.resolvedExecutable).parent; // .../dart-sdk/bin
  for (var i = 0; i < 3; i++) {
    dossier = dossier.parent; // -> .../bin/cache
  }
  final fichier = File(
    '${dossier.path}/artifacts/material_fonts/materialicons-regular.otf',
  );
  if (!fichier.existsSync()) {
    stderr.writeln('police des icones introuvable : ${fichier.path}');
    return;
  }
  final octets = ByteData.sublistView(fichier.readAsBytesSync());
  await (FontLoader('MaterialIcons')..addFont(Future.value(octets))).load();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR');
    final police = FontLoader('Roboto')
      ..addFont(rootBundle.load('assets/fonts/roboto-regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/roboto-bold.ttf'));
    await police.load();
    await _chargerIconesMaterial();
  });

  testWidgets('tableau de bord', (tester) async {
    final hier = DateTime.now().subtract(const Duration(days: 1));
    await _dessiner(
      tester,
      taille: const Size(1500, 1620),
      ecran: const AccueilScreen(),
      doublures: _doublureAccueil(hier),
    );
    await _enregistrer('tableau-de-bord');
  });

  // La fenêtre entière — la barre à gauche, le tableau de bord à droite —
  // telle qu'elle s'ouvre sur le poste du commandant. Le chemin « / » fait
  // recharger les modules : on double donc aussi ce qu'ils vont lire.
  testWidgets('fenêtre', (tester) async {
    final hier = DateTime.now().subtract(const Duration(days: 1));
    await _dessiner(
      tester,
      taille: const Size(1500, 1720),
      ecran: const AppShell(location: '/', child: AccueilScreen()),
      doublures: [
        ..._doublureAccueil(hier),
        notificationsProvider.overrideWith(_SansNotification.new),
        reparationsProvider.overrideWith(_Reparations.new),
        soutesProvider.overrideWith(_Soutes.new),
        souteStocksProvider.overrideWith(_SouteStocks.new),
        depotagesProvider.overrideWith(_Depotages.new),
        distributionsProvider.overrideWith(_Distributions.new),
        dotationsProvider.overrideWith(_SansDotation.new),
        munitionsProvider.overrideWith(_Munitions.new),
        equipementsProvider.overrideWith(_Equipements.new),
        activitesProvider.overrideWith(_Activites.new),
        tachesProvider.overrideWith(_Taches.new),
      ],
    );
    tester.takeException();
    await _enregistrer('fenetre');
  });

  testWidgets('tâches', (tester) async {
    await _dessiner(
      tester,
      taille: const Size(1500, 1020),
      ecran: const TachesScreen(),
      doublures: [
        profilCourantProvider.overrideWith((ref) async => _profil),
        chargementProvider.overrideWith(_ChargeTaches.new),
        tachesProvider.overrideWith(_Taches.new),
        activitesProvider.overrideWith(_Activites.new),
        tachesQuotidiennesProvider.overrideWith(_Quotidiennes.new),
      ],
    );
    await _enregistrer('taches');
  });

  // Les deux rubriques regroupées : c'est le bandeau d'onglets qui porte le
  // changement, le corps de chaque onglet étant l'écran d'avant, repris tel
  // quel. On dessine la rubrique réelle et l'on ne garde que son bandeau.
  for (final (nom, ecran) in <(String, Widget)>[
    ('instruction', InstructionScreen()),
    ('sante', SanteScreen()),
  ]) {
    testWidgets('rubrique $nom', (tester) async {
      await _dessiner(
        tester,
        taille: const Size(1500, 700),
        ecran: ecran,
        doublures: [
          profilCourantProvider.overrideWith((ref) async => _profil),
        ],
      );
      // Le corps de l'onglet cherche sa base ; on ne le montre pas, et son
      // échec ne doit pas faire tomber la capture du bandeau.
      tester.takeException();
      await _enregistrer('rubrique-$nom', hauteurUtile: 137.5);
    });
  }

  // Les deux services qui gagnent leurs onglets. Le soutien pétrolier se
  // montre tel qu'il s'ouvre ; l'armurerie, sur sa rubrique « Armement », où
  // les trois niveaux d'onglets se lisent d'un coup.
  testWidgets('soutien pétrolier', (tester) async {
    await _dessiner(
      tester,
      taille: const Size(1500, 1000),
      ecran: const SoutienTechniqueScreen(),
      doublures: _doublureSoutien(),
      apres: (t) async =>
          t.tap(find.widgetWithText(Tab, 'Soutien pétrolier')),
    );
    tester.takeException();
    await _enregistrer('service-soutien-petrolier');
  });

  testWidgets('armurerie', (tester) async {
    await _dessiner(
      tester,
      taille: const Size(1500, 1000),
      ecran: const SoutienTechniqueScreen(),
      doublures: _doublureSoutien(),
      apres: (t) async {
        await t.tap(find.widgetWithText(Tab, 'Armurerie'));
        await t.pump();
        await t.pump(const Duration(milliseconds: 400));
        await t.tap(find.widgetWithText(Tab, 'Armement'));
      },
    );
    tester.takeException();
    await _enregistrer('service-armurerie');
  });

  // Le menu, qui écrit désormais le nom de chaque entrée. On dessine le cadre
  // entier — c'est lui qui porte la barre — et l'on n'en garde que la colonne
  // de gauche.
  testWidgets('menu', (tester) async {
    await _dessiner(
      tester,
      taille: const Size(1300, 790),
      // Un chemin qui ne recharge rien, et qui montre une entrée active : la
      // pilule foncée fait partie de ce qu'on vient regarder.
      ecran: const AppShell(
        location: '/administration',
        child: SizedBox.shrink(),
      ),
      doublures: [
        profilCourantProvider.overrideWith((ref) async => _profil),
        notificationsProvider.overrideWith(_SansNotification.new),
      ],
    );
    tester.takeException();
    await _enregistrer('menu', largeurUtile: 300, hauteurUtile: 782);
  });
}
