import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/mouvement_personnel.dart';
import '../data/mouvements_repository.dart';

final mouvementsRepositoryProvider = Provider<MouvementsRepository>(
  (ref) => MouvementsRepository(),
);

final mouvementsByApprenantProvider = FutureProvider.autoDispose
    .family<List<MouvementPersonnel>, String>((ref, apprenantId) {
      return ref
          .watch(mouvementsRepositoryProvider)
          .fetchByApprenant(apprenantId);
    });
