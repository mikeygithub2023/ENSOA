import 'package:sig_ensoa/core/supabase_client.dart';
import '../../../models/sous_module.dart';

/// Données saisies pour un sous-module. [nature] reste `note` pour un
/// sous-module ordinaire ; le module Sport crée des `sport`, dont la note
/// vient d'une performance et d'un barème (voir la migration 052).
class SousModuleDraft {
  const SousModuleDraft({
    required this.moduleId,
    required this.nom,
    required this.coefficient,
    this.nature = NatureSousModule.note,
    this.ordre = 0,
  });

  final String moduleId;
  final String nom;
  final num coefficient;
  final NatureSousModule nature;
  final int ordre;

  Map<String, dynamic> toJson() => {
    'module_id': moduleId,
    'nom': nom,
    'coefficient': coefficient,
    'nature': nature.value,
    'ordre': ordre,
  };
}

class SousModulesRepository {
  Future<List<SousModule>> fetchByModule(String moduleId) async {
    final rows = await scolarite
        .from('sous_modules')
        .select()
        .eq('module_id', moduleId)
        .order('ordre')
        .order('nom');
    return rows.map(SousModule.fromJson).toList();
  }

  /// Tous les sous-modules des modules d'une phase/stage — une seule requête
  /// via la jointure sur `controles`, pour recomposer les notes de module
  /// dans les statistiques et les bulletins.
  Future<List<SousModule>> fetchByClasse(String classeId) async {
    final rows = await scolarite
        .from('sous_modules')
        .select('*, controles!inner(classe_id)')
        .eq('controles.classe_id', classeId);
    return rows.map(SousModule.fromJson).toList();
  }

  Future<void> createSousModule(SousModuleDraft draft) async {
    await scolarite.from('sous_modules').insert(draft.toJson());
  }

  Future<void> updateSousModule({
    required String sousModuleId,
    required String nom,
    required num coefficient,
  }) async {
    await scolarite
        .from('sous_modules')
        .update({'nom': nom, 'coefficient': coefficient})
        .eq('id', sousModuleId);
  }

  /// Supprimer un sous-module emporte ses notes (cascade en base). Comme
  /// ailleurs, on relit ce qui a réellement été supprimé : une suppression
  /// que la RLS refuse ne lève aucune erreur, elle ne supprime simplement
  /// rien.
  Future<void> deleteSousModule(String sousModuleId) async {
    final supprimes = await scolarite
        .from('sous_modules')
        .delete()
        .eq('id', sousModuleId)
        .select('id');

    if (supprimes.isEmpty) {
      throw Exception(
        'Aucun sous-module n\'a été supprimé : votre rôle ne vous y autorise '
        'pas.',
      );
    }
  }
}
