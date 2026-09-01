import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/controle.dart';
import '../../../models/note.dart';
import '../data/controles_repository.dart';

final controlesRepositoryProvider = Provider<ControlesRepository>(
  (ref) => ControlesRepository(),
);

final controlesByClasseProvider = FutureProvider.autoDispose
    .family<List<Controle>, String>((ref, classeId) {
      return ref.watch(controlesRepositoryProvider).fetchByClasse(classeId);
    });

final notesByControleProvider = FutureProvider.autoDispose
    .family<List<Note>, String>((ref, controleId) {
      return ref.watch(controlesRepositoryProvider).fetchNotes(controleId);
    });

final notesByClasseProvider = FutureProvider.autoDispose
    .family<List<Note>, String>((ref, classeId) {
      return ref
          .watch(controlesRepositoryProvider)
          .fetchNotesByClasse(classeId);
    });

final controleByIdProvider = FutureProvider.autoDispose
    .family<Controle?, String>((ref, controleId) {
      return ref.watch(controlesRepositoryProvider).fetchById(controleId);
    });

final notesByApprenantProvider = FutureProvider.autoDispose
    .family<List<Note>, String>((ref, apprenantId) {
      return ref
          .watch(controlesRepositoryProvider)
          .fetchByApprenant(apprenantId);
    });
