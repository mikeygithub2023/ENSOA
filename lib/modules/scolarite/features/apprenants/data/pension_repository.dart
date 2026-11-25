import 'package:intl/intl.dart';

import 'package:sig_ensoa/core/supabase_client.dart';
import '../../../models/pension.dart';

/// Ce qu'on enregistre en vérifiant une pièce du dossier.
///
/// Pas d'identifiant : la ligne est désignée par le militaire et la pièce.
/// Deux vérifications successives de la même pièce corrigent la même ligne
/// plutôt que d'en empiler deux qui se contredisent — c'est la contrainte
/// d'unicité de la base qui le garantit, et l'`upsert` qui s'y appuie.
class LignePensionDraft {
  const LignePensionDraft({
    required this.apprenantId,
    required this.pieceId,
    required this.presente,
    this.verifieLe,
    this.verifiePar,
    this.observation,
  });

  final String apprenantId;
  final String pieceId;
  final bool presente;
  final DateTime? verifieLe;
  final String? verifiePar;
  final String? observation;

  Map<String, dynamic> toUpsertJson() => {
    'apprenant_id': apprenantId,
    'piece_id': pieceId,
    'presente': presente,
    'verifie_le': verifieLe == null
        ? null
        : DateFormat('yyyy-MM-dd').format(verifieLe!),
    'verifie_par': verifiePar,
    'observation': observation,
  };
}

class PensionRepository {
  static const _catalogue = 'pieces_pension';
  static const _dossiers = 'dossiers_pension';

  // --- Le catalogue des pièces ---------------------------------------------

  /// Le catalogue, dans l'ordre du dossier.
  ///
  /// [toutes] rend aussi les pièces désactivées — l'écran de gestion en a
  /// besoin pour les réactiver, la saisie non.
  Future<List<PiecePension>> fetchPieces({bool toutes = false}) async {
    var requete = scolarite.from(_catalogue).select();
    if (!toutes) requete = requete.eq('active', true);
    final rows = await requete.order('ordre').order('libelle');
    return rows.map(PiecePension.fromJson).toList();
  }

  Future<void> creerPiece({
    required String libelle,
    required int ordre,
    required bool obligatoire,
  }) async {
    await scolarite.from(_catalogue).insert({
      'libelle': libelle,
      'ordre': ordre,
      'obligatoire': obligatoire,
    });
  }

  Future<void> modifierPiece(
    String id, {
    required String libelle,
    required int ordre,
    required bool obligatoire,
    required bool active,
  }) async {
    await scolarite
        .from(_catalogue)
        .update({
          'libelle': libelle,
          'ordre': ordre,
          'obligatoire': obligatoire,
          'active': active,
        })
        .eq('id', id);
  }

  /// Supprime une pièce du catalogue.
  ///
  /// La base s'y oppose (`on delete restrict`) dès qu'un dossier la
  /// mentionne : c'est voulu, et l'écran propose alors de la désactiver.
  Future<void> supprimerPiece(String id) async {
    await scolarite.from(_catalogue).delete().eq('id', id);
  }

  // --- Les vérifications ----------------------------------------------------

  /// Toutes les lignes visibles, divisions confondues. La RLS borne le
  /// résultat ; l'écran les range par militaire.
  Future<List<LignePension>> fetchLignes() async {
    final rows = await scolarite.from(_dossiers).select();
    return rows.map(LignePension.fromJson).toList();
  }

  Future<List<LignePension>> fetchLignesByApprenant(String apprenantId) async {
    final rows = await scolarite
        .from(_dossiers)
        .select()
        .eq('apprenant_id', apprenantId);
    return rows.map(LignePension.fromJson).toList();
  }

  Future<void> enregistrer(LignePensionDraft draft) async {
    await scolarite
        .from(_dossiers)
        .upsert(draft.toUpsertJson(), onConflict: 'apprenant_id,piece_id');
  }

  /// Efface la vérification d'une pièce — la pièce redevient « non
  /// vérifiée », ce qui n'est pas la même chose que « manquante ».
  Future<void> effacer({
    required String apprenantId,
    required String pieceId,
  }) async {
    await scolarite
        .from(_dossiers)
        .delete()
        .eq('apprenant_id', apprenantId)
        .eq('piece_id', pieceId);
  }
}
