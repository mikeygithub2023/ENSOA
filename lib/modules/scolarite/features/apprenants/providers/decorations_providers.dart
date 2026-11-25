import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/decoration.dart';
import '../data/decorations_repository.dart';

final decorationsRepositoryProvider = Provider<DecorationsRepository>(
  (ref) => DecorationsRepository(),
);

/// Le catalogue en service — celui que la saisie propose.
final catalogueDecorationsProvider =
    FutureProvider.autoDispose<List<TypeDecoration>>((ref) {
      return ref.watch(decorationsRepositoryProvider).fetchCatalogue();
    });

/// Le catalogue entier, décorations désactivées comprises.
final toutLeCatalogueDecorationsProvider =
    FutureProvider.autoDispose<List<TypeDecoration>>((ref) {
      return ref
          .watch(decorationsRepositoryProvider)
          .fetchCatalogue(toutes: true);
    });

/// Toutes les attributions visibles — la RLS borne le résultat.
final decorationsRecuesProvider =
    FutureProvider.autoDispose<List<DecorationRecue>>((ref) {
      return ref.watch(decorationsRepositoryProvider).fetchRecues();
    });

final decorationsRecuesByApprenantProvider = FutureProvider.autoDispose
    .family<List<DecorationRecue>, String>((ref, apprenantId) {
      return ref
          .watch(decorationsRepositoryProvider)
          .fetchRecuesByApprenant(apprenantId);
    });
