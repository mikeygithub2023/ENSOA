// Le dossier de pension et les décorations, éprouvés là où ça compte.
//
// Un dossier annoncé complet à tort, c'est un militaire qui part à la
// retraite sans sa pension. Ces épreuves fixent ce que « complet » veut
// dire, et surtout ce qu'il ne veut pas dire — un catalogue vide n'est pas
// un dossier prêt, et une pièce non vérifiée n'est pas une pièce manquante.

import 'package:flutter_test/flutter_test.dart';

import 'package:sig_ensoa/modules/scolarite/features/apprenants/data/decorations_repository.dart';
import 'package:sig_ensoa/modules/scolarite/features/apprenants/data/pension_repository.dart';
import 'package:sig_ensoa/modules/scolarite/features/apprenants/pension_bilan.dart';
import 'package:sig_ensoa/modules/scolarite/models/decoration.dart';
import 'package:sig_ensoa/modules/scolarite/models/pension.dart';

PiecePension piece(
  String id, {
  bool obligatoire = true,
  bool active = true,
  int ordre = 0,
}) => PiecePension(
  id: id,
  libelle: 'Pièce $id',
  ordre: ordre,
  obligatoire: obligatoire,
  active: active,
);

LignePension ligne(String pieceId, {bool presente = true}) => LignePension(
  id: 'l-$pieceId',
  apprenantId: 'a1',
  pieceId: pieceId,
  presente: presente,
  verifieLe: DateTime(2026, 11, 20),
);

void main() {
  group('le bilan d’un dossier de pension', () {
    test('sans catalogue, on ne juge rien', () {
      final b = bilanDuDossier(pieces: const [], lignes: const []);
      expect(b.etat, EtatDossier.sansCatalogue);
      expect(b.libelle, 'Aucune pièce au catalogue');
    });

    test('catalogue en place, rien de vérifié : non vérifié', () {
      final b = bilanDuDossier(
        pieces: [piece('p1'), piece('p2')],
        lignes: const [],
      );
      expect(b.etat, EtatDossier.nonVerifie);
      expect(b.verifiees, 0);
      expect(b.exigeesTotal, 2);
    });

    test('toutes les obligatoires présentes : complet', () {
      final b = bilanDuDossier(
        pieces: [piece('p1'), piece('p2'), piece('p3', obligatoire: false)],
        lignes: [ligne('p1'), ligne('p2')],
      );
      expect(b.etat, EtatDossier.complet);
      expect(b.exigeesTotal, 2);
      expect(b.exigeesPresentes, 2);
      expect(b.presentes, 2);
    });

    test('une facultative manquante ne rend pas le dossier incomplet', () {
      final b = bilanDuDossier(
        pieces: [piece('p1'), piece('p2', obligatoire: false)],
        lignes: [ligne('p1'), ligne('p2', presente: false)],
      );
      expect(b.etat, EtatDossier.complet);
      expect(b.presentes, 1);
      expect(b.verifiees, 2);
    });

    test('une obligatoire constatée manquante : incomplet', () {
      final b = bilanDuDossier(
        pieces: [piece('p1'), piece('p2')],
        lignes: [ligne('p1'), ligne('p2', presente: false)],
      );
      expect(b.etat, EtatDossier.incomplet);
      expect(b.exigeesManquantes, 1);
      expect(b.libelle, '1 pièce à réunir');
    });

    test('une obligatoire jamais vérifiée compte comme à réunir', () {
      final b = bilanDuDossier(
        pieces: [piece('p1'), piece('p2'), piece('p3')],
        lignes: [ligne('p1')],
      );
      expect(b.etat, EtatDossier.incomplet);
      expect(b.exigeesManquantes, 2);
      expect(b.libelle, '2 pièces à réunir');
      // Une seule pièce a reçu un avis : le bureau doit pouvoir le lire.
      expect(b.verifiees, 1);
    });

    test('une pièce désactivée ne manque plus', () {
      final b = bilanDuDossier(
        pieces: [piece('p1'), piece('p2', active: false)],
        lignes: [ligne('p1')],
      );
      expect(b.etat, EtatDossier.complet);
      expect(b.piecesActives, 1);
    });

    test('la ligne d’une pièce désactivée est ignorée', () {
      final b = bilanDuDossier(
        pieces: [piece('p1'), piece('p2', active: false)],
        lignes: [ligne('p2')],
      );
      expect(b.etat, EtatDossier.nonVerifie);
      expect(b.verifiees, 0);
    });

    test('un catalogue tout facultatif reste à réunir en entier', () {
      final b = bilanDuDossier(
        pieces: [
          piece('p1', obligatoire: false),
          piece('p2', obligatoire: false),
        ],
        lignes: [ligne('p1')],
      );
      expect(b.etat, EtatDossier.incomplet);
      expect(b.exigeesTotal, 2);
      expect(b.exigeesManquantes, 1);
    });
  });

  group('l’ordre d’urgence des retraites', () {
    test('la plus proche d’abord', () {
      final dates = [
        DateTime(2031, 1, 1),
        DateTime(2027, 1, 1),
        DateTime(2029, 1, 1),
      ]..sort(compareUrgenceRetraite);
      expect(dates.map((d) => d.year), [2027, 2029, 2031]);
    });

    test('celle qu’on ne connaît pas ferme la liste', () {
      final dates = <DateTime?>[
        null,
        DateTime(2031, 1, 1),
        null,
        DateTime(2027, 1, 1),
      ]..sort(compareUrgenceRetraite);
      expect(dates.map((d) => d?.year), [2027, 2031, null, null]);
    });
  });

  group('ce qui part en base', () {
    test('une vérification porte la pièce, le militaire et l’avis', () {
      final json = const LignePensionDraft(
        apprenantId: 'a1',
        pieceId: 'p1',
        presente: true,
        verifiePar: 'u1',
        observation: 'Copie légalisée',
      ).toUpsertJson();
      expect(json['apprenant_id'], 'a1');
      expect(json['piece_id'], 'p1');
      expect(json['presente'], isTrue);
      expect(json['verifie_le'], isNull);
      expect(json['observation'], 'Copie légalisée');
    });

    test('la date de vérification part au format de la base', () {
      final json = LignePensionDraft(
        apprenantId: 'a1',
        pieceId: 'p1',
        presente: false,
        verifieLe: DateTime(2026, 5, 18),
      ).toUpsertJson();
      expect(json['verifie_le'], '2026-05-18');
      expect(json['presente'], isFalse);
    });

    test('une décoration sans date part avec une date nulle', () {
      final json = const DecorationRecueDraft(
        apprenantId: 'a1',
        decorationId: 'd1',
        reference: 'Décret 2024-117',
      ).toJson();
      expect(json['date_attribution'], isNull);
      expect(json['reference'], 'Décret 2024-117');
      expect(json['echelon'], isNull);
    });

    test('une décoration datée part au format de la base', () {
      final json = DecorationRecueDraft(
        apprenantId: 'a1',
        decorationId: 'd1',
        dateAttribution: DateTime(2024, 8, 7),
        echelon: 'Agrafe Côte d\'Ivoire',
      ).toJson();
      expect(json['date_attribution'], '2024-08-07');
      expect(json['echelon'], 'Agrafe Côte d\'Ivoire');
    });
  });

  group('les modèles se relisent depuis la base', () {
    test('une pièce du catalogue', () {
      final p = PiecePension.fromJson({
        'id': 'p1',
        'libelle': 'Extrait de naissance',
        'ordre': 3,
        'obligatoire': false,
        'active': true,
      });
      expect(p.libelle, 'Extrait de naissance');
      expect(p.ordre, 3);
      expect(p.obligatoire, isFalse);
    });

    test('une décoration du catalogue', () {
      final d = TypeDecoration.fromJson({
        'id': 'd1',
        'libelle': 'Médaille militaire',
        'ordre': 1,
        'active': true,
      });
      expect(d.libelle, 'Médaille militaire');
      expect(d.active, isTrue);
    });

    test('une attribution sans date se relit sans date', () {
      final r = DecorationRecue.fromJson({
        'id': 'r1',
        'apprenant_id': 'a1',
        'decoration_id': 'd1',
        'date_attribution': null,
        'reference': null,
        'echelon': null,
        'observation': null,
      });
      expect(r.dateAttribution, isNull);
      expect(r.decorationId, 'd1');
    });
  });
}
