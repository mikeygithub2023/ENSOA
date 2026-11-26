// Les pièces du dossier de pension qui ne se demandent qu'à certains : au
// militaire marié, à celui qui a des enfants.
import 'package:flutter_test/flutter_test.dart';
import 'package:sig_ensoa/modules/scolarite/features/apprenants/data/pension_repository.dart';
import 'package:sig_ensoa/modules/scolarite/features/apprenants/pension_bilan.dart';
import 'package:sig_ensoa/modules/scolarite/models/pension.dart';

PiecePension _piece(String id, [ConditionPiece c = ConditionPiece.aucune]) =>
    PiecePension(
      id: id,
      libelle: id,
      ordre: 0,
      obligatoire: true,
      active: true,
      condition: c,
    );

final _catalogue = [
  _piece('fiche'),
  _piece('enfants', ConditionPiece.enfants),
  _piece('mariage', ConditionPiece.marie),
];

void main() {
  test('la condition se lit en base', () {
    expect(ConditionPiece.depuis('marie'), ConditionPiece.marie);
    expect(ConditionPiece.depuis('enfants'), ConditionPiece.enfants);
    expect(ConditionPiece.depuis(null), ConditionPiece.aucune);
    expect(
      PiecePension.fromJson({
        'id': 'x',
        'libelle': 'Acte de mariage',
        'condition': 'marie',
      }).condition,
      ConditionPiece.marie,
    );
  });

  test(
    'un célibataire sans enfant : ni acte de mariage, ni actes des enfants',
    () {
      expect(
        piecesPour(
          _catalogue,
          situationMatrimoniale: 'Célibataire',
          nombreEnfants: 0,
        ).map((p) => p.id),
        ['fiche'],
      );
    },
  );

  test('un marié père de famille : tout le dossier', () {
    for (final s in ['Marié(e)', 'MARIE', 'M']) {
      expect(
        piecesPour(
          _catalogue,
          situationMatrimoniale: s,
          nombreEnfants: 2,
        ).length,
        3,
        reason: s,
      );
    }
  });

  test("un nombre d'enfants inconnu ne retire pas leurs actes", () {
    expect(
      piecesPour(
        _catalogue,
        situationMatrimoniale: 'Concubinage',
      ).map((p) => p.id),
      ['fiche', 'enfants'],
    );
  });

  test('le dossier du célibataire est complet sans acte de mariage', () {
    final pieces = piecesPour(
      _catalogue,
      situationMatrimoniale: 'Célibataire',
      nombreEnfants: 0,
    );
    final bilan = bilanDuDossier(
      pieces: pieces,
      lignes: const [
        LignePension(
          id: 'l1',
          apprenantId: 'a',
          pieceId: 'fiche',
          presente: true,
        ),
      ],
    );
    expect(bilan.etat, EtatDossier.complet);
  });

  group('les pièces numérisées', () {
    test('le chemin commence par le militaire, que la RLS y lise', () {
      expect(
        cheminPiecePension(
          apprenantId: 'a1',
          pieceId: 'p1',
          nom: 'Acte Naissance.JPEG',
        ),
        'a1/p1.jpg',
      );
      expect(
        cheminPiecePension(apprenantId: 'a1', pieceId: 'p1', nom: 'x.pdf'),
        'a1/p1.pdf',
      );
    });

    test("le type suit l'extension", () {
      expect(typeDuFichierPension('scan.PDF'), 'application/pdf');
      expect(typeDuFichierPension('scan.png'), 'image/png');
      expect(typeDuFichierPension('scan.jpg'), 'image/jpeg');
    });

    test('la ligne garde son scan', () {
      final l = LignePension.fromJson({
        'id': 'l',
        'apprenant_id': 'a',
        'piece_id': 'p',
        'presente': true,
        'fichier_path': 'a/p.pdf',
        'fichier_nom': 'livret.pdf',
      });
      expect(l.fichierPath, 'a/p.pdf');
      expect(l.fichierNom, 'livret.pdf');
    });

    test("un enregistrement sans nouveau scan n'efface pas l'ancien", () {
      const sans = LignePensionDraft(
        apprenantId: 'a',
        pieceId: 'p',
        presente: true,
      );
      expect(sans.toUpsertJson().containsKey('fichier_path'), isFalse);
      const avec = LignePensionDraft(
        apprenantId: 'a',
        pieceId: 'p',
        presente: true,
        fichierPath: 'a/p.pdf',
        fichierNom: 'livret.pdf',
      );
      expect(avec.toUpsertJson()['fichier_path'], 'a/p.pdf');
    });
  });
}
