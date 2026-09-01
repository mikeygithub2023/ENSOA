import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/classe.dart';
import '../../../models/matiere.dart';
import '../../../models/promotion.dart';
import '../data/classes_repository.dart';
import '../data/matieres_repository.dart';
import '../data/promotions_repository.dart';

final matieresRepositoryProvider = Provider<MatieresRepository>(
  (ref) => MatieresRepository(),
);

final matieresCatalogueProvider = FutureProvider.autoDispose<List<Matiere>>((
  ref,
) {
  return ref.watch(matieresRepositoryProvider).fetchCatalogue();
});

final matiereModulesProvider = FutureProvider.autoDispose<List<MatiereModule>>((
  ref,
) {
  return ref.watch(matieresRepositoryProvider).fetchModules();
});

final classesRepositoryProvider = Provider<ClassesRepository>(
  (ref) => ClassesRepository(),
);

final classesListProvider = FutureProvider.autoDispose<List<Classe>>((ref) {
  return ref.watch(classesRepositoryProvider).fetchAll();
});

final promotionsRepositoryProvider = Provider<PromotionsRepository>(
  (ref) => PromotionsRepository(),
);

final promotionsListProvider = FutureProvider.autoDispose<List<Promotion>>((
  ref,
) {
  return ref.watch(promotionsRepositoryProvider).fetchAll();
});

/// Les promotions d'une division, dans l'ordre où elles se lisent.
final promotionsParDivisionProvider = Provider.autoDispose
    .family<List<Promotion>, String>((ref, divisionId) {
      final promotions = ref.watch(promotionsListProvider).value ?? const [];
      return promotions.where((p) => p.divisionId == divisionId).toList();
    });
