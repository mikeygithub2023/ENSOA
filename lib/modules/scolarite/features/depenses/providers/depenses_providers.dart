import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/depense.dart';
import '../data/depenses_repository.dart';

final depensesRepositoryProvider = Provider<DepensesRepository>(
  (ref) => DepensesRepository(),
);

/// Période d'observation des dépenses (bornes incluses). Un enregistrement
/// Dart plutôt qu'une classe : l'égalité structurelle est déjà celle
/// attendue par la famille de providers.
typedef PeriodeDepenses = ({DateTime debut, DateTime fin});

final depensesProvider = FutureProvider.autoDispose
    .family<List<Depense>, PeriodeDepenses>((ref, periode) {
      return ref
          .watch(depensesRepositoryProvider)
          .fetchBetween(debut: periode.debut, fin: periode.fin);
    });

final depensesByConsultationProvider = FutureProvider.autoDispose
    .family<List<Depense>, String>((ref, consultationId) {
      return ref
          .watch(depensesRepositoryProvider)
          .fetchByConsultation(consultationId);
    });
