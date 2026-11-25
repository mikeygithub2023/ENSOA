import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/pension.dart';
import '../data/pension_repository.dart';

final pensionRepositoryProvider = Provider<PensionRepository>(
  (ref) => PensionRepository(),
);

/// Le catalogue des pièces en service — celles que la saisie propose.
final piecesPensionProvider = FutureProvider.autoDispose<List<PiecePension>>((
  ref,
) {
  return ref.watch(pensionRepositoryProvider).fetchPieces();
});

/// Le catalogue entier, pièces désactivées comprises — l'écran de gestion.
final toutesLesPiecesPensionProvider =
    FutureProvider.autoDispose<List<PiecePension>>((ref) {
      return ref.watch(pensionRepositoryProvider).fetchPieces(toutes: true);
    });

/// Toutes les vérifications visibles, pour l'onglet qui les range par
/// militaire.
final lignesPensionProvider = FutureProvider.autoDispose<List<LignePension>>((
  ref,
) {
  return ref.watch(pensionRepositoryProvider).fetchLignes();
});

final lignesPensionByApprenantProvider = FutureProvider.autoDispose
    .family<List<LignePension>, String>((ref, apprenantId) {
      return ref
          .watch(pensionRepositoryProvider)
          .fetchLignesByApprenant(apprenantId);
    });
