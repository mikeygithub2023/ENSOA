import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    this.fichierPath,
    this.fichierNom,
  });

  final String apprenantId;
  final String pieceId;
  final bool presente;
  final DateTime? verifieLe;
  final String? verifiePar;
  final String? observation;

  /// Un scan qu'on vient de déposer. Nul : la ligne garde celui qu'elle a.
  final String? fichierPath;
  final String? fichierNom;

  Map<String, dynamic> toUpsertJson() => {
    'apprenant_id': apprenantId,
    'piece_id': pieceId,
    'presente': presente,
    'verifie_le': verifieLe == null
        ? null
        : DateFormat('yyyy-MM-dd').format(verifieLe!),
    'verifie_par': verifiePar,
    'observation': observation,
    if (fichierPath != null) 'fichier_path': fichierPath,
    if (fichierPath != null) 'fichier_nom': fichierNom,
  };
}

/// Les formats qu'on accepte pour une pièce numérisée — ceux que le dépôt
/// accepte aussi, et sa taille maximale.
const extensionsPiecePension = ['pdf', 'jpg', 'jpeg', 'png'];
const tailleMaxPiecePension = 10 * 1024 * 1024;

/// Le type du fichier, d'après son extension.
String typeDuFichierPension(String nom) {
  final ext = nom.contains('.') ? nom.split('.').last.toLowerCase() : '';
  return switch (ext) {
    'pdf' => 'application/pdf',
    'png' => 'image/png',
    _ => 'image/jpeg',
  };
}

/// Le chemin d'un scan : `<militaire>/<pièce>.<extension>`. La RLS du
/// dépôt lit le militaire dans ce chemin.
String cheminPiecePension({
  required String apprenantId,
  required String pieceId,
  required String nom,
}) {
  final ext = nom.contains('.') ? nom.split('.').last.toLowerCase() : 'pdf';
  return '$apprenantId/$pieceId.${ext == 'jpeg' ? 'jpg' : ext}';
}

class PensionRepository {
  static const _catalogue = 'pieces_pension';
  static const _dossiers = 'dossiers_pension';
  static const _depot = 'dossiers-pension';

  // --- Le catalogue des pièces ---------------------------------------------

  /// Le catalogue, dans l'ordre du dossier.
  ///
  /// [toutes] rend aussi les pièces désactivées — l'écran de gestion en a
  /// besoin pour les réactiver, la saisie non.
  Future<List<PiecePension>> fetchPieces({bool toutes = false}) async {
    var requete = scolarite.from(_catalogue).select();
    if (!toutes) requete = requete.eq('active', true);
    // `order` trie par défaut du plus grand au plus petit : l'ordre du
    // dossier se lit, lui, du premier au dernier.
    final rows = await requete
        .order('ordre', ascending: true)
        .order('libelle', ascending: true);
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
    String? fichierPath,
  }) async {
    await scolarite
        .from(_dossiers)
        .delete()
        .eq('apprenant_id', apprenantId)
        .eq('piece_id', pieceId);
    // Sans sa ligne, le scan ne serait plus rattaché à rien.
    if (fichierPath != null) {
      await supabase.storage.from(_depot).remove([fichierPath]);
    }
  }

  // --- Les pièces numérisées -------------------------------------------------

  /// Dépose le scan d'une pièce et rend son chemin. Un scan déjà déposé sous
  /// une autre extension est retiré : la pièce n'en garde qu'un.
  Future<String> deposerFichier({
    required String apprenantId,
    required String pieceId,
    required Uint8List octets,
    required String nom,
    String? ancienChemin,
  }) async {
    final chemin = cheminPiecePension(
      apprenantId: apprenantId,
      pieceId: pieceId,
      nom: nom,
    );
    await supabase.storage
        .from(_depot)
        .uploadBinary(
          chemin,
          octets,
          fileOptions: FileOptions(
            upsert: true,
            contentType: typeDuFichierPension(nom),
          ),
        );
    if (ancienChemin != null && ancienChemin != chemin) {
      await supabase.storage.from(_depot).remove([ancienChemin]);
    }
    return chemin;
  }

  /// Les octets d'un scan, pour le revoir ou l'enregistrer sur le poste.
  Future<Uint8List> telechargerFichier(String chemin) {
    return supabase.storage.from(_depot).download(chemin);
  }
}
