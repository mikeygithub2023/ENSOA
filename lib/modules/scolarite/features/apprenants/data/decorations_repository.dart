import 'package:intl/intl.dart';

import 'package:sig_ensoa/core/supabase_client.dart';
import '../../../models/decoration.dart';

/// Ce qu'on saisit en inscrivant une décoration reçue.
class DecorationRecueDraft {
  const DecorationRecueDraft({
    required this.apprenantId,
    required this.decorationId,
    this.dateAttribution,
    this.reference,
    this.echelon,
    this.observation,
  });

  final String apprenantId;
  final String decorationId;
  final DateTime? dateAttribution;
  final String? reference;
  final String? echelon;
  final String? observation;

  Map<String, dynamic> toJson() => {
    'apprenant_id': apprenantId,
    'decoration_id': decorationId,
    'date_attribution': dateAttribution == null
        ? null
        : DateFormat('yyyy-MM-dd').format(dateAttribution!),
    'reference': reference,
    'echelon': echelon,
    'observation': observation,
  };
}

class DecorationsRepository {
  static const _catalogue = 'decorations';
  static const _recues = 'decorations_recues';

  // --- Le catalogue ---------------------------------------------------------

  /// Le catalogue, dans l'ordre de préséance.
  ///
  /// [toutes] rend aussi les décorations désactivées — l'écran de gestion
  /// en a besoin, la saisie non.
  Future<List<TypeDecoration>> fetchCatalogue({bool toutes = false}) async {
    var requete = scolarite.from(_catalogue).select();
    if (!toutes) requete = requete.eq('active', true);
    final rows = await requete.order('ordre').order('libelle');
    return rows.map(TypeDecoration.fromJson).toList();
  }

  Future<void> creerDecoration({
    required String libelle,
    required int ordre,
  }) async {
    await scolarite.from(_catalogue).insert({
      'libelle': libelle,
      'ordre': ordre,
    });
  }

  Future<void> modifierDecoration(
    String id, {
    required String libelle,
    required int ordre,
    required bool active,
  }) async {
    await scolarite
        .from(_catalogue)
        .update({'libelle': libelle, 'ordre': ordre, 'active': active})
        .eq('id', id);
  }

  /// La base s'y oppose dès qu'un militaire la porte (`on delete
  /// restrict`) : l'écran propose alors de la désactiver.
  Future<void> supprimerDecoration(String id) async {
    await scolarite.from(_catalogue).delete().eq('id', id);
  }

  // --- Les attributions -----------------------------------------------------

  /// Toutes les attributions visibles, divisions confondues — la RLS borne
  /// le résultat. Les plus récentes d'abord ; celles sans date ferment la
  /// liste plutôt que de l'ouvrir.
  Future<List<DecorationRecue>> fetchRecues() async {
    final rows = await scolarite
        .from(_recues)
        .select()
        .order('date_attribution', ascending: false, nullsFirst: false);
    return rows.map(DecorationRecue.fromJson).toList();
  }

  Future<List<DecorationRecue>> fetchRecuesByApprenant(
    String apprenantId,
  ) async {
    final rows = await scolarite
        .from(_recues)
        .select()
        .eq('apprenant_id', apprenantId)
        .order('date_attribution', ascending: false, nullsFirst: false);
    return rows.map(DecorationRecue.fromJson).toList();
  }

  Future<void> creer(DecorationRecueDraft draft) async {
    await scolarite.from(_recues).insert(draft.toJson());
  }

  Future<void> modifier(String id, DecorationRecueDraft draft) async {
    await scolarite.from(_recues).update(draft.toJson()).eq('id', id);
  }

  Future<void> supprimer(String id) async {
    await scolarite.from(_recues).delete().eq('id', id);
  }
}
