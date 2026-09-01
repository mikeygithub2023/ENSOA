import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/cours.dart';
import '../data/cours_repository.dart';

final coursRepositoryProvider = Provider<CoursRepository>(
  (ref) => CoursRepository(),
);

final coursByClasseProvider = FutureProvider.autoDispose
    .family<List<Cours>, String>((ref, classeId) {
      return ref.watch(coursRepositoryProvider).fetchByClasse(classeId);
    });

final qcmQuestionsProvider = FutureProvider.autoDispose
    .family<List<QcmQuestion>, String>((ref, devoirId) {
      return ref.watch(coursRepositoryProvider).fetchQuestions(devoirId);
    });

final resultatsDevoirProvider = FutureProvider.autoDispose
    .family<List<ResultatDevoir>, String>((ref, devoirId) {
      return ref.watch(coursRepositoryProvider).fetchResultats(devoirId);
    });
