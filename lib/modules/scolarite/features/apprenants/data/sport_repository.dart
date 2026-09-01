import 'package:sig_ensoa/core/supabase_client.dart';
import '../../../models/sous_module.dart';

/// Accès au sport : le catalogue des activités et leurs barèmes d'un côté,
/// les séances d'une phase et les performances de l'autre.
///
/// La note n'est jamais écrite d'ici : la base la calcule depuis le barème
/// de l'activité et la dépose dans `notes` (migrations 055 et 056). Ce
/// dépôt ne fait que la relire pour l'afficher à côté de la performance.
class SportRepository {
  // --- Le catalogue ---------------------------------------------------------

  Future<List<ActiviteSportive>> fetchActivites() async {
    final rows = await scolarite
        .from('activites_sportives')
        .select()
        .order('nom');
    return rows.map(ActiviteSportive.fromJson).toList();
  }

  Future<void> createActivite({
    required String nom,
    required UniteEpreuve unite,
    required SensEpreuve meilleur,
    String? consigne,
  }) async {
    await scolarite.from('activites_sportives').insert({
      'nom': nom,
      'unite': unite.value,
      'meilleur': meilleur.value,
      'consigne': consigne,
    });
  }

  Future<void> updateActivite({
    required String activiteId,
    required String nom,
    required UniteEpreuve unite,
    required SensEpreuve meilleur,
    String? consigne,
  }) async {
    await scolarite
        .from('activites_sportives')
        .update({
          'nom': nom,
          'unite': unite.value,
          'meilleur': meilleur.value,
          'consigne': consigne,
        })
        .eq('id', activiteId);
  }

  /// La base refuse de supprimer une activité encore convoquée par une
  /// séance (`on delete restrict`) : effacer le barème sous les pieds des
  /// notes déjà calculées les rendrait incompréhensibles.
  Future<void> deleteActivite(String activiteId) async {
    final supprimees = await scolarite
        .from('activites_sportives')
        .delete()
        .eq('id', activiteId)
        .select('id');

    if (supprimees.isEmpty) {
      throw Exception(
        'Aucune activité n\'a été supprimée : votre rôle ne vous y autorise '
        'pas.',
      );
    }
  }

  /// Le barème d'une activité, rangé du plus petit au plus grand : c'est
  /// l'ordre dans lequel on le lit sur une feuille de barème, quel que soit
  /// le sens de l'activité.
  Future<List<BaremePalier>> fetchBareme(String activiteId) async {
    final rows = await scolarite
        .from('bareme_paliers')
        .select()
        .eq('activite_id', activiteId)
        .order('sexe')
        .order('performance');
    return rows.map(BaremePalier.fromJson).toList();
  }

  Future<void> ajouterPalier({
    required String activiteId,
    required String sexe,
    required num performance,
    required num note,
  }) async {
    await scolarite.from('bareme_paliers').insert({
      'activite_id': activiteId,
      'sexe': sexe,
      'performance': performance,
      'note': note,
    });
  }

  Future<void> modifierPalier({
    required String palierId,
    required num performance,
    required num note,
  }) async {
    await scolarite
        .from('bareme_paliers')
        .update({'performance': performance, 'note': note})
        .eq('id', palierId);
  }

  Future<void> supprimerPalier(String palierId) async {
    final supprimes = await scolarite
        .from('bareme_paliers')
        .delete()
        .eq('id', palierId)
        .select('id');

    if (supprimes.isEmpty) {
      throw Exception(
        'Aucun palier n\'a été supprimé : votre rôle ne vous y autorise pas.',
      );
    }
  }

  // --- Les séances ----------------------------------------------------------

  /// Les séances du module Sport, chacune avec le sous-module qui la porte.
  /// Les deux vont ensemble : une séance EST un sous-module du module Sport
  /// (voir la migration 056), et c'est par lui que sa note entre dans la
  /// moyenne.
  Future<List<({SousModule sousModule, SeanceSportive seance})>> fetchSeances(
    String moduleSportId,
  ) async {
    final rows = await scolarite
        .from('sous_modules')
        .select('*, seances_sportives!inner(*)')
        .eq('module_id', moduleSportId);

    final seances = [
      for (final row in rows)
        (
          sousModule: SousModule.fromJson(row),
          seance: SeanceSportive.fromJson(
            row['seances_sportives'] as Map<String, dynamic>,
          ),
        ),
    ];
    // La plus récente en tête : c'est celle qu'on vient saisir.
    seances.sort((a, b) => b.seance.dateSeance.compareTo(a.seance.dateSeance));
    return seances;
  }

  /// Crée la séance et le sous-module qui la porte. Le coefficient vaut 1 :
  /// toutes les séances pèsent le même poids dans la note du module Sport.
  Future<void> createSeance({
    required String moduleSportId,
    required String activiteId,
    required String nom,
    required DateTime dateSeance,
  }) async {
    final insere = await scolarite
        .from('sous_modules')
        .insert({
          'module_id': moduleSportId,
          'nom': nom,
          'coefficient': 1,
          'nature': 'sport',
        })
        .select('id')
        .single();

    try {
      await scolarite.from('seances_sportives').insert({
        'sous_module_id': insere['id'],
        'activite_id': activiteId,
        'date_seance': _jour(dateSeance),
      });
    } catch (e) {
      // Un sous-module sans séance ne veut rien dire : plutôt que de le
      // laisser en place, on défait la moitié qui a abouti.
      await scolarite.from('sous_modules').delete().eq('id', insere['id']);
      rethrow;
    }
  }

  Future<void> updateSeance({
    required String sousModuleId,
    required String activiteId,
    required String nom,
    required DateTime dateSeance,
  }) async {
    await scolarite
        .from('sous_modules')
        .update({'nom': nom})
        .eq('id', sousModuleId);
    await scolarite
        .from('seances_sportives')
        .update({'activite_id': activiteId, 'date_seance': _jour(dateSeance)})
        .eq('sous_module_id', sousModuleId);
  }

  /// Supprimer la séance emporte ses performances et ses notes (cascade en
  /// base) — c'est le sous-module qu'on retire, la séance suit.
  Future<void> deleteSeance(String sousModuleId) async {
    final supprimees = await scolarite
        .from('sous_modules')
        .delete()
        .eq('id', sousModuleId)
        .select('id');

    if (supprimees.isEmpty) {
      throw Exception(
        'Aucune séance n\'a été supprimée : votre rôle ne vous y autorise '
        'pas.',
      );
    }
  }

  // --- Les performances -----------------------------------------------------

  /// Les performances d'une séance, chacune accompagnée de la note que le
  /// barème lui a donnée. Les deux vivent dans des tables différentes — la
  /// performance est saisie, la note est calculée — et sont rapprochées ici
  /// par apprenant.
  Future<List<PerformanceSportive>> fetchPerformances(
    String sousModuleId,
  ) async {
    final rows = await scolarite
        .from('performances_sportives')
        .select()
        .eq('sous_module_id', sousModuleId);

    final notes = await scolarite
        .from('notes')
        .select('apprenant_id, note, previous_note, deletion_requested_at')
        .eq('sous_module_id', sousModuleId);
    final noteParApprenant = {
      for (final n in notes) n['apprenant_id'] as String: n,
    };

    return [
      for (final row in rows)
        PerformanceSportive.fromJson({
          ...row,
          ...?noteParApprenant[row['apprenant_id']],
          // La performance garde son propre identifiant : celui de la note
          // ne doit pas le supplanter dans la fusion ci-dessus.
          'id': row['id'],
        }),
    ];
  }

  /// Un non-administrateur ne supprime pas une performance : il en fait la
  /// demande, portée par la note qu'elle a produite — le même mécanisme
  /// que pour une note saisie, et donc la même notification aux
  /// administrateurs (trigger côté base).
  Future<void> demanderSuppressionPerformance({
    required String sousModuleId,
    required String apprenantId,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    final misesAJour = await scolarite
        .from('notes')
        .update({
          'deletion_requested_at': DateTime.now().toIso8601String(),
          'deletion_requested_by': userId,
        })
        .eq('sous_module_id', sousModuleId)
        .eq('apprenant_id', apprenantId)
        .select('id');

    if (misesAJour.isEmpty) {
      throw Exception(
        'La demande n\'a pas pu être enregistrée : cette performance n\'a '
        'pas encore de note (barème absent pour ce sexe).',
      );
    }
  }

  /// L'administrateur rejette la demande : la performance est conservée,
  /// la demande annulée.
  Future<void> annulerDemandeSuppression({
    required String sousModuleId,
    required String apprenantId,
  }) async {
    await scolarite
        .from('notes')
        .update({'deletion_requested_at': null, 'deletion_requested_by': null})
        .eq('sous_module_id', sousModuleId)
        .eq('apprenant_id', apprenantId);
  }

  /// Une performance par séance et par apprenant : on garde la mesure
  /// retenue, pas un historique de tentatives (voir la migration 056).
  Future<void> enregistrerPerformance({
    required String sousModuleId,
    required String apprenantId,
    required num valeur,
    String? observations,
  }) async {
    await scolarite.from('performances_sportives').upsert({
      'sous_module_id': sousModuleId,
      'apprenant_id': apprenantId,
      'valeur': valeur,
      'observations': observations,
    }, onConflict: 'sous_module_id,apprenant_id');
  }

  Future<void> supprimerPerformance(String performanceId) async {
    final supprimees = await scolarite
        .from('performances_sportives')
        .delete()
        .eq('id', performanceId)
        .select('id');

    if (supprimees.isEmpty) {
      throw Exception(
        'Aucune performance n\'a été supprimée : votre rôle ne vous y '
        'autorise pas.',
      );
    }
  }

  static String _jour(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
