import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/profil.dart';
import '../data/comptes_repository.dart';

final comptesRepositoryProvider = Provider<ComptesRepository>(
  (ref) => ComptesRepository(),
);

/// La liste des comptes. Ce que la RLS laisse voir, et rien de plus :
/// l'administrateur voit tout, le chef du Soutien Technique son service.
///
/// `autoDispose` : la liste se relit à chaque ouverture de l'écran. Sans
/// cela, elle était chargée une fois pour la session et n'en bougeait plus —
/// un mot de passe changé par quelqu'un d'autre laissait l'administrateur
/// devant la mention « Mot de passe à changer » jusqu'à ce qu'il ferme
/// l'application. La table compte quelques dizaines de lignes : la relire
/// coûte moins cher que d'afficher un état faux.
final comptesProvider = FutureProvider.autoDispose<List<Profil>>((ref) {
  return ref.watch(comptesRepositoryProvider).lister();
});
