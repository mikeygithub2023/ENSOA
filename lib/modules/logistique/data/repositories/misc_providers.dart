import 'dart:async';

import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sig_ensoa/core/roles.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgresChangeEvent, RealtimeChannel;

import 'package:sig_ensoa/core/sonnerie.dart';
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

RoleLogistique _roleFromDb(String? value) {
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

/// Depuis la fusion, un profil peut ne relever que de la scolarité : son
/// matricule, son grade et son rôle du soutien technique sont alors nuls. Ce
/// convertisseur les lisait comme des chaînes obligatoires — la première
/// fiche d'élève rencontrée faisait échouer la lecture de tout le
/// référentiel, et le journal d'audit se retrouvait à n'afficher que des
/// identifiants techniques faute de savoir nommer qui que ce soit.
///
/// Et il lisait `role` — le rôle de la scolarité — là où il fallait
/// `role_logistique`.
AppUser _appUserFromRow(Map<String, dynamic> row) => AppUser(
  id: row['id'] as String,
  matricule: (row['matricule'] as String?) ?? '',
  nomComplet: (row['nom_complet'] as String?) ?? '',
  grade: (row['grade'] as String?) ?? '',
  role: _roleFromDb(row['role_logistique'] as String?),
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
    case 'activite':
      return NotificationCategory.activite;
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
      noteId: row['note_id'] as String?,
    );

/// Notifications persistées (table `notification`), filtrées côté RLS :
/// globales, ciblant mon rôle, ou m'étant destinées personnellement — donc
/// naturellement différentes d'un utilisateur connecté à l'autre.
class NotificationsNotifier extends Notifier<List<AppNotification>> {
  RealtimeChannel? _canal;
  Timer? _minuterie;
  AppLifecycleListener? _cycleDeVie;

  /// Le nombre de non-lues au dernier passage. Nul tant que rien n'a été lu
  /// une première fois : c'est ce qui distingue « il en arrive une » de
  /// « voici ce qui vous attendait ».
  int? _nonLues;

  /// Les notifications qu'on vient d'éteindre et dont le serveur n'a pas
  /// encore rendu compte.
  ///
  /// Sans ce souvenir, un clic pouvait rester sans effet visible. Une
  /// lecture partie une fraction de seconde plus tôt — la minuterie, le
  /// flux temps réel — revenait avec l'ancienne valeur et rallumait la
  /// notification, alors même que la base l'avait bien enregistrée comme
  /// lue. Vu de la tablette : « je clique, et rien ne se passe ».
  final Set<String> _luesLocalement = {};

  @override
  List<AppNotification> build() {
    Future.microtask(refresh);
    _seTenirAuCourant();
    ref.onDispose(() {
      _minuterie?.cancel();
      _cycleDeVie?.dispose();
      final canal = _canal;
      if (canal != null) supabase.removeChannel(canal);
    });
    return [];
  }

  /// Une notification qui n'arrive qu'au changement d'écran n'en est pas
  /// une : un administrateur qui laisse sa session ouverte ne voyait jamais
  /// venir une demande de suppression, jusqu'à ce qu'il clique lui-même sur
  /// la rubrique — auquel cas il l'avait déjà trouvée.
  ///
  /// Trois voies, à dessein. Le flux temps réel de Supabase donne l'alerte
  /// dans la seconde. La minuterie rattrape ce qu'il aurait manqué — une
  /// coupure de réseau, un socket refermé par un pare-feu : c'est elle qui
  /// garantit le délai, vingt secondes au pire, et elle seule qu'on puisse
  /// promettre. Le retour d'arrière-plan enfin, car une tablette qu'on
  /// rallume a pu dormir des heures, socket compris.
  ///
  /// Interroger une table de quelques dizaines de lignes à cette cadence ne
  /// coûte rien, et l'on ne dépend pas d'un seul mécanisme pour une
  /// information qu'on ne peut pas se permettre de rater.
  void _seTenirAuCourant() {
    _canal = supabase
        .channel('notifications-du-compte')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'socle',
          table: 'notifications',
          callback: (_) => _rafraichirSansBruit(),
        )
        .subscribe();

    _minuterie = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _rafraichirSansBruit(),
    );

    _cycleDeVie = AppLifecycleListener(onResume: _rafraichirSansBruit);
  }

  /// Le rafraîchissement de fond ne doit jamais faire tomber l'application :
  /// hors ligne, il échoue simplement, et la prochaine tentative reprendra.
  Future<void> _rafraichirSansBruit() async {
    try {
      await refresh();
    } catch (_) {}
  }

  Future<void> refresh() async {
    final rows = await socle
        .from('notifications')
        .select()
        .order('created_at', ascending: false);
    final duServeur = (rows as List)
        .map((r) => _notificationFromRow(r as Map<String, dynamic>))
        .toList();

    // Le serveur a rattrapé son retard sur ces lignes : on peut oublier.
    _luesLocalement.removeAll([
      for (final n in duServeur)
        if (n.lue) n.id,
    ]);

    final nouvelles = [
      for (final n in duServeur)
        if (!n.lue && _luesLocalement.contains(n.id)) n.copieLue() else n,
    ];

    // Sonner quand le nombre de non-lues augmente, et à cette condition
    // seule. Pas au premier chargement — on ne réveille pas quelqu'un qui
    // vient d'ouvrir l'application pour lui annoncer ce qu'il a déjà vu
    // hier — ni quand une notification est marquée lue, ce qui fait bouger
    // le compte dans l'autre sens.
    final avant = _nonLues;
    final apres = nouvelles.where((n) => !n.lue).length;
    state = nouvelles;
    if (avant != null && apres > avant) Sonnerie.notification();
    _nonLues = apres;
  }

  /// Marquer lu, sans attendre le serveur pour l'afficher.
  ///
  /// Trois défauts se cumulaient ici. La pastille ne s'éteignait qu'au
  /// retour du réseau — sur une tablette un aller-retour se voit, et celui
  /// qui ne voit rien reclique. Le `update` n'avait pas de `select` : si la
  /// RLS refusait la ligne, PostgREST répondait « aucune erreur, aucune
  /// ligne touchée » et l'écran affichait comme lue une notification qui ne
  /// l'était pas. Rien enfin ne remontait à l'appelant, qui n'avait pas de
  /// quoi prévenir.
  ///
  /// L'ordre est donc inversé : on éteint tout de suite, on écrit ensuite,
  /// et l'on rallume si le serveur n'a pas suivi. Une notification qu'on
  /// croit avoir lue et qui revient déroute plus qu'une erreur annoncée.
  Future<void> markRead(String id) async {
    final avant = state;
    state = [
      for (final n in state)
        if (n.id == id) n.copieLue() else n,
    ];
    _luesLocalement.add(id);
    _nonLues = state.where((n) => !n.lue).length;

    try {
      final touchees = await socle
          .from('notifications')
          .update({'read': true})
          .eq('id', id)
          .select('id');
      if (touchees.isEmpty) {
        throw Exception("Cette notification n'est pas la vôtre.");
      }
    } catch (_) {
      _luesLocalement.remove(id);
      state = avant;
      _nonLues = avant.where((n) => !n.lue).length;
      rethrow;
    }
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
    case RoleLogistique.profilPersonnalise:
      return 'profil_personnalise';
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
      [?row['table_name'] as String?, ?row['record_id'] as String?].join(' '),
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
    ref.read(chargementProvider.notifier).marquerCharge('journal');
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
