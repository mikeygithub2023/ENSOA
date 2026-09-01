import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sig_ensoa/core/supabase_client.dart';
import 'division.dart';

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

/// Une promotion et le nom de la division dont elle relève.
///
/// Deux divisions peuvent nommer leurs promotions de la même façon — une
/// « 1ère promotion » existe des deux côtés. Choisir sur le seul nom, c'est
/// risquer de rattacher un Commandant de Brigade à une promotion qui n'est
/// pas la sienne, et de lui ouvrir des élèves qu'il n'a pas à voir.
class PromotionNommee {
  const PromotionNommee(this.promotion, this.division);

  final Promotion promotion;

  /// Nul si la division n'a pas pu être lue — on affiche alors la promotion
  /// seule plutôt que rien.
  final String? division;

  String get id => promotion.id;
  String get divisionId => promotion.divisionId;

  String get intitule => division == null
      ? promotion.intitule
      : '${promotion.intitule} · $division';
}

/// Les promotions désignées par leur nom et leur division, rangées par
/// division puis de la plus récente à la plus ancienne.
final promotionsNommeesProvider =
    FutureProvider.autoDispose<List<PromotionNommee>>((ref) async {
      final promotions = await ref.watch(promotionsProvider.future);
      final divisions = await ref.watch(divisionsProvider.future);
      final nomDeLaDivision = {for (final d in divisions) d.id: d.nom};

      return [
        for (final p in promotions)
          PromotionNommee(p, nomDeLaDivision[p.divisionId]),
      ]..sort((a, b) {
        final parDivision = (a.division ?? '').compareTo(b.division ?? '');
        return parDivision != 0
            ? parDivision
            : a.promotion.intitule.compareTo(b.promotion.intitule);
      });
    });
