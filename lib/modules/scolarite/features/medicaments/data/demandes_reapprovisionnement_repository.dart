import 'package:intl/intl.dart';

import 'package:sig_ensoa/core/supabase_client.dart';
import '../../../models/demande_reapprovisionnement.dart';

final _dateFmt = DateFormat('yyyy-MM-dd');

/// Les lignes et le rappel du médicament sont ramenés par jointure en même
/// temps que la fiche : la liste et l'impression n'ont alors plus rien à
/// recharger.
const _select =
    '*, demandes_reapprovisionnement_lignes(id, medicament_id, '
    'quantite_demandee, stock_au_moment_de_la_demande, '
    'medicaments(nom, unite, type))';

/// Une ligne saisie dans le formulaire : le médicament coché, la quantité
/// commandée et le stock constaté au moment de la saisie.
class LigneReapprovisionnementDraft {
  const LigneReapprovisionnementDraft({
    required this.medicamentId,
    required this.quantiteDemandee,
    required this.stockActuel,
  });

  final String medicamentId;
  final int quantiteDemandee;
  final int stockActuel;
}

class DemandesReapprovisionnementRepository {
  Future<List<DemandeReapprovisionnement>> fetchAll() async {
    final rows = await scolarite
        .from('demandes_reapprovisionnement')
        .select(_select)
        .order('date_demande', ascending: false)
        .order('created_at', ascending: false);
    return rows.map(DemandeReapprovisionnement.fromJson).toList();
  }

  /// Enregistre la fiche puis ses lignes. L'insertion des lignes est
  /// groupée : une fiche vide n'a pas de sens, et un échec en cours de route
  /// laisserait une demande incomplète.
  Future<String> createDemande({
    required DateTime dateDemande,
    String? observations,
    required List<LigneReapprovisionnementDraft> lignes,
  }) async {
    final demande = await scolarite
        .from('demandes_reapprovisionnement')
        .insert({
          'date_demande': _dateFmt.format(dateDemande),
          'observations': observations,
        })
        .select('id')
        .single();
    final demandeId = demande['id'] as String;

    await scolarite.from('demandes_reapprovisionnement_lignes').insert([
      for (final ligne in lignes)
        {
          'demande_id': demandeId,
          'medicament_id': ligne.medicamentId,
          'quantite_demandee': ligne.quantiteDemandee,
          'stock_au_moment_de_la_demande': ligne.stockActuel,
        },
    ]);
    return demandeId;
  }

  /// Les lignes suivent la fiche (`on delete cascade`).
  Future<void> deleteDemande(String id) async {
    await scolarite.from('demandes_reapprovisionnement').delete().eq('id', id);
  }
}
