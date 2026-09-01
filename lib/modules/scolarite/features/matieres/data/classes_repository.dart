import 'package:sig_ensoa/core/supabase_client.dart';
import '../../../models/classe.dart';

class ClassesRepository {
  /// Ordre d'enregistrement (création) — l'écran Matières > Classes trie
  /// lui-même par ordre alphabétique dans chaque division ; les autres
  /// écrans (ex. filtres Élèves & Stagiaires) affichent cet ordre naturel.
  Future<List<Classe>> fetchAll() async {
    final rows = await scolarite
        .from('classes')
        .select()
        .order('created_at', ascending: true);
    return rows.map(Classe.fromJson).toList();
  }

  /// Une phase appartient à une promotion, un stage n'en a pas : la base
  /// refuse toute autre combinaison. On force donc `promotion_id` à null
  /// pour un stage plutôt que de compter sur l'appelant.
  Future<void> create({
    required String divisionId,
    required ClasseType type,
    required String nom,
    String? promotionId,
    num coefficient = 1,
  }) {
    return scolarite.from('classes').insert({
      'division_id': divisionId,
      'type': type.name,
      'nom': nom,
      'promotion_id': type == ClasseType.phase ? promotionId : null,
      // Un stage ne se compose pas de phases : son coefficient ne pèserait
      // sur rien. On le laisse à 1 plutôt que d'inventer un sens.
      'coefficient': type == ClasseType.phase ? coefficient : 1,
    });
  }

  Future<void> update({
    required String id,
    required ClasseType type,
    required String nom,
    String? promotionId,
    num coefficient = 1,
  }) {
    return scolarite
        .from('classes')
        .update({
          'type': type.name,
          'nom': nom,
          'promotion_id': type == ClasseType.phase ? promotionId : null,
          'coefficient': type == ClasseType.phase ? coefficient : 1,
        })
        .eq('id', id);
  }

  /// Clôture une phase : elle est figée, et ses élèves actifs passent à la
  /// phase suivante. Rend le nombre d'élèves ayant migré.
  ///
  /// Tout se joue en base (migration 066) : l'ordre des clôtures, le
  /// verrou et la migration. Une clôture qui ne tiendrait qu'à l'interface
  /// n'en serait pas une.
  Future<int> cloturerPhase(String classeId) async {
    final resultat = await scolarite.rpc<dynamic>(
      'cloturer_phase',
      params: {'p_classe_id': classeId},
    );
    return resultat is int ? resultat : 0;
  }

  /// Rouvre une phase clôturée par erreur. Les élèves ne redescendent pas :
  /// les faire reculer d'office déferait des affectations peut-être déjà
  /// reprises à la main.
  Future<void> rouvrirPhase(String classeId) async {
    await scolarite.rpc<dynamic>(
      'rouvrir_phase',
      params: {'p_classe_id': classeId},
    );
  }

  Future<void> delete(String id) {
    return scolarite.from('classes').delete().eq('id', id);
  }
}
