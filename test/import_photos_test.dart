// Le rapprochement des photos, éprouvé.
//
// Une photo mal posée met le visage d'un homme sur la fiche d'un autre, et
// personne ne s'en aperçoit avant la prochaine prise d'armes. Ces épreuves
// fixent ce que le nom d'un fichier a le droit de désigner — et, surtout,
// ce qu'il ne désigne pas.

import 'package:flutter_test/flutter_test.dart';

import 'package:sig_ensoa/modules/scolarite/features/apprenants/import_photos.dart';
import 'package:sig_ensoa/modules/scolarite/models/apprenant.dart';

Apprenant militaire({
  required String id,
  String nom = 'KOUAME',
  String prenom = 'KOUASSI CELESTIN',
  String? matricule,
  String? matriculeSolde,
  String? mecano,
  String? photoPath,
}) => Apprenant(
  id: id,
  divisionId: 'd4',
  type: ApprenantType.personnel,
  nom: nom,
  prenom: prenom,
  statut: ApprenantStatut.actif,
  matricule: matricule,
  matriculeSolde: matriculeSolde,
  numeroMecano: mecano,
  photoPath: photoPath,
);

void main() {
  group('la clé d’identité', () {
    test('elle ignore espaces, tirets et apostrophes', () {
      expect(normaliserCle('001 06 0467'), '001060467');
      expect(normaliserCle('001-06-0467'), '001060467');
      expect(normaliserCle("N'GUESSAN"), 'NGUESSAN');
    });

    test('elle replie les accents sur la lettre nue', () {
      expect(normaliserCle('DIABATÉ'), 'DIABATE');
      expect(normaliserCle('Kôné'), 'KONE');
    });

    test('elle ne garde rien d’une chaîne sans lettre ni chiffre', () {
      expect(normaliserCle('— ·  '), '');
    });
  });

  group('le nom du fichier', () {
    test('il perd son extension', () {
      expect(baseDuFichier('39287.jpg'), '39287');
      expect(baseDuFichier('KOUAME CELESTIN.JPEG'), 'KOUAME CELESTIN');
    });

    test('il perd le « (1) » que Windows ajoute en recopiant', () {
      expect(baseDuFichier('39287 (1).jpg'), '39287');
      expect(baseDuFichier('39287(2).png'), '39287');
    });

    test('il perd le « - Copie » du même geste', () {
      expect(baseDuFichier('39287 - Copie.jpg'), '39287');
      expect(baseDuFichier('39287-copy.jpg'), '39287');
    });

    test('un nom sans point reste entier', () {
      expect(baseDuFichier('39287'), '39287');
    });
  });

  group('ce par quoi un fichier désigne un militaire', () {
    final cne = militaire(
      id: 'a1',
      nom: 'AIME',
      prenom: 'MOH JULIEN',
      matricule: '001 08 0505',
      matriculeSolde: '00108000505',
      mecano: '39287',
    );

    test('ses trois identifiants et son nom complet', () {
      expect(clesDuMilitaire(cne), {
        '001080505',
        '00108000505',
        '39287',
        'AIMEMOHJULIEN',
      });
    });

    test('les rubriques vides n’ouvrent pas de clé', () {
      expect(clesDuMilitaire(militaire(id: 'a2')), {'KOUAMEKOUASSICELESTIN'});
    });
  });

  group('le rapprochement', () {
    final cne = militaire(
      id: 'a1',
      nom: 'AIME',
      prenom: 'MOH JULIEN',
      matricule: '001 08 0505',
      mecano: '39287',
    );
    final adt = militaire(
      id: 'a2',
      nom: 'DIABAGATE',
      prenom: 'ADAMA',
      matricule: '001 99 1234',
      mecano: '41200',
      photoPath: 'a2.jpg',
    );

    test('par le numéro mécanographique', () {
      final r = rapprocherLesPhotos(
        fichiers: const [FichierPhoto('39287.jpg', 120000)],
        effectif: [cne, adt],
      );
      expect(r.single.estTrouve, isTrue);
      expect(r.single.apprenant!.id, 'a1');
      expect(r.single.remplaceUnePhoto, isFalse);
    });

    test('par le matricule, espaces ou non', () {
      final r = rapprocherLesPhotos(
        fichiers: const [
          FichierPhoto('001 08 0505.jpg', 100),
          FichierPhoto('001991234.png', 100),
        ],
        effectif: [cne, adt],
      );
      expect(r.map((e) => e.apprenant?.id), ['a1', 'a2']);
    });

    test('par le nom complet', () {
      final r = rapprocherLesPhotos(
        fichiers: const [FichierPhoto('AIME MOH JULIEN.jpg', 100)],
        effectif: [cne, adt],
      );
      expect(r.single.apprenant?.id, 'a1');
    });

    test('il signale la photo qu’il remplacerait', () {
      final r = rapprocherLesPhotos(
        fichiers: const [FichierPhoto('41200.jpg', 100)],
        effectif: [cne, adt],
      );
      expect(r.single.remplaceUnePhoto, isTrue);
    });

    test('un fichier qui ne désigne personne reste de côté', () {
      final r = rapprocherLesPhotos(
        fichiers: const [FichierPhoto('photo du bureau.jpg', 100)],
        effectif: [cne, adt],
      );
      expect(r.single.estTrouve, isFalse);
      expect(r.single.motif, MotifNonRapproche.introuvable);
    });

    test('deux fiches pour un même identifiant : on ne choisit pas', () {
      final jumeau = militaire(id: 'a3', nom: 'AIME', prenom: 'MOH JULIEN');
      final r = rapprocherLesPhotos(
        fichiers: const [FichierPhoto('AIME MOH JULIEN.jpg', 100)],
        effectif: [cne, jumeau],
      );
      expect(r.single.estTrouve, isFalse);
      expect(r.single.motif, MotifNonRapproche.ambigu);
    });

    test('un militaire hors de la portée n’est pas servi', () {
      final r = rapprocherLesPhotos(
        fichiers: const [FichierPhoto('39287.jpg', 100)],
        effectif: [adt],
      );
      expect(r.single.motif, MotifNonRapproche.introuvable);
    });

    test('une photo trop lourde est écartée avant tout rapprochement', () {
      final r = rapprocherLesPhotos(
        fichiers: [FichierPhoto('39287.jpg', poidsMaxPhoto + 1)],
        effectif: [cne],
      );
      expect(r.single.estTrouve, isFalse);
      expect(r.single.motif, MotifNonRapproche.tropLourd);
    });

    test('le poids limite exact passe', () {
      final r = rapprocherLesPhotos(
        fichiers: [FichierPhoto('39287.jpg', poidsMaxPhoto)],
        effectif: [cne],
      );
      expect(r.single.estTrouve, isTrue);
    });

    test('l’ordre des fichiers est celui du dossier', () {
      final r = rapprocherLesPhotos(
        fichiers: const [
          FichierPhoto('41200.jpg', 100),
          FichierPhoto('inconnu.jpg', 100),
          FichierPhoto('39287.jpg', 100),
        ],
        effectif: [cne, adt],
      );
      expect(r.map((e) => e.fichier), [
        '41200.jpg',
        'inconnu.jpg',
        '39287.jpg',
      ]);
    });
  });

  group('deux fichiers pour le même militaire', () {
    final cne = militaire(id: 'a1', matricule: '001 08 0505', mecano: '39287');

    test('le matricule et le mécano désignent le même homme', () {
      final r = rapprocherLesPhotos(
        fichiers: const [
          FichierPhoto('39287.jpg', 100),
          FichierPhoto('001080505.jpg', 100),
        ],
        effectif: [cne],
      );
      expect(militairesServisDeuxFois(r), {'a1'});
    });

    test('un dossier propre n’en signale aucun', () {
      final r = rapprocherLesPhotos(
        fichiers: const [FichierPhoto('39287.jpg', 100)],
        effectif: [cne],
      );
      expect(militairesServisDeuxFois(r), isEmpty);
    });
  });

  group('le poids, dit comme on le dit', () {
    test('les trois ordres de grandeur', () {
      expect(formatPoids(512), '512 o');
      expect(formatPoids(2048), '2 Ko');
      expect(formatPoids(3 * 1024 * 1024), '3.0 Mo');
    });
  });
}
