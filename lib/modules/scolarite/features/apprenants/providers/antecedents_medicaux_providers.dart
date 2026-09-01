import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/antecedents_medicaux.dart';
import '../data/antecedents_medicaux_repository.dart';

final antecedentsMedicauxRepositoryProvider =
    Provider<AntecedentsMedicauxRepository>(
      (ref) => AntecedentsMedicauxRepository(),
    );

final antecedentsMedicauxProvider = FutureProvider.autoDispose
    .family<AntecedentsMedicaux?, String>((ref, apprenantId) {
      return ref
          .watch(antecedentsMedicauxRepositoryProvider)
          .fetchByApprenant(apprenantId);
    });
