import 'package:sig_ensoa/core/supabase_client.dart';
import 'package:sig_ensoa/modules/scolarite/compat.dart';

class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.action,
    required this.tableName,
    required this.recordId,
    required this.createdAt,
    this.actorId,
    this.auteur,
    this.meta,
  });

  final int id;
  final String action;
  final String tableName;
  final String? recordId;
  final String? actorId;
  final DateTime createdAt;

  /// Identité de l'auteur, résolue à l'affichage depuis `actor_id`.
  ///
  /// Nulle quand le compte a depuis été supprimé — le journal, lui, garde
  /// la trace de l'acte : c'est tout son objet.
  final String? auteur;

  /// La ligne telle qu'elle était au moment de l'acte, écrite par le
  /// trigger d'audit. On n'en montre que ce qui identifie l'enregistrement.
  final Map<String, dynamic>? meta;

  /// L'auteur, tel qu'on l'écrit dans le journal.
  String get auteurLabel => auteur ?? 'Compte supprimé';

  /// Ce sur quoi a porté l'acte, en clair.
  ///
  /// `meta` contient la ligne entière : l'afficher telle quelle noierait le
  /// lecteur. On en tire les champs qui désignent l'enregistrement, dans
  /// l'ordre où un militaire le nommerait — le grade et le nom avant le
  /// matricule, le libellé avant l'identifiant.
  String get resume {
    final donnees = meta;
    if (donnees == null || donnees.isEmpty) {
      return 'Enregistrement ${recordId ?? '—'}';
    }

    String? valeur(String cle) {
      final v = donnees[cle];
      if (v == null) return null;
      final texte = v.toString().trim();
      return texte.isEmpty ? null : texte;
    }

    final identite = [
      valeur('grade'),
      valeur('prenom'),
      valeur('nom'),
    ].whereType<String>().join(' ');

    final morceaux = <String>[
      if (identite.isNotEmpty) identite,
      ...[
        'libelle',
        'titre',
        'intitule',
        'matricule',
        'motif',
        'categorie',
        'montant',
        'note',
        'stock',
        'role',
        'statut',
        'type',
      ].map(valeur).whereType<String>(),
    ];

    if (morceaux.isEmpty) return 'Enregistrement ${recordId ?? '—'}';
    return morceaux.take(4).join(' · ');
  }

  AuditEntry avecAuteur(String? nom) => AuditEntry(
    id: id,
    action: action,
    tableName: tableName,
    recordId: recordId,
    createdAt: createdAt,
    actorId: actorId,
    auteur: nom,
    meta: meta,
  );

  factory AuditEntry.fromJson(Map<String, dynamic> json) {
    return AuditEntry(
      id: json['id'] as int,
      action: json['action'] as String,
      tableName: json['table_name'] as String,
      recordId: json['record_id'] as String?,
      actorId: json['actor_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      meta: json['meta'] is Map
          ? Map<String, dynamic>.from(json['meta'] as Map)
          : null,
    );
  }
}

class CreateUserRequest {
  const CreateUserRequest({
    required this.email,
    required this.password,
    required this.nom,
    required this.prenom,
    required this.role,
    required this.divisionId,
    this.promotionId,
    this.grade,
    this.apprenantType,
    this.matricule,
    this.classeId,
  });

  final String email;
  final String password;
  final String nom;
  final String prenom;
  final AppRole role;
  final String? divisionId;

  /// La promotion commandée — n'a de sens que pour un Commandant de
  /// Brigade, dont c'est toute la portée.
  final String? promotionId;

  final String? grade;
  final String? apprenantType;
  final String? matricule;
  final String? classeId;

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'password': password,
      'nom': nom,
      'prenom': prenom,
      'role': role.dbValue,
      'divisionId': divisionId,
      if (role == AppRole.commandantBrigade) 'promotionId': promotionId,
      'grade': grade,
      if (role == AppRole.eleveStagiaire)
        'apprenant': {
          'type': apprenantType,
          'matricule': matricule,
          'classeId': classeId,
        },
    };
  }
}

class AdminRepository {
  Future<List<Profile>> fetchProfiles() async {
    final rows = await socle
        .from('profiles')
        .select()
        .order('nom', ascending: true);
    return rows.map(Profile.fromJson).toList();
  }

  /// Le journal, avec le nom de l'auteur de chaque acte.
  ///
  /// L'auteur est résolu ici plutôt que par une jointure : `audit_log`
  /// n'a pas de clé étrangère vers `profiles`, et c'est délibéré — le
  /// journal doit survivre à la suppression du compte qui a agi. On
  /// rapproche donc les deux listes en mémoire, et un compte disparu laisse
  /// simplement une entrée sans nom.
  Future<List<AuditEntry>> fetchAuditLog({int limit = 100}) async {
    final rows = await socle
        .from('audit_log')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);
    final entrees = rows.map(AuditEntry.fromJson).toList();

    final profils = await fetchProfiles();
    final nomParId = {for (final p in profils) p.id: p.identiteComplete};

    return [
      for (final entree in entrees) entree.avecAuteur(nomParId[entree.actorId]),
    ];
  }

  Future<void> createUser(CreateUserRequest request) async {
    final response = await supabase.functions.invoke(
      'create-user',
      body: request.toJson(),
    );
    if (response.status != 200) {
      final data = response.data;
      final message = data is Map && data['error'] != null
          ? data['error'].toString()
          : 'Création impossible';
      throw Exception(message);
    }
  }

  Future<void> updateProfile({
    required String id,
    required String nom,
    required String prenom,
    required AppRole role,
    required String? divisionId,
    String? promotionId,
    String? grade,
  }) {
    return socle
        .from('profiles')
        .update({
          'nom': nom,
          'prenom': prenom,
          'role': role.dbValue,
          'division_id': divisionId,
          // Changer de rôle détache la promotion : seul un Commandant de
          // Brigade en commande une.
          'promotion_id': role == AppRole.commandantBrigade
              ? promotionId
              : null,
          'grade': grade,
        })
        .eq('id', id);
  }

  Future<void> deleteUser(String userId) async {
    final response = await supabase.functions.invoke(
      'delete-user',
      body: {'userId': userId},
    );
    if (response.status != 200) {
      final data = response.data;
      final message = data is Map && data['error'] != null
          ? data['error'].toString()
          : 'Suppression impossible';
      throw Exception(message);
    }
  }
}
