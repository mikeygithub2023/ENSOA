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

/// Ce que l'apprenant a réalisé à chaque séance, déjà mis en forme — « 12′30″ »
/// plutôt que 750 —, rangé par sous-module.
///
/// Sa fiche n'affichait que la note du sportif. Or la note est une lecture du
/// barème : elle dit le rang, pas la performance. Les deux se lisent
/// maintenant côte à côte.
final performancesApprenantProvider = FutureProvider.autoDispose
    .family<Map<String, String>, String>((ref, apprenantId) async {
      final realisees = await ref
          .watch(sportRepositoryProvider)
          .fetchPerformancesApprenant(apprenantId);
      if (realisees.isEmpty) return const {};

      final activites = await ref.watch(activitesSportivesProvider.future);
      return performancesParSeance(realisees, activites);
    });

/// Met en forme chaque performance dans l'unité de son activité.
///
/// Une séance dont l'activité a disparu du catalogue est laissée de côté :
/// sans unité, « 750 » ne veut rien dire, et la note reste seule — ce qui
/// est encore la lecture la moins fausse.
Map<String, String> performancesParSeance(
  List<({PerformanceSportive performance, String activiteId})> realisees,
  List<ActiviteSportive> activites,
) {
  final activitesById = {for (final a in activites) a.id: a};
  return {
    for (final realisee in realisees)
      if (activitesById[realisee.activiteId] case final activite?)
        realisee.performance.sousModuleId: activite.unite.formater(
          realisee.performance.valeur,
        ),
  };
}
