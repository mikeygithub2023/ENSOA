import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/local_disciplinaire.dart';
import '../data/locaux_disciplinaires_repository.dart';

final locauxDisciplinairesRepositoryProvider =
    Provider<LocauxDisciplinairesRepository>(
      (ref) => LocauxDisciplinairesRepository(),
    );

final locauxDisciplinairesByClasseProvider = FutureProvider.autoDispose
    .family<List<LocalDisciplinaire>, String>((ref, classeId) {
      return ref
          .watch(locauxDisciplinairesRepositoryProvider)
          .fetchByClasse(classeId);
    });

final locauxDisciplinairesByDivisionProvider = FutureProvider.autoDispose
    .family<List<LocalDisciplinaire>, String>((ref, divisionId) {
      return ref
          .watch(locauxDisciplinairesRepositoryProvider)
          .fetchByDivision(divisionId);
    });

final locauxDisciplinairesByApprenantProvider = FutureProvider.autoDispose
    .family<List<LocalDisciplinaire>, String>((ref, apprenantId) {
      return ref
          .watch(locauxDisciplinairesRepositoryProvider)
          .fetchByApprenant(apprenantId);
    });

/// Tous les séjours visibles, divisions confondues — la vue « Toutes ».
final locauxDisciplinairesTousProvider =
    FutureProvider.autoDispose<List<LocalDisciplinaire>>((ref) {
      return ref.watch(locauxDisciplinairesRepositoryProvider).fetchTous();
    });
