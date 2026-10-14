import 'package:flutter_test/flutter_test.dart';

import 'package:sig_ensoa/modules/logistique/data/models/vehicule.dart';
import 'package:sig_ensoa/modules/logistique/features/fleet/import_vehicules.dart';

/// Ce que l'import doit reconnaître avant d'écrire quoi que ce soit.
///
/// L'enjeu n'est pas de lire un tableur : c'est de ne pas verser deux fois
/// le même camion dans le parc. Un import se fait une fois, et un doublon
/// s'y rattrape ensuite à la main, véhicule par véhicule.

Vehicule _auParc(String immatriculation, {String marque = 'Toyota'}) =>
    Vehicule(
      id: '1',
      chassis: 'CH-$immatriculation',
      immatriculation: immatriculation,
      kilometrage: 120000,
      etat: EtatVehicule.disponible,
      typeVehiculeId: '1',
      kilometrageVidangeProchaine: 125000,
      marque: marque,
      modele: 'Land Cruiser',
      typeVehicule: 'Station Wagon',
    );

/// Une ligne complète et valide, dont on ne change que ce qui est en cause.
List<String> _ligne({
  String immatriculation = '1234 AA 01',
  String chassis = 'JTEBH9FJ70K123456',
  String marque = 'Toyota',
  String modele = 'Land Cruiser',
  String type = 'Station Wagon',
  String kilometrage = '125000',
  String places = '5',
  String vidange = '130000',
  String etat = 'Disponible',
  String position = '',
  String observations = '',
}) => [
  immatriculation,
  chassis,
  marque,
  modele,
  type,
  kilometrage,
  places,
  vidange,
  etat,
  position,
  observations,
];

void main() {
  group('reconnaître un véhicule déjà au parc', () {
    test('par son immatriculation, quelle qu\'en soit l\'écriture', () {
      // Le fichier d'un service, la base d'un autre : les séparateurs
      // diffèrent, le camion est le même.
      for (final ecriture in [
        '1234 AA 01',
        '1234AA01',
        '1234-AA-01',
        '1234 aa 01',
        '  1234 AA 01  ',
      ]) {
        final lignes = analyserLignes(
          brutes: [_ligne(immatriculation: ecriture)],
          parcExistant: [_auParc('1234AA01')],
        );
        expect(
          lignes.single.statut,
          StatutLigne.dejaPresent,
          reason: '« $ecriture » n\'a pas été reconnue',
        );
        expect(lignes.single.existant, isNotNull);
      }
    });

    test('un véhicule retiré du parc est rétabli, pas recréé', () {
      // Le défaut qui a fait échouer l'import du parc de l'ENSOA : « 310 40
      // 026 » était en base, marquée supprimée. Invisible à l'écran, mais
      // l'index unique lui réservait toujours sa plaque — l'import annonçait
      // « à créer », et le lot entier tombait sur la contrainte.
      final lignes = analyserLignes(
        brutes: [_ligne(immatriculation: '310 40 026')],
        parcExistant: const [],
        parcRetire: [_auParc('310 40 026', marque: 'HOWO')],
      );

      expect(lignes.single.statut, StatutLigne.aRetablir);
      expect(lignes.single.existant, isNotNull);
    });

    test('le parc en service l\'emporte sur le parc retiré', () {
      // Si la même plaque figurait des deux côtés — ce que la base interdit
      // mais qu'un cache en retard peut montrer —, c'est le véhicule en
      // service qui compte : le rétablir n'aurait aucun sens.
      final lignes = analyserLignes(
        brutes: [_ligne(immatriculation: '1234 AA 01')],
        parcExistant: [_auParc('1234AA01')],
        parcRetire: [_auParc('1234 AA 01')],
      );
      expect(lignes.single.statut, StatutLigne.dejaPresent);
    });

    test('une plaque retirée vue deux fois dans le fichier ne l\'est qu\'une '
        'fois à rétablir', () {
      final lignes = analyserLignes(
        brutes: [
          _ligne(immatriculation: '310 40 026'),
          _ligne(immatriculation: '310-40-026'),
        ],
        parcExistant: const [],
        parcRetire: [_auParc('310 40 026')],
      );
      expect(lignes[0].statut, StatutLigne.aRetablir);
      expect(lignes[1].statut, StatutLigne.doublonDansLeFichier);
    });

    test('une immatriculation inconnue est à créer', () {
      final lignes = analyserLignes(
        brutes: [_ligne(immatriculation: '9999 ZZ 99')],
        parcExistant: [_auParc('1234AA01')],
      );
      expect(lignes.single.statut, StatutLigne.nouveau);
      expect(lignes.single.existant, isNull);
    });

    test('deux lignes du fichier pour le même véhicule : la première passe',
        () {
      final lignes = analyserLignes(
        brutes: [
          _ligne(immatriculation: '5555 BB 02'),
          _ligne(immatriculation: '5555-bb-02', chassis: 'AUTRE'),
        ],
        parcExistant: const [],
      );
      expect(lignes[0].statut, StatutLigne.nouveau);
      expect(lignes[1].statut, StatutLigne.doublonDansLeFichier);
    });
  });

  group('ce qui bloque une ligne', () {
    test('les colonnes obligatoires', () {
      for (final (champ, brute) in [
        ('Immatriculation', _ligne(immatriculation: '')),
        ('Châssis', _ligne(chassis: '')),
        ('Marque', _ligne(marque: '')),
        ('Modèle', _ligne(modele: '')),
        ('Type', _ligne(type: '')),
      ]) {
        final ligne = analyserLignes(
          brutes: [brute],
          parcExistant: const [],
        ).single;
        expect(ligne.statut, StatutLigne.erreur, reason: champ);
      }
    });

    test('un nombre illisible', () {
      final ligne = analyserLignes(
        brutes: [_ligne(kilometrage: 'environ 120 000')],
        parcExistant: const [],
      ).single;
      expect(ligne.statut, StatutLigne.erreur);
      expect(ligne.erreurs.single, contains('Kilométrage'));
    });

    test('un état inconnu est refusé, pas replié sur « disponible »', () {
      // Un camion hors service versé au parc disponible, c'est une mission
      // qu'on croit pouvoir monter.
      final ligne = analyserLignes(
        brutes: [_ligne(etat: 'immobilisé')],
        parcExistant: const [],
      ).single;
      expect(ligne.statut, StatutLigne.erreur);
      expect(ligne.erreurs.single, contains('État inconnu'));
    });

    test('une ligne en erreur n\'est jamais dite « déjà présente »', () {
      // Sans immatriculation, il n'y a rien à confronter au parc : annoncer
      // « déjà présent » serait un hasard de chaîne vide.
      final ligne = analyserLignes(
        brutes: [_ligne(immatriculation: '')],
        parcExistant: [_auParc('')],
      ).single;
      expect(ligne.statut, StatutLigne.erreur);
    });

    test('les lignes vides du bas de feuille sont ignorées', () {
      final lignes = analyserLignes(
        brutes: [
          _ligne(),
          List.filled(colonnesVehicule.length, ''),
          List.filled(colonnesVehicule.length, '   '),
        ],
        parcExistant: const [],
      );
      expect(lignes, hasLength(1));
    });
  });

  group('ce qui sera écrit', () {
    test('les conventions annoncées s\'appliquent', () {
      final ligne = analyserLignes(
        brutes: [
          _ligne(kilometrage: '', places: '', vidange: '', etat: ''),
        ],
        parcExistant: const [],
      ).single;
      final v = construireImport(ligne);

      expect(v.kilometrage, 0);
      expect(v.nbrePlaces, 5);
      expect(v.kilometrageVidangeProchaine, 5000); // 0 + 5 000
      expect(v.etat, EtatVehicule.disponible);
      expect(v.positionActuelle, isNull);
    });

    test('la prochaine vidange suit le kilométrage lu', () {
      final ligne = analyserLignes(
        brutes: [_ligne(kilometrage: '125 000', vidange: '')],
        parcExistant: const [],
      ).single;
      expect(construireImport(ligne).kilometrageVidangeProchaine, 130000);
    });

    test('un tableur qui écrit 5.0 ne crée pas un véhicule de 5,0 places', () {
      final ligne = analyserLignes(
        brutes: [_ligne(places: '5.0', kilometrage: '125000.0')],
        parcExistant: const [],
      ).single;
      final v = construireImport(ligne);
      expect(v.nbrePlaces, 5);
      expect(v.kilometrage, 125000);
    });

    test('l\'immatriculation est écrite en capitales', () {
      final ligne = analyserLignes(
        brutes: [_ligne(immatriculation: '1234 aa 01')],
        parcExistant: const [],
      ).single;
      expect(construireImport(ligne).immatriculation, '1234 AA 01');
    });

    test('les états s\'écrivent comme on les écrit à la main', () {
      expect(lireEtat('Hors service'), EtatVehicule.horsService);
      expect(lireEtat('hors_service'), EtatVehicule.horsService);
      expect(lireEtat('En réparation'), EtatVehicule.enReparation);
      expect(lireEtat('en reparation'), EtatVehicule.enReparation);
      expect(lireEtat('EN MISSION'), EtatVehicule.enMission);
      expect(lireEtat(''), EtatVehicule.disponible);
    });
  });

  test('le numéro de ligne est celui qu\'affiche le tableur', () {
    // L'en-tête occupe la ligne 1 : la première donnée est en ligne 2.
    final lignes = analyserLignes(
      brutes: [_ligne(immatriculation: 'A1'), _ligne(immatriculation: 'A2')],
      parcExistant: const [],
    );
    expect(lignes.map((l) => l.numero), [2, 3]);
  });
}
