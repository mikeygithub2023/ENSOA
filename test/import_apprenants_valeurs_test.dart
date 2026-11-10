// Ce qu'une cellule de classeur veut dire, et ce qu'on refuse de deviner.
//
// Les fiches de renseignement de l'école arrivent écrites à la main : la
// taille s'y lit « 1,73 M », le groupe sanguin « o +  », la situation
// « CELIBATAIRE SANS ENFANT ». L'import doit les comprendre — et se taire
// devant ce qu'il ne comprend pas, car une case vide se complète tandis
// qu'une case fausse se croit.
import 'package:flutter_test/flutter_test.dart';

import 'package:sig_ensoa/modules/scolarite/features/apprenants/import_valeurs.dart';

void main() {
  group('le sexe', () {
    test('se lit sous ses formes courantes', () {
      for (final valeur in ['M', 'm', 'Masculin', 'H', 'Homme']) {
        expect(sexeDepuisCellule(valeur), 'M', reason: valeur);
      }
      for (final valeur in ['F', 'f', 'Féminin', 'femme']) {
        expect(sexeDepuisCellule(valeur), 'F', reason: valeur);
      }
    });

    // Il décide du barème sportif : mieux vaut pas de sexe qu'un mauvais.
    test('reste vide devant ce qui ne se comprend pas', () {
      expect(sexeDepuisCellule(''), isNull);
      expect(sexeDepuisCellule('?'), isNull);
    });
  });

  group('la situation matrimoniale', () {
    test('se ramène à la liste de la fiche', () {
      expect(situationDepuisCellule('CELIBATAIRE SANS ENFANT'), 'Célibataire');
      expect(situationDepuisCellule('MARIE 2 ENFANTS'), 'Marié(e)');
      expect(situationDepuisCellule('Mariée'), 'Marié(e)');
      expect(situationDepuisCellule('divorcé'), 'Divorcé(e)');
      expect(situationDepuisCellule('VEUVE'), 'Veuf(ve)');
    });

    test('reste vide devant un libellé inconnu', () {
      expect(situationDepuisCellule('CONCUBINAGE'), isNull);
      expect(situationDepuisCellule(''), isNull);
    });
  });

  group('le groupe sanguin', () {
    test('se normalise sans perdre son signe', () {
      expect(groupeSanguinDepuisCellule('o +'), 'O+');
      expect(groupeSanguinDepuisCellule(' ab- '), 'AB-');
      // Le zéro se tape pour le O, et le O seul n'est pas un groupe.
      expect(groupeSanguinDepuisCellule('0+'), 'O+');
    });

    test("ne s'invente pas hors de la liste", () {
      expect(groupeSanguinDepuisCellule('O'), isNull);
      expect(groupeSanguinDepuisCellule('C+'), isNull);
      expect(groupeSanguinDepuisCellule(''), isNull);
    });
  });

  group('la taille', () {
    // Personne ne mesure deux centimètres : sous trois, la cellule parle en
    // mètres.
    test('se rend en centimètres, quelle que soit la façon de l’écrire', () {
      expect(tailleDepuisCellule('1,73M'), 173);
      expect(tailleDepuisCellule('1.73 m'), 173);
      expect(tailleDepuisCellule('173'), 173);
      expect(tailleDepuisCellule('173 cm'), 173);
    });

    test('reste vide sans nombre', () {
      expect(tailleDepuisCellule('—'), isNull);
      expect(tailleDepuisCellule(''), isNull);
    });
  });

  group('le poids', () {
    test('se lit malgré son unité écrite à côté', () {
      expect(premierNombre('68 KG'), 68);
      expect(premierNombre('54,5 kg'), 54.5);
    });
  });

  group('le nombre d’enfants', () {
    test('se lit dans la phrase', () {
      expect(entierDepuisCellule('2 ENFANTS'), 2);
      expect(entierDepuisCellule('0'), 0);
    });

    // « Sans enfant » n'est pas zéro saisi : on ne sait pas, on ne dit pas.
    test('reste vide quand la cellule ne compte rien', () {
      expect(entierDepuisCellule('SANS ENFANT'), isNull);
      expect(entierDepuisCellule(''), isNull);
    });
  });
}
