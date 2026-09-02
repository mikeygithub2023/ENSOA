import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/permission.dart';
import '../data/permissions_repository.dart';

final permissionsRepositoryProvider = Provider<PermissionsRepository>(
  (ref) => PermissionsRepository(),
);

final permissionsByClasseProvider = FutureProvider.autoDispose
    .family<List<Permission>, String>((ref, classeId) {
      return ref.watch(permissionsRepositoryProvider).fetchByClasse(classeId);
    });

final permissionsByDivisionProvider = FutureProvider.autoDispose
    .family<List<Permission>, String>((ref, divisionId) {
      return ref
          .watch(permissionsRepositoryProvider)
          .fetchByDivision(divisionId);
    });

final permissionsByApprenantProvider = FutureProvider.autoDispose
    .family<List<Permission>, String>((ref, apprenantId) {
      return ref
          .watch(permissionsRepositoryProvider)
          .fetchByApprenant(apprenantId);
    });

/// Toutes les permissions visibles, divisions confondues — la vue
/// « Toutes ». Ce que chacun y trouve dépend de la RLS, pas de ce
/// fournisseur : un commandant de division n'y voit que la sienne.
final permissionsToutesProvider = FutureProvider.autoDispose<List<Permission>>((
  ref,
) {
  return ref.watch(permissionsRepositoryProvider).fetchToutes();
});
