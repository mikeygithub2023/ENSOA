import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/medicament.dart';
import '../data/medicaments_repository.dart';

final medicamentsRepositoryProvider = Provider<MedicamentsRepository>(
  (ref) => MedicamentsRepository(),
);

final medicamentsProvider = FutureProvider.autoDispose<List<Medicament>>((ref) {
  return ref.watch(medicamentsRepositoryProvider).fetchAll();
});

final mouvementsStockProvider = FutureProvider.autoDispose
    .family<List<MouvementStock>, String>((ref, medicamentId) {
      return ref
          .watch(medicamentsRepositoryProvider)
          .fetchMouvements(medicamentId);
    });

/// Période d'observation de la consommation (bornes incluses).
typedef PeriodeConsommation = ({DateTime debut, DateTime fin});

final consommationProvider = FutureProvider.autoDispose
    .family<List<ConsommationMedicament>, PeriodeConsommation>((ref, periode) {
      return ref
          .watch(medicamentsRepositoryProvider)
          .fetchConsommation(debut: periode.debut, fin: periode.fin);
    });
