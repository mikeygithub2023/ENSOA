import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sig_ensoa/core/supabase_client.dart';

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

final divisionsProvider = FutureProvider.autoDispose<List<Division>>((
  ref,
) async {
  final rows = await socle
      .from('divisions')
      .select()
      .order('ordre', ascending: true);
  return rows.map(Division.fromJson).toList();
});
