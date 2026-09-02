import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sig_ensoa/core/roles.dart';
import 'package:sig_ensoa/modules/logistique/compat.dart';
import 'package:sig_ensoa/core/supabase_client.dart';
import 'package:sig_ensoa/core/chargement.dart';
import '../models/notification_item.dart';
import '../models/oa.dart';
import 'misc_providers.dart';

StatutActivite _statutActiviteFromDb(String v) {
  switch (v) {
    case 'en_cours':
      return StatutActivite.enCours;
    case 'terminee':
      return StatutActivite.terminee;
    case 'annulee':
      return StatutActivite.annulee;
    default:
      return StatutActivite.planifiee;
  }
}

String _statutActiviteToDb(StatutActivite s) {
  switch (s) {
    case StatutActivite.planifiee:
      return 'planifiee';
    case StatutActivite.enCours:
      return 'en_cours';
    case StatutActivite.terminee:
      return 'terminee';
    case StatutActivite.annulee:
      return 'annulee';
  }
}

Activite _activiteFromRow(Map<String, dynamic> row) => Activite(
  id: row['id'].toString(),
  titre: row['titre'] as String,
  description: row['description'] as String?,
  dateActivite: DateTime.parse(row['date_activite'] as String),
  lieu: row['lieu'] as String?,
  statut: _statutActiviteFromDb(row['statut'] as String),
  creePar: row['cree_par'] as String,
  creeLe: DateTime.parse(row['cree_le'] as String),
);

class ActivitesNotifier extends Notifier<List<Activite>> {
  @override
  List<Activite> build() {
    Future.microtask(refresh);
    return [];
  }

  Future<void> refresh() async {
    final rows = await logistique
        .from('activite')
        .select()
        .order('date_activite', ascending: false);
    state = (rows as List)
        .map((r) => _activiteFromRow(r as Map<String, dynamic>))
        .toList();
    ref.read(chargementProvider.notifier).marquerCharge('activites');
  }

  Future<void> creer({
    required String titre,
    String? description,
    required DateTime dateActivite,
    String? lieu,
  }) async {
    final user = ref.read(sessionProvider)!.user;
    await logistique.from('activite').insert({
      'titre': titre,
      'description': description,
      'date_activite': dateActivite.toIso8601String(),
      'lieu': lieu,
      'cree_par': user.id,
    });
    await refresh();
  }

  Future<void> changerStatut(String id, StatutActivite statut) async {
    await logistique
        .from('activite')
        .update({'statut': _statutActiviteToDb(statut)})
        .eq('id', int.parse(id));
    await refresh();
  }
}

final activitesProvider = NotifierProvider<ActivitesNotifier, List<Activite>>(
  ActivitesNotifier.new,
);

ActeurTache _acteurFromDb(String v) {
  switch (v) {
    case 'garage':
      return ActeurTache.garage;
    case 'armurerie':
      return ActeurTache.armurerie;
    case 'sante':
      return ActeurTache.sante;
    default:
      return ActeurTache.st;
  }
}

StatutTache _statutTacheFromDb(String v) {
  switch (v) {
    case 'terminee':
      return StatutTache.terminee;
    case 'validee':
      return StatutTache.validee;
    case 'annulee':
      return StatutTache.annulee;
    default:
      return StatutTache.aFaire;
  }
}

TacheActivite _tacheFromRow(Map<String, dynamic> row) => TacheActivite(
  id: row['id'].toString(),
  activiteId: row['activite_id'].toString(),
  acteur: _acteurFromDb(row['acteur'] as String),
  description: row['description'] as String,
  dateLimite: row['date_limite'] != null
      ? DateTime.parse(row['date_limite'] as String)
      : null,
  statut: _statutTacheFromDb(row['statut'] as String),
  termineePar: row['terminee_par'] as String?,
  termineeLe: row['terminee_le'] != null
      ? DateTime.parse(row['terminee_le'] as String)
      : null,
  valideeLe: row['validee_le'] != null
      ? DateTime.parse(row['validee_le'] as String)
      : null,
  commentaire: row['commentaire'] as String?,
);

class TachesNotifier extends Notifier<List<TacheActivite>> {
  @override
  List<TacheActivite> build() {
    Future.microtask(refresh);
    return [];
  }

  Future<void> refresh() async {
    final rows = await logistique
        .from('tache_activite')
        .select()
        .order('date_limite');
    state = (rows as List)
        .map((r) => _tacheFromRow(r as Map<String, dynamic>))
        .toList();
    ref.read(chargementProvider.notifier).marquerCharge('taches');
  }

  Future<void> assigner({
    required String activiteId,
    required ActeurTache acteur,
    required String description,
    DateTime? dateLimite,
    required String titreActivite,
  }) async {
    await logistique.from('tache_activite').insert({
      'activite_id': int.parse(activiteId),
      'acteur': acteur.name,
      'description': description,
      'date_limite': dateLimite?.toIso8601String(),
    });
    await ref
        .read(notificationsProvider.notifier)
        .creer(
          categorie: NotificationCategory.activite,
          titre: 'Nouvelle tâche assignée',
          message: '$titreActivite — $description',
          roleCible: acteur.role,
        );
    await refresh();
  }

  /// Corrige une tâche mal libellée, mal adressée ou mal datée. Réservé à
  /// l'officier adjoint, comme l'assignation : la RLS le vérifie.
  Future<void> modifier({
    required String id,
    required ActeurTache acteur,
    required String description,
    DateTime? dateLimite,
  }) async {
    await logistique
        .from('tache_activite')
        .update({
          'acteur': acteur.name,
          'description': description,
          'date_limite': dateLimite?.toIso8601String(),
        })
        .eq('id', int.parse(id));
    await refresh();
  }

  /// Retire une tâche assignée par erreur. Une tâche déjà faite se valide,
  /// elle ne s'efface pas : c'est la trace du travail accompli.
  Future<void> supprimer(String id) async {
    await logistique.from('tache_activite').delete().eq('id', int.parse(id));
    await refresh();
  }

  Future<void> marquerTerminee(String id, {String? commentaire}) async {
    final user = ref.read(sessionProvider)!.user;
    final tache = state.firstWhere((t) => t.id == id);
    await logistique
        .from('tache_activite')
        .update({
          'statut': 'terminee',
          'terminee_par': user.id,
          'terminee_le': DateTime.now().toIso8601String(),
          'commentaire': commentaire,
        })
        .eq('id', int.parse(id));
    await ref
        .read(notificationsProvider.notifier)
        .creer(
          categorie: NotificationCategory.activite,
          titre: 'Tâche terminée — à valider',
          message: '${tache.description} (${tache.acteur.label})',
          roleCible: RoleLogistique.officierAdjoint,
        );
    await refresh();
  }

  Future<void> valider(String id) async {
    final tache = state.firstWhere((t) => t.id == id);
    await logistique
        .from('tache_activite')
        .update({
          'statut': 'validee',
          'validee_le': DateTime.now().toIso8601String(),
        })
        .eq('id', int.parse(id));
    await ref
        .read(notificationsProvider.notifier)
        .creer(
          categorie: NotificationCategory.activite,
          titre: 'Tâche validée',
          message: tache.description,
          roleCible: tache.acteur.role,
        );
    await refresh();
  }
}

final tachesProvider = NotifierProvider<TachesNotifier, List<TacheActivite>>(
  TachesNotifier.new,
);

final tachesEnAttenteValidationProvider = Provider<List<TacheActivite>>(
  (ref) => ref
      .watch(tachesProvider)
      .where((t) => t.statut == StatutTache.terminee)
      .toList(),
);

/// Tâches assignées à l'acteur correspondant au rôle actuellement connecté —
/// null (donc liste vide) si ce rôle n'a pas d'acteur (ex. soutien pétrolier).
final mesTachesProvider = Provider<List<TacheActivite>>((ref) {
  final role = ref.watch(sessionProvider)?.user.role;
  if (role == null) return [];
  final acteur = acteurPourRole(role);
  if (acteur == null) return [];
  return ref.watch(tachesProvider).where((t) => t.acteur == acteur).toList();
});
