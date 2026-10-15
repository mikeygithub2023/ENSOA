import 'package:flutter_test/flutter_test.dart';

import 'package:sig_ensoa/modules/logistique/data/models/armement.dart';
import 'package:sig_ensoa/modules/logistique/features/armament/import_armes.dart';

/// Ce que l'import d'un registre d'armes doit reconnaître avant d'écrire
/// quoi que ce soit.
///
/// L'enjeu n'est pas de lire un tableur : c'est qu'une arme n'entre pas
/// deux fois au registre, et qu'aucune n'y entre sous un état qu'elle n'a
/// pas. Un registre d'armurerie se relit des années après ; ce qu'on y
/// verse de travers y reste.

Arme _auRegistre(
  String numeroSerie, {
  String designation = 'Fusil d\'assaut',
  String marquage = 'AK 47',
  EtatArme etat = EtatArme.bon,
  String? position,
}) => Arme(
  id: '1',
  numeroSerie: numeroSerie,
  type: designation,
  modele: marquage,
  etat: etat,
  positionActuelle: position,
);

/// Une ligne complète et valide, dont on ne change que ce qui est en cause.
List<String> _ligne({
  String designation = 'Fusil d\'assaut',
  String marquage = 'AK 47',
  String numeroSerie = '1975-A-04412',
  String position = 'Armurerie',
  String etat = 'BON',
  String observations = '',
}) => [designation, marquage, numeroSerie, position, etat, observations];

void main() {
  group('le numéro de série, et lui seul, dit si l\'arme est connue', () {
    test('deux écritures du même numéro désignent la même arme', () {
      expect(
        normaliserNumeroSerie('1975-A-04412'),
        normaliserNumeroSerie('1975 a 04412'),
      );
      expect(
        normaliserNumeroSerie('1975A04412'),
        normaliserNumeroSerie('1975/A/04412'),
      );
    });

    test('deux numéros différents restent différents', () {
      expect(
        normaliserNumeroSerie('1975-A-04412') ==
            normaliserNumeroSerie('1975-A-04413'),
        isFalse,
      );
    });

    test('une arme déjà au registre n\'est pas recréée', () {
      final lignes = analyserLignesArmes(
        brutes: [_ligne(numeroSerie: '1975 A 04412')],
        registreExistant: [_auRegistre('1975-A-04412')],
      );
      expect(lignes.single.statut, StatutLigneArme.dejaPresent);
      expect(lignes.single.existante, isNotNull);
    });

    test('une arme inconnue est créée', () {
      final lignes = analyserLignesArmes(
        brutes: [_ligne(numeroSerie: '1975-A-99999')],
        registreExistant: [_auRegistre('1975-A-04412')],
      );
      expect(lignes.single.statut, StatutLigneArme.nouveau);
    });
  });

  group('les armes retirées du registre', () {
    // Le défaut le plus coûteux de cet écran, et celui qui avait déjà
    // fait tomber l'import du parc automobile : invisible partout
    // ailleurs, une arme retirée garde son numéro de série, et la
    // contrainte d'unicité le lui réserve.
    test('une arme retirée est rétablie, pas recréée', () {
      final lignes = analyserLignesArmes(
        brutes: [_ligne(numeroSerie: '1975-A-04412')],
        registreExistant: const [],
        registreRetire: [_auRegistre('1975-A-04412')],
      );
      expect(lignes.single.statut, StatutLigneArme.aRetablir);
      expect(lignes.single.existante, isNotNull);
    });

    test('le registre actif l\'emporte sur le registre retiré', () {
      final lignes = analyserLignesArmes(
        brutes: [_ligne(numeroSerie: '1975-A-04412')],
        registreExistant: [_auRegistre('1975-A-04412')],
        registreRetire: [_auRegistre('1975-A-04412')],
      );
      expect(lignes.single.statut, StatutLigneArme.dejaPresent);
    });

    test(
      'deux lignes pour la même arme retirée ne l\'écrivent qu\'une fois',
      () {
        // Sans cela, la seconde écriture écraserait la première sans rien
        // dire : deux états pour une arme, et le dernier arrivé gagne.
        final lignes = analyserLignesArmes(
          brutes: [
            _ligne(numeroSerie: '1975-A-04412', position: 'Armurerie'),
            _ligne(numeroSerie: '1975 A 04412', position: 'CIE 1'),
          ],
          registreExistant: const [],
          registreRetire: [_auRegistre('1975-A-04412')],
        );
        expect(lignes[0].statut, StatutLigneArme.aRetablir);
        expect(lignes[1].statut, StatutLigneArme.doublonDansLeFichier);
      },
    );
  });

  group('les doublons à l\'intérieur du fichier', () {
    test('la première ligne est retenue, les suivantes écartées', () {
      final lignes = analyserLignesArmes(
        brutes: [
          _ligne(numeroSerie: '1975-A-04412'),
          _ligne(numeroSerie: '1975 A 04412'),
          _ligne(numeroSerie: '1975-A-04413'),
        ],
        registreExistant: const [],
      );
      expect(lignes[0].statut, StatutLigneArme.nouveau);
      expect(lignes[1].statut, StatutLigneArme.doublonDansLeFichier);
      expect(lignes[2].statut, StatutLigneArme.nouveau);
    });
  });

  group('ce qui manque, et ce qui ne se lit pas', () {
    test('sans désignation, la ligne est en erreur', () {
      final lignes = analyserLignesArmes(
        brutes: [_ligne(designation: '')],
        registreExistant: const [],
      );
      expect(lignes.single.statut, StatutLigneArme.erreur);
      expect(lignes.single.erreurs, contains('Désignation manquante'));
    });

    test('sans numéro de série, la ligne est en erreur', () {
      final lignes = analyserLignesArmes(
        brutes: [_ligne(numeroSerie: '')],
        registreExistant: const [],
      );
      expect(lignes.single.statut, StatutLigneArme.erreur);
      expect(lignes.single.erreurs, contains('Numéro de série manquant'));
    });

    test('le marquage, lui, peut manquer', () {
      // Toutes les armes ne portent pas un marquage lisible, et refuser la
      // ligne pour cela obligerait à inventer une valeur.
      final lignes = analyserLignesArmes(
        brutes: [_ligne(marquage: '')],
        registreExistant: const [],
      );
      expect(lignes.single.statut, StatutLigneArme.nouveau);
      expect(construireImportArme(lignes.single).marquage, '');
    });

    test('la ligne en erreur nomme son numéro de ligne dans le tableur', () {
      final lignes = analyserLignesArmes(
        brutes: [_ligne(), _ligne(designation: '')],
        registreExistant: const [],
      );
      // En-tête en 1, première donnée en 2 : la ligne fautive est la 3e.
      expect(lignes[1].numero, 3);
    });

    test('les lignes entièrement vides sont ignorées', () {
      final lignes = analyserLignesArmes(
        brutes: [
          _ligne(),
          ['', '', '', '', '', ''],
        ],
        registreExistant: const [],
      );
      expect(lignes, hasLength(1));
    });
  });

  group('l\'état, écrit comme on l\'écrit à la main', () {
    test('les deux mots du registre sont reconnus', () {
      expect(lireEtatArme('BON'), EtatArme.bon);
      expect(lireEtatArme('DEFECTUEUX'), EtatArme.defectueux);
      expect(lireEtatArme('Défectueux'), EtatArme.defectueux);
    });

    test('leurs variantes aussi', () {
      // Un fichier tenu à plusieurs mains n'écrit pas deux fois le même
      // mot ; le refuser obligerait à réécrire le fichier avant l'import.
      expect(lireEtatArme('bon état'), EtatArme.bon);
      expect(lireEtatArme('En service'), EtatArme.bon);
      expect(lireEtatArme('RAS'), EtatArme.bon);
      expect(lireEtatArme('Mauvais'), EtatArme.defectueux);
      expect(lireEtatArme('mauvais état'), EtatArme.defectueux);
      expect(lireEtatArme('en réparation'), EtatArme.defectueux);
      expect(lireEtatArme('HS'), EtatArme.defectueux);
      expect(lireEtatArme('Hors service'), EtatArme.defectueux);
    });

    test('une case vide vaut « bon »', () {
      expect(lireEtatArme(''), EtatArme.bon);
      expect(lireEtatArme('   '), EtatArme.bon);
    });

    test('un mot inconnu est une erreur, jamais un repli silencieux', () {
      // Une arme défectueuse versée au registre comme bonne est une arme
      // qu'on croit pouvoir distribuer.
      expect(lireEtatArme('à vérifier'), isNull);
      final lignes = analyserLignesArmes(
        brutes: [_ligne(etat: 'à vérifier')],
        registreExistant: const [],
      );
      expect(lignes.single.statut, StatutLigneArme.erreur);
      expect(
        lignes.single.erreurs.single,
        contains('à vérifier'),
        reason: 'le message doit montrer le mot refusé, pour qu\'on sache '
            'lequel corriger dans le fichier',
      );
    });
  });

  group('ce qui est écrit en base', () {
    test('le numéro de série est mis en capitales', () {
      final lignes = analyserLignesArmes(
        brutes: [_ligne(numeroSerie: '1975-a-04412')],
        registreExistant: const [],
      );
      expect(
        construireImportArme(lignes.single).numeroSerie,
        '1975-A-04412',
      );
    });

    test('position et observations vides deviennent nulles, pas vides', () {
      final lignes = analyserLignesArmes(
        brutes: [_ligne(position: '', observations: '')],
        registreExistant: const [],
      );
      final a = construireImportArme(lignes.single);
      expect(a.positionActuelle, isNull);
      expect(a.observations, isNull);
    });

    test('le reste du fichier passe tel quel', () {
      final lignes = analyserLignesArmes(
        brutes: [
          _ligne(
            designation: 'Pistolet automatique',
            marquage: 'PA MAC 50',
            position: 'CIE 2',
            etat: 'DEFECTUEUX',
            observations: 'Chargeur manquant',
          ),
        ],
        registreExistant: const [],
      );
      final a = construireImportArme(lignes.single);
      expect(a.designation, 'Pistolet automatique');
      expect(a.marquage, 'PA MAC 50');
      expect(a.positionActuelle, 'CIE 2');
      expect(a.etat, EtatArme.defectueux);
      expect(a.observations, 'Chargeur manquant');
    });
  });

  group('les colonnes du modèle', () {
    test('elles sont dans l\'ordre annoncé à l\'utilisateur', () {
      // Les lignes sont lues par position : changer cet ordre sans changer
      // le modèle téléchargeable ferait entrer des marquages dans la case
      // des numéros de série.
      expect(
        [for (final c in colonnesArme) c.cle],
        ['designation', 'marquage', 'numero_serie', 'position', 'etat',
          'observations'],
      );
    });
  });
}
