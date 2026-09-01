import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/visite_medicale.dart';
import '../data/visites_medicales_repository.dart';

final visitesMedicalesRepositoryProvider = Provider<VisitesMedicalesRepository>(
  (ref) => VisitesMedicalesRepository(),
);

final visitesMedicalesProvider =
    FutureProvider.autoDispose<List<VisiteMedicale>>(
      (ref) => ref.watch(visitesMedicalesRepositoryProvider).fetchAll(),
    );

final visiteMedicaleByIdProvider = FutureProvider.autoDispose
    .family<VisiteMedicale?, String>((ref, id) {
      return ref.watch(visitesMedicalesRepositoryProvider).fetchById(id);
    });

/// Apprenants déjà passés à une visite, avec leur examen.
final visiteApprenantsProvider = FutureProvider.autoDispose
    .family<List<VisiteMedicaleApprenant>, String>((ref, visiteId) {
      return ref
          .watch(visitesMedicalesRepositoryProvider)
          .fetchApprenants(visiteId);
    });

/// Nombre d'apprenants passés, par visite — affiché dans la liste des
/// visites.
final visitesEffectifsProvider = FutureProvider.autoDispose<Map<String, int>>(
  (ref) => ref.watch(visitesMedicalesRepositoryProvider).fetchEffectifs(),
);
