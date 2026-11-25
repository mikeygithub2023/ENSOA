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

/// La division portant cet identifiant instruit-elle des élèves ?
///
/// La Division de Commandement et Logistique n'instruit personne : elle tient
/// le personnel de l'école. Le commandant qui en répond est, de fait, le chef
/// du bureau des ressources humaines — les cours, les matières et les
/// bulletins ne le concernent pas.
///
/// Rend `null` quand on ne peut pas le dire : aucune division retenue, liste
/// pas encore lue, ou identifiant qu'elle ne porte pas. L'appelant ne retire
/// alors rien : le menu se trompe du côté de l'ouverture, le serveur du côté
/// du refus — c'est la RLS qui borne, pas la barre de navigation.
bool? divisionInstruit(String? divisionId, List<Division>? divisions) {
  if (divisionId == null || divisions == null) return null;
  for (final d in divisions) {
    if (d.id == divisionId) return !d.tientDuPersonnel;
  }
  return null;
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
