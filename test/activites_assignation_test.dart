import 'package:flutter_test/flutter_test.dart';
import 'package:sig_ensoa/modules/logistique/data/models/oa.dart';

void main() {
  TacheActivite tache({
    ActeurTache? acteur,
    String? profil,
    String? libelle,
    String nom = '',
  }) => TacheActivite(
    id: '1',
    activiteId: '1',
    acteur: acteur,
    profilPersonnaliseId: profil,
    profilPersonnaliseLibelle: libelle,
    assigneA: nom.isEmpty ? null : 'u1',
    assigneNom: nom,
    description: 'Faire le plein',
  );

  group('destinataire', () {
    test('un service seul', () {
      expect(tache(acteur: ActeurTache.garage).destinataire, 'Garage');
    });
    test('un service et une personne', () {
      expect(
        tache(acteur: ActeurTache.garage, nom: 'SGT KONE Ali').destinataire,
        'Garage — SGT KONE Ali',
      );
    });
    test('une personne seule', () {
      expect(tache(nom: 'CNE AIME Julien').destinataire, 'CNE AIME Julien');
    });
    test('un service créé, retiré du catalogue', () {
      expect(tache(profil: 'p1').destinataire, 'Service retiré');
    });
  });

  group('estDuService', () {
    const chef = PersonneAssignable(
      id: 'a',
      nom: 'A',
      roleLogistique: 'chef_soutien_technique',
    );
    const petrolier = PersonneAssignable(
      id: 'b',
      nom: 'B',
      roleLogistique: 'soutien_petrolier',
    );
    const intendant = PersonneAssignable(
      id: 'c',
      nom: 'C',
      roleLogistique: 'profil_personnalise',
      profilPersonnaliseId: 'intendance',
    );
    const instructeur = PersonneAssignable(id: 'd', nom: 'D');

    test('le soutien pétrolier réunit le chef et ses agents', () {
      expect(chef.estDuService(acteur: ActeurTache.st), isTrue);
      expect(petrolier.estDuService(acteur: ActeurTache.st), isTrue);
      expect(petrolier.estDuService(acteur: ActeurTache.garage), isFalse);
    });
    test('un service créé se reconnaît à son identifiant', () {
      expect(
        intendant.estDuService(profilPersonnaliseId: 'intendance'),
        isTrue,
      );
      expect(intendant.estDuService(profilPersonnaliseId: 'popote'), isFalse);
    });
    test("un compte sans rôle logistique n'est d'aucun service", () {
      for (final a in ActeurTache.values) {
        expect(instructeur.estDuService(acteur: a), isFalse);
      }
    });
  });
}
