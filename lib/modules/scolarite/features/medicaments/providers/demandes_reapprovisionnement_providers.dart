import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/demande_reapprovisionnement.dart';
import '../data/demandes_reapprovisionnement_repository.dart';

final demandesReapprovisionnementRepositoryProvider =
    Provider<DemandesReapprovisionnementRepository>(
      (ref) => DemandesReapprovisionnementRepository(),
    );

final demandesReapprovisionnementProvider =
    FutureProvider.autoDispose<List<DemandeReapprovisionnement>>((ref) {
      return ref
          .watch(demandesReapprovisionnementRepositoryProvider)
          .fetchAll();
    });
