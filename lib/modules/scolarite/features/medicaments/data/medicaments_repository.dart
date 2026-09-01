import 'package:intl/intl.dart';

import 'package:sig_ensoa/core/supabase_client.dart';
import '../../../models/medicament.dart';

final _dateFmt = DateFormat('yyyy-MM-dd');

class MedicamentsRepository {
  Future<List<Medicament>> fetchAll() async {
    final rows = await scolarite.from('medicaments').select().order('nom');
    return rows.map(Medicament.fromJson).toList();
  }

  Future<void> createMedicament({
    required String nom,
    String? unite,
    required int stock,
    required int seuilAlerte,
    required TypeMedicament type,
    DateTime? datePeremption,
  }) async {
    await scolarite.from('medicaments').insert({
      'nom': nom,
      'unite': unite,
      'stock': stock,
      'seuil_alerte': seuilAlerte,
      'type': type.value,
      'date_peremption': datePeremption == null
          ? null
          : _dateFmt.format(datePeremption),
    });
  }

  Future<void> updateMedicament({
    required String id,
    required String nom,
    String? unite,
    required int seuilAlerte,
    required TypeMedicament type,
    DateTime? datePeremption,
  }) async {
    await scolarite
        .from('medicaments')
        .update({
          'nom': nom,
          'unite': unite,
          'seuil_alerte': seuilAlerte,
          'type': type.value,
          'date_peremption': datePeremption == null
              ? null
              : _dateFmt.format(datePeremption),
        })
        .eq('id', id);
  }

  /// Enregistre un mouvement de stock (réapprovisionnement ou correction) —
  /// le stock du médicament est ajusté automatiquement (trigger côté base),
  /// pas depuis ce client.
  Future<void> ajusterStock(
    String medicamentId, {
    required int delta,
    required String motif,
  }) async {
    if (delta == 0) return;
    await scolarite.from('mouvements_stock').insert({
      'medicament_id': medicamentId,
      'type': delta > 0 ? 'entree' : 'sortie',
      'quantite': delta.abs(),
      'motif': motif,
    });
  }

  Future<List<MouvementStock>> fetchMouvements(String medicamentId) async {
    final rows = await scolarite
        .from('mouvements_stock')
        .select()
        .eq('medicament_id', medicamentId)
        .order('created_at', ascending: false);
    return rows.map(MouvementStock.fromJson).toList();
  }

  /// Consommation nette par médicament sur une période : ce qui a été
  /// réellement dispensé aux apprenants.
  ///
  /// Seuls les mouvements rattachés à une consultation sont retenus —
  /// réapprovisionnements et corrections d'inventaire ne sont pas de la
  /// consommation. Les prescriptions annulées se déduisent d'elles-mêmes :
  /// le journal enregistre leur restitution comme une entrée portant la même
  /// consultation (voir la migration 023), d'où le net sortie - entrée.
  Future<List<ConsommationMedicament>> fetchConsommation({
    required DateTime debut,
    required DateTime fin,
  }) async {
    final rows = await scolarite
        .from('mouvements_stock')
        .select('medicament_id, type, quantite, medicaments(nom, type)')
        .not('consultation_id', 'is', null)
        .gte(
          'created_at',
          DateTime(debut.year, debut.month, debut.day).toIso8601String(),
        )
        .lte(
          'created_at',
          DateTime(fin.year, fin.month, fin.day, 23, 59, 59).toIso8601String(),
        );

    final quantites = <String, int>{};
    final noms = <String, String>{};
    final types = <String, TypeMedicament>{};
    for (final row in rows) {
      final medicamentId = row['medicament_id'] as String;
      final medicament = row['medicaments'] as Map<String, dynamic>?;
      final quantite = row['quantite'] as int;
      final signe =
          mouvementTypeFromString(row['type'] as String) == MouvementType.sortie
          ? 1
          : -1;
      quantites[medicamentId] =
          (quantites[medicamentId] ?? 0) + signe * quantite;
      noms[medicamentId] =
          medicament?['nom'] as String? ?? 'Médicament supprimé';
      types[medicamentId] = typeMedicamentFromString(
        medicament?['type'] as String? ?? 'autre',
      );
    }

    final consommations =
        quantites.entries
            .where((e) => e.value > 0)
            .map(
              (e) => ConsommationMedicament(
                medicamentId: e.key,
                nom: noms[e.key]!,
                type: types[e.key]!,
                quantite: e.value,
              ),
            )
            .toList()
          ..sort((a, b) => b.quantite.compareTo(a.quantite));
    return consommations;
  }

  Future<void> deleteMedicament(String id) async {
    await scolarite.from('medicaments').delete().eq('id', id);
  }
}
