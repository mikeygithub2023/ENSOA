import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sig_ensoa/core/supabase_client.dart';
import '../../../models/apprenant.dart';

const _photoBucket = 'apprenant-photos';

/// Données saisies pour l'enregistrement d'un élève/stagiaire — reprend les
/// rubriques de la fiche signalétique (DFS). Tous les champs hors identité
/// de base et affectation sont facultatifs.
class ApprenantDraft {
  const ApprenantDraft({
    required this.divisionId,
    required this.classeId,
    required this.type,
    required this.nom,
    required this.prenom,
    this.matricule,
    this.grade,
    this.sexe,
    this.statut = ApprenantStatut.actif,
    this.telephone,
    this.ethnie,
    this.dateNaissance,
    this.lieuNaissance,
    this.situationMatrimoniale,
    this.nombreEnfants,
    this.nomPere,
    this.nomMere,
    this.contact,
    this.email,
    this.urgenceNom,
    this.urgenceLien,
    this.urgenceContact,
    this.tailleCm,
    this.poidsKg,
    this.groupeSanguin,
    this.qualification,
    this.permisConduire,
    this.diplomes = const [],
    this.photoBytes,
    this.photoFileName,
    this.removePhoto = false,
  });

  final String divisionId;
  final String classeId;
  final String type;
  final String nom;
  final String prenom;
  final String? matricule;
  final String? grade;

  /// « M » ou « F ». Décide du barème appliqué aux épreuves sportives.
  final String? sexe;

  /// Actif, radié, diplômé ou suspendu. Il vaut « actif » à
  /// l'enregistrement et ne se reprend qu'en modification : on n'inscrit
  /// pas quelqu'un déjà radié.
  final ApprenantStatut statut;

  final String? telephone;
  final String? ethnie;
  final DateTime? dateNaissance;
  final String? lieuNaissance;
  final String? situationMatrimoniale;
  final int? nombreEnfants;
  final String? nomPere;
  final String? nomMere;
  final String? contact;
  final String? email;
  final String? urgenceNom;
  final String? urgenceLien;
  final String? urgenceContact;
  final num? tailleCm;
  final num? poidsKg;
  final String? groupeSanguin;
  final String? qualification;
  final String? permisConduire;
  final List<String> diplomes;

  /// Photo choisie mais pas encore envoyée — présente uniquement le temps
  /// de l'enregistrement.
  final Uint8List? photoBytes;
  final String? photoFileName;

  /// Demande explicite de suppression de la photo existante, quand aucune
  /// nouvelle photo n'est fournie (édition uniquement).
  final bool removePhoto;

  Map<String, dynamic> toInsertJson() {
    return {
      'division_id': divisionId,
      'classe_id': classeId,
      'type': type,
      'nom': nom,
      'prenom': prenom,
      'statut': statut.name,
      'matricule': matricule,
      'grade': grade,
      'sexe': sexe,
      'telephone': telephone,
      'ethnie': ethnie,
      'date_naissance': dateNaissance == null
          ? null
          : DateFormat('yyyy-MM-dd').format(dateNaissance!),
      'lieu_naissance': lieuNaissance,
      'situation_matrimoniale': situationMatrimoniale,
      'nombre_enfants': nombreEnfants,
      'nom_pere': nomPere,
      'nom_mere': nomMere,
      'contact': contact,
      'email': email,
      'urgence_nom': urgenceNom,
      'urgence_lien': urgenceLien,
      'urgence_contact': urgenceContact,
      'taille_cm': tailleCm,
      'poids_kg': poidsKg,
      'groupe_sanguin': groupeSanguin,
      'qualification': qualification,
      'permis_conduire': permisConduire,
    };
  }
}

/// Résultat d'un import en masse : nombre de lignes effectivement
/// enregistrées, et message d'erreur par ligne en échec (le reste continue).
class ImportResult {
  const ImportResult({required this.inserted, required this.failed});

  final int inserted;
  final List<String> failed;
}

class ApprenantsRepository {
  Future<List<Apprenant>> fetchAll() async {
    final rows = await scolarite
        .from('apprenants')
        .select()
        .order('nom', ascending: true);
    return rows.map(Apprenant.fromJson).toList();
  }

  /// Apprenants déjà enregistrés dans une classe/stage donné(e) — utilisé
  /// pour détecter les doublons (nom/prénom/date de naissance) avant un
  /// enregistrement individuel ou un import en masse.
  Future<List<Apprenant>> fetchByClasse(String classeId) async {
    final rows = await scolarite
        .from('apprenants')
        .select()
        .eq('classe_id', classeId);
    return rows.map(Apprenant.fromJson).toList();
  }

  /// Tous les apprenants d'une promotion, quelle que soit la phase sous
  /// laquelle ils ont été enregistrés.
  ///
  /// Un élève entre dans une promotion, pas dans une phase : il suit toutes
  /// les phases de sa promotion. L'effectif d'une phase est donc celui de
  /// sa promotion entière — sans quoi une note saisie en deuxième phase ne
  /// pourrait concerner que ceux enregistrés sous elle, et la moyenne du
  /// bulletin, qui couvre toutes les phases, serait fausse.
  Future<List<Apprenant>> fetchByPromotion(String promotionId) async {
    final rows = await scolarite
        .from('apprenants')
        .select('*, classes!inner(promotion_id)')
        .eq('classes.promotion_id', promotionId);
    return rows.map(Apprenant.fromJson).toList();
  }

  /// Tous les apprenants d'une division, toutes phases et stages confondus —
  /// utilisé pour les onglets (Permissions, Absences, Consultations
  /// médicales...) affichés sous "Toutes phases / stages".
  Future<List<Apprenant>> fetchByDivision(String divisionId) async {
    final rows = await scolarite
        .from('apprenants')
        .select()
        .eq('division_id', divisionId);
    return rows.map(Apprenant.fromJson).toList();
  }

  Future<Apprenant?> fetchByProfileId(String profileId) async {
    final row = await scolarite
        .from('apprenants')
        .select()
        .eq('profile_id', profileId)
        .maybeSingle();
    if (row == null) return null;
    return Apprenant.fromJson(row);
  }

  Future<Apprenant?> fetchById(String id) async {
    final row = await scolarite
        .from('apprenants')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return Apprenant.fromJson(row);
  }

  Future<List<String>> fetchDiplomes(String apprenantId) async {
    final rows = await scolarite
        .from('apprenant_diplomes')
        .select('diplomes(nom)')
        .eq('apprenant_id', apprenantId);
    return [
      for (final row in rows)
        if (row['diplomes'] != null)
          (row['diplomes'] as Map<String, dynamic>)['nom'] as String,
    ]..sort();
  }

  Future<void> createApprenant(ApprenantDraft draft) async {
    final inserted = await scolarite
        .from('apprenants')
        .insert(draft.toInsertJson())
        .select('id')
        .single();
    final apprenantId = inserted['id'] as String;
    await _applyPhoto(apprenantId, draft);
    await _replaceDiplomes(apprenantId, draft.diplomes);
  }

  Future<void> updateApprenant(String apprenantId, ApprenantDraft draft) async {
    await scolarite
        .from('apprenants')
        .update(draft.toInsertJson())
        .eq('id', apprenantId);
    await _applyPhoto(apprenantId, draft);
    await _replaceDiplomes(apprenantId, draft.diplomes);
  }

  /// Suppression directe — réservée à l'administrateur par la RLS. Sert
  /// aussi à confirmer une demande de suppression en attente.
  ///
  /// Le `select()` final n'est pas décoratif : sans lui, une suppression
  /// que la RLS refuse ne lève aucune erreur. PostgREST répond « rien
  /// supprimé » et l'application annonçait la suppression d'une fiche
  /// toujours en place. On lit donc ce qui a réellement été supprimé, et on
  /// le dit quand rien ne l'a été.
  Future<void> deleteApprenant(String apprenantId) async {
    // Le compte de connexion part avec la fiche. Il vit dans `auth.users`,
    // hors d'atteinte d'une clé étrangère : aucune cascade ne peut le
    // retirer, il faut le demander. Sans cela, supprimer un élève laissait
    // derrière lui un compte capable de se connecter à un espace vide.
    //
    // On ferme le compte AVANT de supprimer la fiche : c'est elle qui porte
    // le lien vers le compte. Dans l'autre ordre, une erreur en cours de
    // route laisserait un compte que plus rien ne désigne.
    await _fermerEspaceEleve(apprenantId);

    final supprimes = await scolarite
        .from('apprenants')
        .delete()
        .eq('id', apprenantId)
        .select('id');

    if (supprimes.isEmpty) {
      throw Exception(
        'Aucune fiche n\'a été supprimée : votre rôle ne vous y autorise pas. '
        'Seul l\'administrateur supprime un apprenant — les autres en font la '
        'demande, qui lui est notifiée.',
      );
    }
  }

  /// Ferme l'espace élève d'un apprenant s'il en a un, sans bruit s'il n'en
  /// a pas — un stagiaire ou un élève dont le compte n'a jamais été ouvert
  /// se supprime aussi bien.
  ///
  /// L'échec, lui, n'est pas silencieux : un compte qui survit à sa fiche
  /// resterait capable de se connecter, et personne ne le verrait plus
  /// nulle part.
  Future<void> _fermerEspaceEleve(String apprenantId) async {
    final fiche = await scolarite
        .from('apprenants')
        .select('profile_id')
        .eq('id', apprenantId)
        .maybeSingle();
    if (fiche == null || fiche['profile_id'] == null) return;

    final reponse = await supabase.functions.invoke(
      'espaces-eleves',
      body: {
        'action': 'supprimer',
        'apprenantIds': [apprenantId],
      },
    );
    if (reponse.status != 200) {
      final data = reponse.data;
      final message = data is Map && data['error'] != null
          ? data['error'].toString()
          : 'Fermeture du compte impossible';
      throw Exception(
        'La fiche n\'a pas été supprimée : son compte de connexion n\'a pas '
        'pu être fermé ($message). Le supprimer sans fermer le compte '
        'laisserait un accès sans titulaire.',
      );
    }
  }

  /// Un non-administrateur ne peut pas supprimer un apprenant (RLS) : il ne
  /// fait que marquer sa fiche "Suppression demandée", ce qui déclenche une
  /// notification à tous les administrateurs (trigger côté base).
  Future<void> requestApprenantDeletion(String apprenantId) async {
    final userId = supabase.auth.currentUser?.id;
    await scolarite
        .from('apprenants')
        .update({
          'deletion_requested_at': DateTime.now().toIso8601String(),
          'deletion_requested_by': userId,
        })
        .eq('id', apprenantId);
  }

  /// Annule une demande de suppression en attente sans supprimer la fiche.
  Future<void> rejectApprenantDeletion(String apprenantId) async {
    await scolarite
        .from('apprenants')
        .update({'deletion_requested_at': null, 'deletion_requested_by': null})
        .eq('id', apprenantId);
    await socle.from('notifications').delete().eq('apprenant_id', apprenantId);
  }

  /// Enregistre chaque brouillon indépendamment : une ligne en échec (ex.
  /// matricule déjà pris) n'empêche pas les suivantes d'être importées.
  Future<ImportResult> importApprenants(List<ApprenantDraft> drafts) async {
    var inserted = 0;
    final failed = <String>[];
    for (final draft in drafts) {
      try {
        await createApprenant(draft);
        inserted++;
      } catch (e) {
        final label = (draft.matricule?.isNotEmpty ?? false)
            ? draft.matricule!
            : '${draft.nom} ${draft.prenom}';
        failed.add('$label : $e');
      }
    }
    return ImportResult(inserted: inserted, failed: failed);
  }

  Future<void> _applyPhoto(String apprenantId, ApprenantDraft draft) async {
    final bytes = draft.photoBytes;
    final fileName = draft.photoFileName;
    if (bytes != null && fileName != null) {
      final ext = fileName.contains('.') ? fileName.split('.').last : 'jpg';
      final path = '$apprenantId.$ext';
      await supabase.storage
          .from(_photoBucket)
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );
      await scolarite
          .from('apprenants')
          .update({'photo_path': path})
          .eq('id', apprenantId);
    } else if (draft.removePhoto) {
      await scolarite
          .from('apprenants')
          .update({'photo_path': null})
          .eq('id', apprenantId);
    }
  }

  /// URL signée temporaire (1h) pour afficher une photo — le bucket est
  /// privé, pas d'URL publique directe.
  Future<String> getPhotoSignedUrl(String photoPath) {
    return supabase.storage.from(_photoBucket).createSignedUrl(photoPath, 3600);
  }

  /// Télécharge les octets d'une photo — utilisé pour l'incruster dans un
  /// PDF (contrairement à [getPhotoSignedUrl], qui sert à l'affichage
  /// à l'écran via une URL).
  Future<Uint8List> downloadPhoto(String photoPath) {
    return supabase.storage.from(_photoBucket).download(photoPath);
  }

  Future<void> _replaceDiplomes(
    String apprenantId,
    List<String> diplomeNames,
  ) async {
    await scolarite
        .from('apprenant_diplomes')
        .delete()
        .eq('apprenant_id', apprenantId);

    final names = diplomeNames
        .map((d) => d.trim())
        .where((d) => d.isNotEmpty)
        .toSet();
    if (names.isEmpty) return;

    // Un ensemble, pas une liste : deux libellés qui ne diffèrent que par la
    // casse — « BAC » et « Bac », que rien n'empêche de coexister au
    // catalogue, dont l'unicité est sensible à la casse — désignent la même
    // ligne. Les insérer deux fois violerait l'unicité (apprenant, diplôme).
    final ids = <String>{};
    for (final name in names) {
      // `.limit(1)` avant `.maybeSingle()` : sans lui, un catalogue portant
      // ces deux orthographes rendait deux lignes, et `maybeSingle` levait
      // une erreur au lieu de choisir. L'enregistrement de l'élève échouait
      // alors tout entier, pour un doublon dont personne n'était responsable.
      // `%` et `_` sont des jokers pour `ilike` : un diplôme nommé
      // « BAC_TECHNIQUE » irait chercher n'importe quel caractère à la place
      // du souligné, et pourrait retrouver une autre ligne — ou n'en
      // retrouver aucune et créer un doublon. On les échappe.
      final motif = name
          .replaceAll('\\', r'\\')
          .replaceAll('%', r'\%')
          .replaceAll('_', r'\_');

      final existant = await scolarite
          .from('diplomes')
          .select('id')
          .ilike('nom', motif)
          .limit(1)
          .maybeSingle();
      if (existant != null) {
        ids.add(existant['id'] as String);
        continue;
      }
      final cree = await scolarite
          .from('diplomes')
          .insert({'nom': name})
          .select('id')
          .single();
      ids.add(cree['id'] as String);
    }

    await scolarite.from('apprenant_diplomes').insert([
      for (final diplomeId in ids)
        {'apprenant_id': apprenantId, 'diplome_id': diplomeId},
    ]);
  }
}
