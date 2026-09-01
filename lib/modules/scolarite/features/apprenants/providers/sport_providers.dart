import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/sous_module.dart';
import '../data/sport_repository.dart';

final sportRepositoryProvider = Provider<SportRepository>(
  (ref) => SportRepository(),
);

/// Le catalogue des activités sportives de l'école — paramétré dans
/// Matières, consulté partout où l'on crée une séance.
final activitesSportivesProvider =
    FutureProvider.autoDispose<List<ActiviteSportive>>(
      (ref) => ref.watch(sportRepositoryProvider).fetchActivites(),
    );

final baremeActiviteProvider = FutureProvider.autoDispose
    .family<List<BaremePalier>, String>((ref, activiteId) {
      return ref.watch(sportRepositoryProvider).fetchBareme(activiteId);
    });

/// Les séances du module Sport d'une phase, la plus récente en tête.
final seancesSportivesProvider = FutureProvider.autoDispose
    .family<List<({SousModule sousModule, SeanceSportive seance})>, String>((
      ref,
      moduleSportId,
    ) {
      return ref.watch(sportRepositoryProvider).fetchSeances(moduleSportId);
    });

final performancesSeanceProvider = FutureProvider.autoDispose
    .family<List<PerformanceSportive>, String>((ref, sousModuleId) {
      return ref.watch(sportRepositoryProvider).fetchPerformances(sousModuleId);
    });
