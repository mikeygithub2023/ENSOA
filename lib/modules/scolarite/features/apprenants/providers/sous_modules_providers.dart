import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/sous_module.dart';
import '../data/sous_modules_repository.dart';

final sousModulesRepositoryProvider = Provider<SousModulesRepository>(
  (ref) => SousModulesRepository(),
);

final sousModulesByModuleProvider = FutureProvider.autoDispose
    .family<List<SousModule>, String>((ref, moduleId) {
      return ref.watch(sousModulesRepositoryProvider).fetchByModule(moduleId);
    });

/// Les sous-modules de tous les modules d'une phase/stage — nécessaire pour
/// recomposer la note d'un module à partir des siens (voir `moyennes.dart`).
final sousModulesByClasseProvider = FutureProvider.autoDispose
    .family<List<SousModule>, String>((ref, classeId) {
      return ref.watch(sousModulesRepositoryProvider).fetchByClasse(classeId);
    });
