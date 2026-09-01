import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sig_ensoa/core/supabase_client.dart';

class Diplome {
  const Diplome({required this.id, required this.nom});

  final String id;
  final String nom;

  factory Diplome.fromJson(Map<String, dynamic> json) {
    return Diplome(id: json['id'] as String, nom: json['nom'] as String);
  }
}

final diplomesProvider = FutureProvider.autoDispose<List<Diplome>>((ref) async {
  final rows = await scolarite
      .from('diplomes')
      .select()
      .order('nom', ascending: true);
  return rows.map(Diplome.fromJson).toList();
});
