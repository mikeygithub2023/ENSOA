import 'package:intl/intl.dart';

import 'package:sig_ensoa/core/supabase_client.dart';
import '../../../models/mouvement_personnel.dart';

/// Ce qu'on saisit en inscrivant un mouvement. Le reste — l'auteur, et ce
/// qui était vrai avant — la base le relève elle-même.
class MouvementDraft {
  const MouvementDraft({
    required this.apprenantId,
    required this.nature,
    required this.dateEffet,
    this.serviceApres,
    this.uniteAccueil,
    this.reference,
    this.observation,
  });

  final String apprenantId;
  final NatureMouvement nature;
  final DateTime dateEffet;
  final String? serviceApres;
  final String? uniteAccueil;
  final String? reference;
  final String? observation;

  Map<String, dynamic> toJson() => {
    'apprenant_id': apprenantId,
    'nature': nature.valeur,
    'date_effet': DateFormat('yyyy-MM-dd').format(dateEffet),
    'service_apres': nature.demandeService ? serviceApres : null,
    'unite_accueil': nature.demandeUnite ? uniteAccueil : null,
    'reference': reference,
    'observation': observation,
  };
}

class MouvementsRepository {
  static const _table = 'mouvements_personnel';

  /// Le journal d'un militaire, le plus récent d'abord.
  Future<List<MouvementPersonnel>> fetchByApprenant(String apprenantId) async {
    final rows = await scolarite
        .from(_table)
        .select()
        .eq('apprenant_id', apprenantId)
        .order('date_effet', ascending: false)
        .order('created_at', ascending: false);
    return rows.map(MouvementPersonnel.fromJson).toList();
  }

  /// Inscrit le mouvement ; la base le porte sur la fiche.
  Future<void> inscrire(MouvementDraft draft) async {
    await scolarite.from(_table).insert(draft.toJson());
  }
}
