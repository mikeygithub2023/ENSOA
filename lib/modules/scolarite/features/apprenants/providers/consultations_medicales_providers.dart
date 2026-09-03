import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/consultation_medicale.dart';
import '../../../models/medicament.dart';
import '../data/consultations_medicales_repository.dart';

final consultationsMedicalesRepositoryProvider =
    Provider<ConsultationsMedicalesRepository>(
      (ref) => ConsultationsMedicalesRepository(),
    );

final consultationsMedicalesByClasseProvider = FutureProvider.autoDispose
    .family<List<ConsultationMedicale>, String>((ref, classeId) {
      return ref
          .watch(consultationsMedicalesRepositoryProvider)
          .fetchByClasse(classeId);
    });

final consultationsMedicalesByDivisionProvider = FutureProvider.autoDispose
    .family<List<ConsultationMedicale>, String>((ref, divisionId) {
      return ref
          .watch(consultationsMedicalesRepositoryProvider)
          .fetchByDivision(divisionId);
    });

final consultationsMedicalesByApprenantProvider = FutureProvider.autoDispose
    .family<List<ConsultationMedicale>, String>((ref, apprenantId) {
      return ref
          .watch(consultationsMedicalesRepositoryProvider)
          .fetchByApprenant(apprenantId);
    });

final ordonnanceLignesByConsultationProvider = FutureProvider.autoDispose
    .family<List<OrdonnanceLigne>, String>((ref, consultationId) {
      return ref
          .watch(consultationsMedicalesRepositoryProvider)
          .fetchOrdonnanceLignes(consultationId);
    });

/// Toutes les consultations visibles, divisions confondues — la vue
/// « Toutes ».
final consultationsMedicalesToutesProvider =
    FutureProvider.autoDispose<List<ConsultationMedicale>>((ref) {
      return ref.watch(consultationsMedicalesRepositoryProvider).fetchToutes();
    });
