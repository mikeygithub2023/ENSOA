// Les mouvements du personnel : ce que chacun exige, ce qu'on peut proposer,
// et le reversé qui ne compte plus.
import 'package:flutter_test/flutter_test.dart';

import 'package:sig_ensoa/modules/scolarite/features/apprenants/data/mouvements_repository.dart';
import 'package:sig_ensoa/modules/scolarite/features/apprenants/import_valeurs.dart';
import 'package:sig_ensoa/modules/scolarite/features/apprenants/register_mouvement_dialog.dart';
import 'package:sig_ensoa/modules/scolarite/models/apprenant.dart';
import 'package:sig_ensoa/modules/scolarite/models/mouvement_personnel.dart';

Apprenant _militaire({
  ApprenantStatut statut = ApprenantStatut.actif,
  String? position = 'PERSONNEL AU SERVICE',
}) => Apprenant.fromJson({
  'id': 'a1',
  'division_id': 'd1',
  'type': 'personnel',
  'nom': 'KONE',
  'prenom': 'ALI',
  'statut': statut.name,
  'position_statutaire': position,
  'unite': statut == ApprenantStatut.reverse ? 'AFA' : 'ENSOA',
});

void main() {
  group('ce que la base attend', () {
    test('la mise à disposition s\'écrit comme la base l\'attend', () {
      expect(NatureMouvement.miseADisposition.valeur, 'mise_a_disposition');
      expect(
        NatureMouvement.depuis('mise_a_disposition'),
        NatureMouvement.miseADisposition,
      );
      for (final n in NatureMouvement.values) {
        expect(NatureMouvement.depuis(n.valeur), n);
      }
    });

    test(
      "un reversement n'envoie pas de service, une mutation pas d'unité",
      () {
        final reversement = MouvementDraft(
          apprenantId: 'a1',
          nature: NatureMouvement.reversement,
          dateEffet: DateTime(2026, 11, 25),
          serviceApres: 'X',
          uniteAccueil: 'AFA',
        ).toJson();
        expect(reversement['service_apres'], isNull);
        expect(reversement['unite_accueil'], 'AFA');
        expect(reversement['date_effet'], '2026-11-25');

        final mutation = MouvementDraft(
          apprenantId: 'a1',
          nature: NatureMouvement.mutation,
          dateEffet: DateTime(2026, 11, 25),
          serviceApres: 'ENSOA/BRH',
          uniteAccueil: 'AFA',
        ).toJson();
        expect(mutation['unite_accueil'], isNull);
        expect(mutation['service_apres'], 'ENSOA/BRH');
      },
    );
  });

  group('ce qu\'on propose', () {
    test('un militaire en service ne peut pas « revenir »', () {
      expect(
        naturesPossibles(_militaire()),
        isNot(contains(NatureMouvement.retour)),
      );
    });

    test('un mis à disposition peut revenir', () {
      expect(
        naturesPossibles(_militaire(position: 'MIS A DISPOSITION')),
        contains(NatureMouvement.retour),
      );
    });

    test('un reversé ne peut que revenir', () {
      expect(naturesPossibles(_militaire(statut: ApprenantStatut.reverse)), [
        NatureMouvement.retour,
      ]);
    });
  });

  group('le journal se lit', () {
    MouvementPersonnel m(Map<String, dynamic> extra) =>
        MouvementPersonnel.fromJson({
          'id': 'm1',
          'apprenant_id': 'a1',
          'date_effet': '2026-11-20',
          ...extra,
        });

    test("d'où il part, où il va", () {
      expect(
        m({
          'nature': 'mutation',
          'service_avant': 'CCAS/ENSOA',
          'service_apres': 'ENSOA/BRH',
        }).trajet,
        'CCAS/ENSOA → ENSOA/BRH',
      );
      expect(
        m({
          'nature': 'reversement',
          'unite_avant': 'ENSOA',
          'unite_accueil': 'AFA',
        }).trajet,
        'ENSOA → AFA',
      );
      expect(m({'nature': 'retour'}).trajet, isNull);
    });
  });

  group("l'état nominatif dit qui est reversé", () {
    test('une autre unité que l\'école', () {
      expect(estReverse('AFA'), isTrue);
      expect(estReverse(' ensoa '), isFalse);
      expect(estReverse(''), isFalse);
    });

    test('le reversé se lit sur la fiche', () {
      final a = _militaire(statut: ApprenantStatut.reverse);
      expect(a.statut, ApprenantStatut.reverse);
      expect(a.statut.label, 'Reversé');
      expect(a.unite, 'AFA');
    });
  });
}
