import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import 'package:sig_ensoa/core/session_fraiche.dart';
import 'package:sig_ensoa/core/supabase_client.dart';
import '../../../models/promotion.dart';

/// Les promotions d'une division.
///
/// Seules la Formation Initiale et la Formation des Spécialistes en ont :
/// la Formation Continue ne contient que des stages, qui relèvent
/// directement de leur division.
class PromotionsRepository {
  /// De la plus récente à la plus ancienne — c'est celle qui est en
  /// formation qu'on cherche, pas celle d'il y a dix ans. Les promotions
  /// sans année déclarée ferment la marche.
  Future<List<Promotion>> fetchAll() async {
    final rows = await scolarite
        .from('promotions')
        .select()
        .order('annee', ascending: false, nullsFirst: false)
        .order('nom', ascending: true);
    return rows.map(Promotion.fromJson).toList();
  }

  Future<void> create({
    required String divisionId,
    required String nom,
    int? annee,
  }) {
    return _avecNomLisible(
      nom,
      () => avecSessionFraiche(
        () => scolarite.from('promotions').insert({
          'division_id': divisionId,
          'nom': nom,
          'annee': annee,
        }),
      ),
    );
  }

  Future<void> update({required String id, required String nom, int? annee}) {
    return _avecNomLisible(
      nom,
      () => avecSessionFraiche(
        () => scolarite
            .from('promotions')
            .update({'nom': nom, 'annee': annee})
            .eq('id', id),
      ),
    );
  }

  /// Deux promotions de même nom dans une division seraient
  /// indiscernables : la base l'interdit. Elle le dit en revanche dans sa
  /// langue — « duplicate key value violates unique constraint
  /// promotions_division_id_nom_key » —, ce qui n'apprend rien à qui saisit
  /// une promotion. On traduit.
  Future<T> _avecNomLisible<T>(String nom, Future<T> Function() action) async {
    try {
      return await action();
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw Exception(
          'Cette division a déjà une promotion nommée « $nom ». '
          'Choisissez un autre nom, ou modifiez celle qui existe — la liste '
          'ci-dessous les montre toutes.',
        );
      }
      rethrow;
    }
  }

  /// Supprimer une promotion emporte ses phases, et avec elles tout ce qui
  /// s'y rattache. On lit donc ce qui a réellement été supprimé : une
  /// suppression que la RLS refuse ne lève aucune erreur, et l'écran
  /// annoncerait un succès sur une promotion toujours en place.
  Future<void> delete(String id) async {
    final supprimees = await avecSessionFraiche(
      () => scolarite.from('promotions').delete().eq('id', id).select('id'),
    );

    if (supprimees.isEmpty) {
      throw Exception(
        'Aucune promotion supprimée : votre rôle ne vous y autorise pas.',
      );
    }
  }
}
