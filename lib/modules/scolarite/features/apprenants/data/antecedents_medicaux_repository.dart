import 'package:sig_ensoa/core/supabase_client.dart';
import '../../../models/antecedents_medicaux.dart';

class AntecedentsMedicauxRepository {
  Future<AntecedentsMedicaux?> fetchByApprenant(String apprenantId) async {
    final row = await scolarite
        .from('antecedents_medicaux')
        .select()
        .eq('apprenant_id', apprenantId)
        .maybeSingle();
    return row == null ? null : AntecedentsMedicaux.fromJson(row);
  }

  /// Crée ou met à jour la fiche d'antécédents de l'apprenant — une seule
  /// ligne par apprenant (voir la contrainte unique côté base).
  Future<void> upsert({
    required String apprenantId,
    String? allergies,
    String? antecedentsPathologiques,
    String? antecedentsChirurgicaux,
    String? antecedentsFamiliaux,
    String? traitementEnCours,
    String? observations,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    await scolarite.from('antecedents_medicaux').upsert({
      'apprenant_id': apprenantId,
      'allergies': allergies,
      'antecedents_pathologiques': antecedentsPathologiques,
      'antecedents_chirurgicaux': antecedentsChirurgicaux,
      'antecedents_familiaux': antecedentsFamiliaux,
      'traitement_en_cours': traitementEnCours,
      'observations': observations,
      'updated_at': DateTime.now().toIso8601String(),
      'updated_by': userId,
    }, onConflict: 'apprenant_id');
  }
}
