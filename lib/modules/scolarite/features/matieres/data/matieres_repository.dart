import 'package:sig_ensoa/core/supabase_client.dart';
import '../../../models/matiere.dart';

class MatieresRepository {
  Future<List<Matiere>> fetchCatalogue() async {
    final rows = await scolarite.from('matieres').select();
    final matieres = rows.map(Matiere.fromJson).toList();
    matieres.sort((a, b) => a.nom.toLowerCase().compareTo(b.nom.toLowerCase()));
    return matieres;
  }

  Future<void> createMatiere({required String code, required String nom}) {
    return scolarite.from('matieres').insert({'code': code, 'nom': nom});
  }

  Future<void> updateMatiere({
    required String id,
    required String code,
    required String nom,
  }) {
    return scolarite
        .from('matieres')
        .update({'code': code, 'nom': nom})
        .eq('id', id);
  }

  Future<void> deleteMatiere(String id) {
    return scolarite.from('matieres').delete().eq('id', id);
  }

  Future<List<MatiereModule>> fetchModules() async {
    final rows = await scolarite
        .from('matiere_modules')
        .select()
        .order('created_at', ascending: true);
    return rows.map(MatiereModule.fromJson).toList();
  }

  Future<void> createModule({
    required String matiereId,
    required String divisionId,
    required String classeId,
    required double coefficient,
  }) {
    return scolarite.from('matiere_modules').insert({
      'matiere_id': matiereId,
      'division_id': divisionId,
      'classe_id': classeId,
      'coefficient': coefficient,
    });
  }

  Future<void> updateModuleCoefficient({
    required String id,
    required double coefficient,
  }) {
    return scolarite
        .from('matiere_modules')
        .update({'coefficient': coefficient})
        .eq('id', id);
  }

  Future<void> deleteModule(String id) {
    return scolarite.from('matiere_modules').delete().eq('id', id);
  }
}
