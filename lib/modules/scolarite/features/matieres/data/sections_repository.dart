import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import 'package:sig_ensoa/core/session_fraiche.dart';
import 'package:sig_ensoa/core/supabase_client.dart';
import '../../../models/section.dart';

/// Les sections, par promotion.
///
/// Elles se tiennent comme les promotions dont elles relèvent : le chef de
/// division sur sa division, le commandant de promotion et le commandant de
/// brigade sur la leur, l'administrateur partout. La RLS en répond.
class SectionsRepository {
  Future<List<Section>> fetchAll() async {
    final rows = await scolarite
        .from('sections')
        .select()
        .order('ordre', ascending: true)
        .order('nom', ascending: true);
    return rows.map(Section.fromJson).toList();
  }

  Future<void> create({
    required String promotionId,
    required String nom,
    int ordre = 0,
  }) {
    return _avecNomLisible(
      nom,
      () => avecSessionFraiche(
        () => scolarite.from('sections').insert({
          'promotion_id': promotionId,
          'nom': nom,
          'ordre': ordre,
        }),
      ),
    );
  }

  Future<void> update({
    required String id,
    required String nom,
    required int ordre,
  }) {
    return _avecNomLisible(
      nom,
      () => avecSessionFraiche(
        () => scolarite
            .from('sections')
            .update({'nom': nom, 'ordre': ordre})
            .eq('id', id),
      ),
    );
  }

  /// Supprimer une section ne supprime pas ses élèves : la colonne est en
  /// `on delete set null`, ils reviennent « sans section ». On le dit à
  /// l'écran plutôt que de laisser croire à une perte.
  Future<void> delete(String id) async {
    final supprimees = await avecSessionFraiche(
      () => scolarite.from('sections').delete().eq('id', id).select('id'),
    );

    if (supprimees.isEmpty) {
      throw Exception(
        'Aucune section supprimée : votre rôle ne vous y autorise pas.',
      );
    }
  }

  /// Affecte — ou retire, avec [sectionId] nul — une section à plusieurs
  /// élèves en une seule écriture.
  ///
  /// C'est l'opération courante : on répartit une promotion entière, pas un
  /// élève à la fois. La base vérifie au passage que la section relève bien
  /// de la promotion de chacun (déclencheur `apprenant_tient_sa_section`).
  Future<void> affecter({
    required List<String> apprenantIds,
    required String? sectionId,
  }) async {
    if (apprenantIds.isEmpty) return;
    final modifies = await avecSessionFraiche(
      () => scolarite
          .from('apprenants')
          .update({'section_id': sectionId})
          .inFilter('id', apprenantIds)
          .select('id'),
    );

    if (modifies.isEmpty) {
      throw Exception(
        'Aucun élève n\'a été déplacé : votre rôle ne vous y autorise pas.',
      );
    }
  }

  /// Deux sections de même nom dans une promotion seraient
  /// indiscernables : la base l'interdit, et le dit dans sa langue. On
  /// traduit.
  Future<T> _avecNomLisible<T>(String nom, Future<T> Function() action) async {
    try {
      return await action();
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw Exception(
          'Cette promotion a déjà une section nommée « $nom ». Choisissez un '
          'autre nom, ou modifiez celle qui existe.',
        );
      }
      rethrow;
    }
  }
}
