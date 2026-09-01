import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sig_ensoa/core/supabase_client.dart';

/// Une promotion regroupe les phases d'une division — Formation Initiale et
/// Formation des Spécialistes en ont, la Formation Continue n'en a pas :
/// elle ne contient que des stages.
class Promotion {
  const Promotion({
    required this.id,
    required this.divisionId,
    required this.nom,
    this.annee,
  });

  final String id;
  final String divisionId;
  final String nom;

  /// Année d'incorporation, quand l'école la précise. Elle sert à ranger
  /// les promotions du plus récent au plus ancien.
  final int? annee;

  String get intitule => annee == null ? nom : '$nom ($annee)';

  factory Promotion.fromJson(Map<String, dynamic> json) {
    return Promotion(
      id: json['id'] as String,
      divisionId: json['division_id'] as String,
      nom: json['nom'] as String,
      annee: json['annee'] as int?,
    );
  }
}

/// Toutes les promotions de l'école, la plus récente d'abord.
///
/// Sert à rattacher un Commandant de Brigade à celle qu'il commande : c'est
/// ce rattachement, et lui seul, qui décide de ce qu'il voit. La RLS le borne
/// aux phases de cette promotion et aux élèves qui y sont affectés.
final promotionsProvider = FutureProvider.autoDispose<List<Promotion>>((
  ref,
) async {
  final rows = await scolarite
      .from('promotions')
      .select()
      .order('annee', ascending: false)
      .order('nom');
  return rows.map(Promotion.fromJson).toList();
});
