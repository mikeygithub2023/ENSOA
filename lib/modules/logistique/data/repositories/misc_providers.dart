import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sig_ensoa/core/roles.dart';
import 'package:sig_ensoa/core/supabase_client.dart';
import 'package:sig_ensoa/core/chargement.dart';
import '../models/audit_entry.dart';
import '../models/notification_item.dart';
import '../models/user.dart';

AppUser? findUser(List<AppUser> users, String id) {
  for (final u in users) {
    if (u.id == id) return u;
  }
  return null;
}

RoleLogistique _roleFromDb(String value) {
  switch (value) {
    case 'chef_soutien_technique':
      return RoleLogistique.chefSoutienTechnique;
    case 'soutien_petrolier':
      return RoleLogistique.soutienPetrolier;
    case 'garage':
      return RoleLogistique.garage;
    case 'armurerie':
      return RoleLogistique.armurerie;
    case 'poste_police':
      return RoleLogistique.postePolice;
    case 'officier_adjoint':
      return RoleLogistique.officierAdjoint;
    case 'sante':
      return RoleLogistique.sante;
    case 'administrateur':
      return RoleLogistique.administrateur;
    default:
      return RoleLogistique.soutienPetrolier;
  }
}

AppUser _appUserFromRow(Map<String, dynamic> row) => AppUser(
  id: row['id'] as String,
  matricule: row['matricule'] as String,
  nomComplet: row['nom_complet'] as String,
  grade: row['grade'] as String,
  role: _roleFromDb(row['role'] as String),
  celluleId: row['cellule_id']?.toString(),
  actif: (row['actif'] as bool?) ?? true,
);

/// Référentiel des comptes utilisateurs (table `profiles`) — sert à résoudre
/// "qui est l'auteur de cette action" dans le journal d'audit, et à la
/// gestion des utilisateurs par l'administrateur. La RLS ne laisse voir
/// l'ensemble des profils qu'au chef soutien technique et à l'administrateur ;
/// les autres rôles ne voient que le leur.
class UsersNotifier extends Notifier<List<AppUser>> {
  @override
  List<AppUser> build() {
    Future.microtask(refresh);
    return [];
  }

  Future<void> refresh() async {
    final rows = await socle.from('profiles').select();
    state = (rows as List)
        .map((r) => _appUserFromRow(r as Map<String, dynamic>))
        .toList();
    ref.read(chargementProvider.notifier).marquerCharge('utilisateurs');
  }

  /// L'app n'a pas les droits pour créer un compte Supabase Auth (ça exige
  /// la clé service_role, jamais embarquée côté client) : cette opération
  /// passe par la fonction serveur `admin-create-user`, qui détient cette
  /// clé côté Supabase et vérifie elle-même que l'appelant est bien un
  /// administrateur avant d'agir. Crée le compte ET la fiche `profiles` en
  /// un seul appel — retourne l'UUID du nouveau compte.
  Future<String> creerUtilisateurComplet({
    required String email,
    required String password,
    required String matricule,
    required String nomComplet,
    required String grade,
    required RoleLogistique role,
    String? celluleId,
  }) async {
    final reponse = await supabase.functions.invoke(
      'admin-create-user',
      body: {
        'email': email,
        'password': password,
        'matricule': matricule,
        'nomComplet': nomComplet,
        'grade': grade,
        'role': _roleToDb(role),
        'celluleId': celluleId == null ? null : int.parse(celluleId),
      },
    );
    final data = reponse.data;
    if (data is Map && data['error'] != null) {
      throw Exception(data['error']);
    }
    if (data is! Map || data['id'] == null) {
      throw Exception('Réponse inattendue de la fonction serveur.');
    }
    await refresh();
    return data['id'] as String;
  }

  Future<void> modifier({
    required String id,
    required String nomComplet,
    required String grade,
    required RoleLogistique role,
  }) async {
    await socle
        .from('profiles')
        .update({
          'nom_complet': nomComplet,
          'grade': grade,
          'role': _roleToDb(role),
        })
        .eq('id', id);
    await refresh();
  }

  Future<void> activerDesactiver(String id, bool actif) async {
    await socle.from('profiles').update({'actif': actif}).eq('id', id);
    await refresh();
  }

  /// Peut échouer (contrainte de clé étrangère) si ce compte a déjà des
  /// actions enregistrées ailleurs (historique, réparations, dotations...) —
  /// dans ce cas, désactiver le compte plutôt que le supprimer.
  Future<void> supprimer(String id) async {
    await socle.from('profiles').delete().eq('id', id);
    await refresh();
  }
}

final usersProvider = NotifierProvider<UsersNotifier, List<AppUser>>(
  UsersNotifier.new,
);

NotificationCategory _categorieFromDb(String value) {
  switch (value) {
    case 'carburant':
      return NotificationCategory.carburant;
    case 'maintenance':
      return NotificationCategory.maintenance;
    case 'armement':
      return NotificationCategory.armement;
    default:
      return NotificationCategory.systeme;
  }
}

String _categorieToDb(NotificationCategory c) => c.name;

AppNotification _notificationFromRow(Map<String, dynamic> row) =>
    AppNotification(
      id: row['id'].toString(),
      categorie: _categorieFromDb(row['type'] as String),
      titre: row['title'] as String,
      message: row['message'] as String,
      date: DateTime.parse(row['created_at'] as String),
      lue: row['read'] as bool,
    );

/// Notifications persistées (table `notification`), filtrées côté RLS :
/// globales, ciblant mon rôle, ou m'étant destinées personnellement — donc
/// naturellement différentes d'un utilisateur connecté à l'autre.
class NotificationsNotifier extends Notifier<List<AppNotification>> {
  @override
  List<AppNotification> build() {
    Future.microtask(refresh);
    return [];
  }

  Future<void> refresh() async {
    final rows = await socle
        .from('notifications')
        .select()
        .order('created_at', ascending: false);
    state = (rows as List)
        .map((r) => _notificationFromRow(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> markRead(String id) async {
    await socle
        .from('notifications')
        .update({'read': true})
        .eq('id', id);
    state = [
      for (final n in state)
        if (n.id == id)
          AppNotification(
            id: n.id,
            categorie: n.categorie,
            titre: n.titre,
            message: n.message,
            date: n.date,
            lue: true,
          )
        else
          n,
    ];
  }

  /// [destinataireId] cible un utilisateur précis, [roleCible] tout un rôle ;
  /// laisser les deux à null pour une notification globale (tous les rôles).
  Future<void> creer({
    required NotificationCategory categorie,
    required String titre,
    required String message,
    String? destinataireId,
    RoleLogistique? roleCible,
  }) async {
    await socle.from('notifications').insert({
      'type': _categorieToDb(categorie),
      'title': titre,
      'message': message,
      'profile_id': destinataireId,
      'role_cible': roleCible == null ? null : _roleToDb(roleCible),
    });
    await refresh();
  }

  /// Une notification par rôle listé — la colonne `role_cible` ne porte
  /// qu'un seul rôle à la fois, donc "notifier CST et Garage" veut dire deux
  /// lignes distinctes, chacune ciblant son rôle.
  Future<void> creerPourRoles({
    required NotificationCategory categorie,
    required String titre,
    required String message,
    required List<RoleLogistique> roles,
  }) async {
    for (final role in roles) {
      await creer(
        categorie: categorie,
        titre: titre,
        message: message,
        roleCible: role,
      );
    }
  }
}

String _roleToDb(RoleLogistique role) {
  switch (role) {
    case RoleLogistique.chefSoutienTechnique:
      return 'chef_soutien_technique';
    case RoleLogistique.soutienPetrolier:
      return 'soutien_petrolier';
    case RoleLogistique.garage:
      return 'garage';
    case RoleLogistique.armurerie:
      return 'armurerie';
    case RoleLogistique.postePolice:
      return 'poste_police';
    case RoleLogistique.officierAdjoint:
      return 'officier_adjoint';
    case RoleLogistique.sante:
      return 'sante';
    case RoleLogistique.administrateur:
      return 'administrateur';
  }
}

final notificationsProvider =
    NotifierProvider<NotificationsNotifier, List<AppNotification>>(
      NotificationsNotifier.new,
    );

AuditEntry _auditEntryFromRow(Map<String, dynamic> row) => AuditEntry(
  id: row['id'].toString(),
  date: DateTime.parse(row['created_at'] as String),
  auteurId: (row['actor_id'] as String?) ?? '',
  action: row['action'] as String,
  // Une ligne écrite par l'application nomme sa cible ; une ligne posée par
  // un déclencheur de la scolarité nomme la table et l'enregistrement.
  cible:
      (row['cible'] as String?) ??
      [
        ?row['table_name'] as String?,
        ?row['record_id'] as String?,
      ].join(' '),
  detail: row['detail'] as String?,
);

/// Le journal d'audit — une seule table pour l'école entière (`audit_log`) :
/// était réinitialisé à chaque redémarrage de l'app (état local uniquement).
class AuditNotifier extends Notifier<List<AuditEntry>> {
  @override
  List<AuditEntry> build() {
    Future.microtask(refresh);
    return [];
  }

  Future<void> refresh() async {
    final rows = await socle
        .from('audit_log')
        .select()
        .order('created_at', ascending: false)
        .limit(500);
    state = (rows as List)
        .map((r) => _auditEntryFromRow(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> log({
    required String auteurId,
    required String action,
    required String cible,
    String? detail,
  }) async {
    try {
      await socle.from('audit_log').insert({
        'actor_id': auteurId,
        'action': action,
        'cible': cible,
        'detail': detail,
      });
      await refresh();
    } catch (_) {
      // Best-effort : un échec de journalisation ne doit pas bloquer l'action principale.
    }
  }
}

final auditProvider = NotifierProvider<AuditNotifier, List<AuditEntry>>(
  AuditNotifier.new,
);
