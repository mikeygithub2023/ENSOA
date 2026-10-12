import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase_client.dart';
import '../../../models/profil_personnalise.dart';

/// Le catalogue des services créés par l'administrateur.
///
/// `autoDispose` à dessein : la liste se recharge en entrant dans l'écran.
/// Un provider gardé pour la session avait déjà fait croire qu'un compte
/// gardait sa mention « mot de passe à changer » après l'avoir changé.
final profilsPersonnalisesProvider =
    FutureProvider.autoDispose<List<ProfilPersonnalise>>((ref) async {
      final rows = await socle
          .from('profil_personnalise')
          .select()
          .isFilter('supprime_le', null)
          .order('libelle');
      return (rows as List)
          .map((r) => ProfilPersonnalise.fromJson(r as Map<String, dynamic>))
          .toList();
    });

/// Ceux à qui l'on peut encore confier une tâche ou ouvrir un compte.
final profilsPersonnalisesActifsProvider =
    Provider.autoDispose<List<ProfilPersonnalise>>((ref) {
      return ref
              .watch(profilsPersonnalisesProvider)
              .value
              ?.where((p) => p.actif)
              .toList() ??
          const [];
    });

class ProfilsPersonnalisesRepository {
  /// Crée un service. Le `select` n'est pas décoratif : sans lui, une
  /// insertion que la RLS refuserait passerait pour un succès — PostgREST
  /// répond « aucune ligne touchée », sans erreur.
  Future<ProfilPersonnalise> creer({
    required String libelle,
    String? description,
  }) async {
    final lignes = await socle.from('profil_personnalise').insert({
      'libelle': libelle.trim(),
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
    }).select();

    if (lignes.isEmpty) {
      throw Exception(
        "Le service n'a pas été créé : seul l'administrateur peut le faire.",
      );
    }
    return ProfilPersonnalise.fromJson(lignes.first);
  }

  Future<void> renommer(String id, String libelle, String? description) async {
    final lignes = await socle
        .from('profil_personnalise')
        .update({'libelle': libelle.trim(), 'description': description?.trim()})
        .eq('id', id)
        .select('id');
    if (lignes.isEmpty) throw Exception('Modification refusée par le serveur.');
  }

  /// Retirer plutôt que supprimer : les tâches déjà confiées gardent le nom
  /// du service qui les a reçues. Une suppression trouerait l'historique des
  /// activités, et la base la refuserait de toute façon — les tâches y
  /// renvoient.
  Future<void> changerActivite(String id, bool actif) async {
    final lignes = await socle
        .from('profil_personnalise')
        .update({'actif': actif})
        .eq('id', id)
        .select('id');
    if (lignes.isEmpty) throw Exception('Changement refusé par le serveur.');
  }

  /// Supprime un service. Sa ligne survit — les tâches qu'il a reçues
  /// gardent son nom, et les effacer trouerait l'historique des activités —
  /// mais il disparaît de la liste, de la répartition et de l'ouverture de
  /// compte.
  ///
  /// La base refuse si des comptes actifs y sont encore rattachés : ils
  /// deviendraient membres d'un service invisible, sans rien voir et sans
  /// que rien ne dise pourquoi.
  Future<void> supprimer(String id) async {
    final lignes = await socle
        .from('profil_personnalise')
        .update({'supprime_le': DateTime.now().toIso8601String()})
        .eq('id', id)
        .select('id');
    if (lignes.isEmpty) throw Exception('Suppression refusée par le serveur.');
  }
}

final profilsPersonnalisesRepositoryProvider = Provider(
  (ref) => ProfilsPersonnalisesRepository(),
);
