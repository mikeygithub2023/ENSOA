import 'package:intl/intl.dart';

import 'package:sig_ensoa/core/supabase_client.dart';
import '../../../models/depense.dart';

final _dateFmt = DateFormat('yyyy-MM-dd');

/// Le rappel du patient (nom, matricule, grade, date de la consultation)
/// est ramené par jointure en même temps que la dépense : la liste et
/// l'état imprimé s'affichent alors en une seule requête, sans recharger
/// chaque consultation une par une.
const _select =
    '*, consultations_medicales(id, date_souhaitee, '
    'apprenants(nom, prenom, matricule, grade))';

/// Données saisies pour l'enregistrement d'une dépense. [consultationId]
/// est obligatoire pour une dépense de [TypeDepense.consultation] et doit
/// rester nul pour une dépense de service — la base rejette toute autre
/// combinaison (contrainte `depenses_rattachement`).
class DepenseDraft {
  const DepenseDraft({
    required this.dateDepense,
    required this.type,
    required this.categorie,
    required this.libelle,
    required this.montant,
    this.observations,
    this.consultationId,
  });

  final DateTime dateDepense;
  final TypeDepense type;
  final CategorieDepense categorie;
  final String libelle;
  final int montant;
  final String? observations;
  final String? consultationId;

  Map<String, dynamic> toJson() {
    return {
      'date_depense': _dateFmt.format(dateDepense),
      'type': type.value,
      'categorie': categorie.value,
      'libelle': libelle,
      'montant': montant,
      'observations': observations,
      'consultation_id': type == TypeDepense.consultation
          ? consultationId
          : null,
    };
  }
}

class DepensesRepository {
  /// Dépenses engagées entre [debut] et [fin] inclus, les plus récentes
  /// d'abord.
  Future<List<Depense>> fetchBetween({
    required DateTime debut,
    required DateTime fin,
  }) async {
    final rows = await scolarite
        .from('depenses')
        .select(_select)
        .gte('date_depense', _dateFmt.format(debut))
        .lte('date_depense', _dateFmt.format(fin))
        .order('date_depense', ascending: false)
        .order('created_at', ascending: false);
    return rows.map(Depense.fromJson).toList();
  }

  /// Dépenses rattachées à une consultation précise.
  Future<List<Depense>> fetchByConsultation(String consultationId) async {
    final rows = await scolarite
        .from('depenses')
        .select(_select)
        .eq('consultation_id', consultationId)
        .order('date_depense', ascending: false);
    return rows.map(Depense.fromJson).toList();
  }

  Future<void> createDepense(DepenseDraft draft) async {
    await scolarite.from('depenses').insert(draft.toJson());
  }

  Future<void> updateDepense(String id, DepenseDraft draft) async {
    await scolarite.from('depenses').update(draft.toJson()).eq('id', id);
  }

  Future<void> deleteDepense(String id) async {
    await scolarite.from('depenses').delete().eq('id', id);
  }
}
