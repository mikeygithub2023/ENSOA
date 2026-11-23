// L'état nominatif de la DORH ne tient qu'une colonne « NOM ET PRENOMS » :
// le nom du père dit où le patronyme s'arrête.
import 'package:flutter_test/flutter_test.dart';

import 'package:sig_ensoa/modules/scolarite/features/apprenants/import_valeurs.dart';

void main() {
  test('un patronyme de deux mots se lit dans le nom du père', () {
    final r = couperNomEtPrenoms(
      'DJAMA DJAMA YANNICK JOCELYN',
      'DJAMA DJAMA FELICIEN',
    );
    expect(r.nom, 'DJAMA DJAMA');
    expect(r.prenoms, 'YANNICK JOCELYN');
  });

  test("un patronyme d'un mot", () {
    final r = couperNomEtPrenoms('EDI FABRICE', 'EDI KOUASSI BARTHELEMY');
    expect(r.nom, 'EDI');
    expect(r.prenoms, 'FABRICE');
  });

  test('quand le père ne dit rien, le premier mot fait le nom', () {
    expect(couperNomEtPrenoms('ALI GNAMIEN KOUAKOU', 'SIRIKI ALI').nom, 'ALI');
    expect(couperNomEtPrenoms('KONE MOLA', 'PND').nom, 'KONE');
    expect(couperNomEtPrenoms('KONE MOLA', '').prenoms, 'MOLA');
  });

  test('il reste toujours au moins un prénom', () {
    final r = couperNomEtPrenoms('KONE ALI', 'KONE ALI');
    expect(r.nom, 'KONE');
    expect(r.prenoms, 'ALI');
  });

  test('recollés, nom et prénoms rendent la cellule', () {
    const complet = 'DJAMA  DJAMA YANNICK   JOCELYN';
    final r = couperNomEtPrenoms(complet, 'DJAMA DJAMA FELICIEN');
    expect('${r.nom} ${r.prenoms}', 'DJAMA DJAMA YANNICK JOCELYN');
  });
}
