import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/classe.dart';
import '../../../models/matiere.dart';
import '../../../models/promotion.dart';
import '../../../models/section.dart';
import '../data/classes_repository.dart';
import '../data/matieres_repository.dart';
import '../data/promotions_repository.dart';
import '../data/sections_repository.dart';

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

final sectionsRepositoryProvider = Provider<SectionsRepository>(
  (ref) => SectionsRepository(),
);

final sectionsListProvider = FutureProvider.autoDispose<List<Section>>((ref) {
  return ref.watch(sectionsRepositoryProvider).fetchAll();
});

/// Les sections d'une promotion, dans l'ordre où elles défilent.
final sectionsParPromotionProvider = Provider.autoDispose
    .family<List<Section>, String>((ref, promotionId) {
      final sections = ref.watch(sectionsListProvider).value ?? const [];
      return sections.where((s) => s.promotionId == promotionId).toList();
    });
