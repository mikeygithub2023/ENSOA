import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/absence.dart';
import '../data/absences_repository.dart';

final absencesRepositoryProvider = Provider<AbsencesRepository>(
  (ref) => AbsencesRepository(),
);

final absencesByClasseProvider = FutureProvider.autoDispose
    .family<List<Absence>, String>((ref, classeId) {
      return ref.watch(absencesRepositoryProvider).fetchByClasse(classeId);
    });

final absencesByDivisionProvider = FutureProvider.autoDispose
    .family<List<Absence>, String>((ref, divisionId) {
      return ref.watch(absencesRepositoryProvider).fetchByDivision(divisionId);
    });

final absencesByApprenantProvider = FutureProvider.autoDispose
    .family<List<Absence>, String>((ref, apprenantId) {
      return ref
          .watch(absencesRepositoryProvider)
          .fetchByApprenant(apprenantId);
    });

/// Toutes les absences visibles, divisions confondues — la vue « Toutes ».
final absencesToutesProvider = FutureProvider.autoDispose<List<Absence>>((ref) {
  return ref.watch(absencesRepositoryProvider).fetchToutes();
});
