import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sig_ensoa/core/supabase_client.dart';

/// Le code de la Division de Commandement et Logistique.
///
/// Elle ne ressemble à aucune autre : elle n'instruit personne, et n'a donc
/// ni promotion ni stage. Elle regroupe le personnel de l'école, qui reçoit
/// la même fiche que les élèves — la prise d'armes du matin compte tout le
/// monde.
const codeDivisionCommandement = 'commandement_logistique';

class Division {
  const Division({required this.id, required this.code, required this.nom});

  final String id;
  final String code;
  final String nom;

  factory Division.fromJson(Map<String, dynamic> json) {
    return Division(
      id: json['id'] as String,
      code: json['code'] as String,
      nom: json['nom'] as String,
    );
  }
}

extension DivisionCursus on Division {
  /// Cette division tient-elle du personnel plutôt que des élèves ?
  bool get tientDuPersonnel => code == codeDivisionCommandement;
}

final divisionsProvider = FutureProvider.autoDispose<List<Division>>((
  ref,
) async {
  final rows = await socle
      .from('divisions')
      .select()
      .order('ordre', ascending: true);
  return rows.map(Division.fromJson).toList();
});
