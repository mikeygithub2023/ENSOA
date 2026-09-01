import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sig_ensoa/modules/scolarite/compat.dart';
import '../data/admin_repository.dart';
import '../data/espaces_eleves_repository.dart';

final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => AdminRepository(),
);

final profilesListProvider = FutureProvider.autoDispose<List<Profile>>((ref) {
  return ref.watch(adminRepositoryProvider).fetchProfiles();
});

final auditLogProvider = FutureProvider.autoDispose<List<AuditEntry>>((ref) {
  return ref.watch(adminRepositoryProvider).fetchAuditLog();
});

final espacesElevesRepositoryProvider = Provider<EspacesElevesRepository>(
  (ref) => EspacesElevesRepository(),
);
