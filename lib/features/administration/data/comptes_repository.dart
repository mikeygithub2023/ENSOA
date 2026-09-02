import '../../../core/postes.dart';
import '../../../core/roles.dart';
import '../../../core/supabase_client.dart';
import '../../../models/profil.dart';

/// Les comptes de l'école. La lecture et les modifications simples passent
/// par la table (la RLS décide) ; l'ouverture et la suppression passent par
/// des fonctions serveur, qui seules détiennent le droit de toucher aux
/// comptes d'authentification.
class ComptesRepository {
  Future<List<Profil>> lister() async {
    final donnees = await socle
        .from('profiles')
        .select()
        .order('matricule', ascending: true);
    return (donnees as List)
        .map((e) => Profil.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> ouvrir({
    required String matricule,
    required String nom,
    required String prenom,
    required String? grade,
    required Poste poste,
    required String motDePasse,
    String? titre,
    String? divisionId,
    String? promotionId,
    int? celluleId,
  }) async {
    final reponse = await supabase.functions.invoke(
      'creer-compte',
      body: {
        'matricule': matricule,
        'nom': nom,
        'prenom': prenom,
        'grade': grade,
        'poste': poste.name.toSnake(),
        'motDePasse': motDePasse,
        'titre': titre,
        'divisionId': divisionId,
        // La promotion que commande un Commandant de Brigade. C'est elle qui
        // borne tout ce qu'il voit : sans elle, son compte s'ouvre sur du
        // vide.
        'promotionId': promotionId,
        'celluleId': celluleId,
      },
    );
    _verifier(reponse.status, reponse.data);
  }

  Future<void> supprimer(String id) async {
    final reponse = await supabase.functions.invoke(
      'supprimer-compte',
      body: {'id': id},
    );
    _verifier(reponse.status, reponse.data);
  }

  /// Désactiver plutôt que supprimer : le compte ne s'ouvre plus, mais tout
  /// ce que son titulaire a saisi reste attribué à quelqu'un. Un journal
  /// d'audit qui pointe vers un compte effacé ne vaut plus grand-chose.
  Future<void> changerActivation(String id, bool actif) async {
    await socle.from('profiles').update({'actif': actif}).eq('id', id);
  }

  /// Identité et affectation. Le matricule ne se modifie pas ici : c'est la
  /// clé de connexion, et la changer sans refaire le compte d'authentification
  /// laisserait le titulaire à la porte.
  Future<void> modifier({
    required String id,
    required String nom,
    required String prenom,
    required String? grade,
    required String? titre,
    required Poste poste,
    String? promotionId,
  }) async {
    await socle
        .from('profiles')
        .update({
          'nom': nom,
          'prenom': prenom,
          'grade': grade,
          'titre': titre,
          'role': poste.roleScolarite?.valeurDb,
          'role_logistique': poste.roleLogistique?.valeurDb,
          // Nulle pour tout autre poste : une promotion qui resterait
          // accrochée à un compte devenu instructeur lui ouvrirait des
          // écrans qui ne le regardent plus.
          'promotion_id':
              (poste == Poste.commandantBrigade ||
                  poste == Poste.commandantPromotion)
              ? promotionId
              : null,
        })
        .eq('id', id);
  }

  Future<void> changerPoste(String id, Poste poste) async {
    await socle
        .from('profiles')
        .update({
          'role': poste.roleScolarite?.valeurDb,
          'role_logistique': poste.roleLogistique?.valeurDb,
        })
        .eq('id', id);
  }

  void _verifier(int? status, dynamic data) {
    if (status == 200) return;
    final message = data is Map && data['error'] != null
        ? data['error'].toString()
        : "L'opération a échoué (code $status).";
    throw Exception(message);
  }
}

extension on String {
  /// `chefSoutienTechnique` → `chef_soutien_technique`, la forme attendue par
  /// la fonction serveur et par la base.
  String toSnake() => replaceAllMapped(
    RegExp(r'[A-Z]'),
    (m) => '_${m[0]!.toLowerCase()}',
  );
}
