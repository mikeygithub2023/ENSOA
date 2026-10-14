import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import 'package:sig_ensoa/core/erreurs.dart';

/// Ce qu'un utilisateur doit lire quand la base refuse.
///
/// Le critère est simple et se vérifie : la phrase montrée ne contient
/// jamais de jargon — « constraint », « violates », un nom de contrainte —,
/// elle dit quel renseignement est en cause, et elle dit quoi en faire.

/// Les erreurs telles que PostgREST les remonte réellement.
PostgrestException _pg(String code, String message, {String? details}) =>
    PostgrestException(message: message, code: code, details: details);

const _jargon = [
  'constraint',
  'violates',
  'foreign key',
  'duplicate key',
  'row-level security',
  '_fkey',
  '_key"',
  'null value in column',
];

void _sansJargon(String phrase) {
  for (final mot in _jargon) {
    expect(
      phrase.toLowerCase(),
      isNot(contains(mot)),
      reason: 'la phrase montrée à l\'utilisateur contient « $mot » :\n$phrase',
    );
  }
}

void main() {
  test('la clé étrangère de l\'import du parc se lit en français', () {
    // L'erreur exacte rencontrée à l'import du parc automobile.
    final phrase = messageErreur(
      _pg(
        '23503',
        'insert or update on table "vehicule" violates foreign key '
            'constraint "vehicule_type_vhl_id_fkey"',
        details: 'Key (type_vhl_id)=(41) is not present in table "type_vhl".',
      ),
    );

    _sansJargon(phrase);
    expect(phrase, contains('type de véhicule'));
    expect(phrase, contains('catalogue des types de véhicule'));
  });

  test('une immatriculation déjà prise nomme la valeur en cause', () {
    final phrase = messageErreur(
      _pg(
        '23505',
        'duplicate key value violates unique constraint '
            '"vehicule_immatriculation_key"',
        details: 'Key (immatriculation)=(310 20 158) already exists.',
      ),
    );

    _sansJargon(phrase);
    expect(phrase, contains('immatriculation'));
    expect(phrase, contains('310 20 158'));
    // L'accord suit le genre du champ : « déjà utilisée », pas « utilisé ».
    expect(phrase, contains('utilisée'));
  });

  test('une suppression retenue se distingue d\'une référence absente', () {
    final absente = messageErreur(
      _pg(
        '23503',
        'insert or update on table "soute_type_stock" violates foreign key '
            'constraint "soute_type_stock_repartition_id_fkey"',
        details: 'Key (repartition_id)=(9) is not present in table '
            '"repartition".',
      ),
    );
    final retenue = messageErreur(
      _pg(
        '23503',
        'update or delete on table "repartition" violates foreign key '
            'constraint "soute_type_stock_repartition_id_fkey" on table '
            '"soute_type_stock"',
        details: 'Key (id)=(9) is still referenced from table '
            '"soute_type_stock".',
      ),
    );

    _sansJargon(absente);
    _sansJargon(retenue);
    expect(absente, contains('n\'est pas connue'));
    expect(retenue, contains('ne peut pas être supprimée'));
  });

  test('nos propres refus passent intacts', () {
    // Un `raise exception` d'un déclencheur est déjà écrit pour celui qui le
    // lira : le traduire une seconde fois ne ferait que l'appauvrir.
    const refus =
        'Activités Ordinaires ne contient que 300 L de Gasoil, et l\'on en '
        'demande 500.';
    expect(messageErreur(_pg('P0001', refus)), refus);
  });

  test('un refus de la sécurité ne parle pas de politique de ligne', () {
    final phrase = messageErreur(
      _pg(
        '42501',
        'new row violates row-level security policy for table "notifications"',
      ),
    );
    _sansJargon(phrase);
    expect(phrase, contains('droit'));
  });

  test('un champ obligatoire manquant se nomme', () {
    final phrase = messageErreur(
      _pg(
        '23502',
        'null value in column "immatriculation" of relation "vehicule" '
            'violates not-null constraint',
        details: 'Failing row contains (...).',
      ),
    );
    _sansJargon(phrase);
    expect(phrase, contains('obligatoire'));
  });

  test('un code inconnu garde sa trace technique', () {
    // Sans elle, l'utilisateur n'a rien à signaler et le technicien rien à
    // chercher.
    final phrase = messageErreur(_pg('XX000', 'internal error'));
    expect(phrase, contains('XX000'));
    expect(phrase, contains('internal error'));
  });

  test('un champ hors catalogue reste lisible', () {
    final phrase = messageErreur(
      _pg(
        '23505',
        'duplicate key value violates unique constraint "truc_machin_bidule_key"',
        details: 'Key (machin_bidule)=(X) already exists.',
      ),
    );
    _sansJargon(phrase);
    expect(phrase, contains('machin bidule'));
  });
}
