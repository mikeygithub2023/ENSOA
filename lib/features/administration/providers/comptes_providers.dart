import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/profil.dart';
import '../data/comptes_repository.dart';

final comptesRepositoryProvider = Provider<ComptesRepository>(
  (ref) => ComptesRepository(),
);

/// La liste des comptes. Ce que la RLS laisse voir, et rien de plus :
/// l'administrateur voit tout, le chef du Soutien Technique son service.
final comptesProvider = FutureProvider<List<Profil>>((ref) {
  return ref.watch(comptesRepositoryProvider).lister();
});
