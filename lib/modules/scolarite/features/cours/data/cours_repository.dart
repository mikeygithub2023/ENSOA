import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;

import 'package:sig_ensoa/core/reprise.dart';
import 'package:sig_ensoa/core/session_fraiche.dart';
import 'package:sig_ensoa/core/supabase_client.dart';
import '../../../models/cours.dart';

final _dateFmt = DateFormat('yyyy-MM-dd');

const _bucket = 'cours-documents';

/// Données saisies pour un cours, un exercice ou un devoir. [fichier] et
/// [fichierNom] ne sont renseignés que si l'utilisateur joint un document ;
/// [supprimerFichier] retire celui déjà en place.
class CoursDraft {
  const CoursDraft({
    required this.divisionId,
    required this.classeId,
    required this.type,
    required this.titre,
    this.matiereId,
    this.coursId,
    this.description,
    this.dateSeance,
    this.dateRemise,
    this.dureeMinutes,
    this.fichier,
    this.fichierNom,
    this.supprimerFichier = false,
  });

  final String divisionId;
  final String classeId;
  final TypeRessource type;
  final String titre;
  final String? matiereId;
  final String? coursId;
  final String? description;
  final DateTime? dateSeance;
  final DateTime? dateRemise;

  /// Temps imparti, en minutes — seulement pour un devoir.
  final int? dureeMinutes;

  final Uint8List? fichier;
  final String? fichierNom;
  final bool supprimerFichier;

  Map<String, dynamic> toJson() {
    return {
      'division_id': divisionId,
      'classe_id': classeId,
      'type': type.value,
      'titre': titre,
      'matiere_id': matiereId,
      // Un cours ne se rattache à rien : la base le refuserait.
      'cours_id': type == TypeRessource.cours ? null : coursId,
      'description': description,
      'date_seance': dateSeance == null ? null : _dateFmt.format(dateSeance!),
      'date_remise': dateRemise == null ? null : _dateFmt.format(dateRemise!),
      // Seul un devoir se compose contre la montre.
      'duree_minutes': type == TypeRessource.devoir ? dureeMinutes : null,
    };
  }
}

class CoursRepository {
  Future<List<Cours>> fetchByClasse(String classeId) async {
    final rows = await scolarite
        .from('cours')
        .select()
        .eq('classe_id', classeId)
        .order('date_seance', ascending: false)
        .order('created_at', ascending: false);
    return rows.map(Cours.fromJson).toList();
  }

  /// L'identifiant est engendré ici plutôt que demandé au serveur : cela
  /// évite un aller-retour et rend l'insertion rejouable sans risque de
  /// doublon (voir [nouvelIdentifiant]).
  Future<void> createCours(CoursDraft draft) async {
    final id = nouvelIdentifiant();
    await avecReprise(
      () => scolarite.from('cours').insert({...draft.toJson(), 'id': id}),
    );
    await _appliquerFichier(id, draft);
  }

  Future<void> updateCours(String id, CoursDraft draft) async {
    await avecReprise(
      () => scolarite.from('cours').update(draft.toJson()).eq('id', id),
    );
    await _appliquerFichier(id, draft);
  }

  /// Le document est déposé sous l'identifiant de la ressource : un même
  /// cours ne peut donc pas accumuler d'objets orphelins dans le bucket, et
  /// le remplacement écrase l'ancien.
  Future<void> _appliquerFichier(String id, CoursDraft draft) async {
    final fichier = draft.fichier;
    if (fichier != null) {
      final nom = draft.fichierNom ?? 'document';
      final extension = nom.contains('.') ? nom.split('.').last : 'bin';
      final path = '$id.$extension';
      await supabase.storage
          .from(_bucket)
          .uploadBinary(
            path,
            fichier,
            fileOptions: const FileOptions(upsert: true),
          );
      await scolarite
          .from('cours')
          .update({'fichier_path': path, 'fichier_nom': nom})
          .eq('id', id);
    } else if (draft.supprimerFichier) {
      await scolarite
          .from('cours')
          .update({'fichier_path': null, 'fichier_nom': null})
          .eq('id', id);
    }
  }

  /// Octets du document, pour l'enregistrer sur le poste de l'utilisateur.
  Future<Uint8List> telechargerDocument(String fichierPath) {
    return supabase.storage.from(_bucket).download(fichierPath);
  }

  /// Supprime un cours, un exercice ou un devoir.
  ///
  /// La suppression arrive souvent après un long moment passé à lire la
  /// liste : c'est le geste le plus exposé à un jeton expiré. On renouvelle
  /// la session et on rejoue plutôt que de renvoyer « JWT expired ».
  ///
  /// Le `select()` final n'est pas décoratif : une suppression que la RLS
  /// refuse ne lève aucune erreur, et l'écran annoncerait un succès sur une
  /// ligne toujours en place.
  Future<void> deleteCours(String id) async {
    final supprimes = await avecSessionFraiche(
      () => scolarite.from('cours').delete().eq('id', id).select('id'),
    );

    if (supprimes.isEmpty) {
      throw Exception(
        'Rien n\'a été supprimé : vous ne pouvez retirer que ce que vous avez '
        'déposé, ou ce qui relève de votre division.',
      );
    }
  }
}

/// Une question telle qu'elle est saisie dans l'éditeur, avant
/// enregistrement.
class QcmQuestionDraft {
  const QcmQuestionDraft({
    required this.enonce,
    required this.propositions,
    required this.indexesBonnesReponses,
  });

  final String enonce;
  final List<String> propositions;

  /// Index des propositions désignées comme justes — une question peut en
  /// compter plusieurs.
  final Set<int> indexesBonnesReponses;
}

extension QcmRepository on CoursRepository {
  Future<List<QcmQuestion>> fetchQuestions(String devoirId) async {
    final rows = await scolarite
        .from('qcm_questions')
        .select('*, qcm_propositions(*)')
        .eq('devoir_id', devoirId)
        .order('ordre');
    return rows.map(QcmQuestion.fromJson).toList();
  }

  /// Réécrit le QCM en entier plutôt que de rapprocher ligne à ligne
  /// l'ancien et le nouveau : un QCM se compose d'un bloc, les questions se
  /// réordonnent et se suppriment librement dans l'éditeur, et le nombre de
  /// lignes en jeu reste modeste.
  ///
  /// Les propositions suivent leur question (`on delete cascade`).
  Future<void> remplacerQuestions(
    String devoirId,
    List<QcmQuestionDraft> questions,
  ) async {
    await scolarite.from('qcm_questions').delete().eq('devoir_id', devoirId);

    for (var i = 0; i < questions.length; i++) {
      final question = questions[i];
      final questionId = nouvelIdentifiant();
      await avecReprise(
        () => scolarite.from('qcm_questions').insert({
          'id': questionId,
          'devoir_id': devoirId,
          'ordre': i,
          'enonce': question.enonce,
        }),
      );

      await avecReprise(
        () => scolarite.from('qcm_propositions').insert([
          for (var j = 0; j < question.propositions.length; j++)
            {
              'question_id': questionId,
              'ordre': j,
              'texte': question.propositions[j],
              'correcte': question.indexesBonnesReponses.contains(j),
            },
        ]),
      );
    }

    await _pousserAuxEleves(devoirId);
  }

  /// Prévient les téléphones des élèves de la classe/stage.
  ///
  /// La notification dans leur espace est déjà posée par le trigger de la
  /// base (migration 045) : celle-ci n'est que le rappel sur l'écran
  /// verrouillé. Un échec — Firebase non configuré, réseau capricieux — ne
  /// doit donc jamais faire croire à l'instructeur que son QCM n'est pas
  /// enregistré : il l'est, et les élèves le verront en ouvrant leur espace.
  Future<void> _pousserAuxEleves(String devoirId) async {
    try {
      await supabase.functions.invoke(
        'pousser-devoir',
        body: {'devoirId': devoirId},
      );
    } catch (_) {
      // Volontairement silencieux : voir ci-dessus.
    }
  }
}

extension ResultatsRepository on CoursRepository {
  /// Les copies remises pour un devoir. Les policies ne rendent au
  /// demandeur que celles de sa division — le cloisonnement est garanti
  /// côté serveur.
  Future<List<ResultatDevoir>> fetchResultats(String devoirId) async {
    final rows = await scolarite
        .from('qcm_participations')
        .select('apprenant_id, note, bareme, terminee_at, hors_delai')
        .eq('devoir_id', devoirId);
    return rows.map(ResultatDevoir.fromJson).toList();
  }
}

extension PublicationResultats on CoursRepository {
  /// Ouvre ou referme l'accès des élèves à leur note. Un simple drapeau sur
  /// le devoir : la note elle-même ne bouge pas.
  Future<void> publierResultats(String devoirId, {required bool publies}) {
    return avecReprise(
      () => scolarite
          .from('cours')
          .update({'resultats_publies': publies})
          .eq('id', devoirId),
    );
  }
}
