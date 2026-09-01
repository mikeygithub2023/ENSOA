import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/apprenant.dart';
import '../../matieres/providers/matieres_providers.dart';
import '../data/apprenants_repository.dart';

final apprenantsRepositoryProvider = Provider<ApprenantsRepository>(
  (ref) => ApprenantsRepository(),
);

/// Liste des apprenants visibles pour l'utilisateur connecté — le filtrage
/// par division/rôle est garanti côté serveur par les policies RLS.
final apprenantsListProvider = FutureProvider.autoDispose<List<Apprenant>>((
  ref,
) {
  return ref.watch(apprenantsRepositoryProvider).fetchAll();
});

final apprenantByIdProvider = FutureProvider.autoDispose
    .family<Apprenant?, String>((ref, id) {
      return ref.watch(apprenantsRepositoryProvider).fetchById(id);
    });

/// L'effectif d'une phase ou d'un stage.
///
/// Pour un stage, ce sont ses seuls stagiaires. Pour une phase, c'est
/// l'effectif de sa promotion entière : un élève entre dans une promotion
/// et suit toutes ses phases, il n'appartient pas à l'une plutôt qu'à
/// l'autre. Sans cela, la saisie des notes d'une deuxième phase n'aurait
/// proposé que les élèves enregistrés sous elle, et la moyenne du bulletin
/// — qui couvre toutes les phases — aurait été fausse.
final apprenantsByClasseProvider = FutureProvider.autoDispose
    .family<List<Apprenant>, String>((ref, classeId) async {
      final repo = ref.watch(apprenantsRepositoryProvider);
      final classes = await ref.watch(classesListProvider.future);
      final promotionId = classes
          .where((c) => c.id == classeId)
          .firstOrNull
          ?.promotionId;
      return promotionId == null
          ? repo.fetchByClasse(classeId)
          : repo.fetchByPromotion(promotionId);
    });

/// L'effectif d'une promotion, pour les écrans qui la prennent d'emblée
/// pour portée — le bulletin de promotion, notamment.
final apprenantsByPromotionProvider = FutureProvider.autoDispose
    .family<List<Apprenant>, String>((ref, promotionId) {
      return ref
          .watch(apprenantsRepositoryProvider)
          .fetchByPromotion(promotionId);
    });

final apprenantsByDivisionProvider = FutureProvider.autoDispose
    .family<List<Apprenant>, String>((ref, divisionId) {
      return ref
          .watch(apprenantsRepositoryProvider)
          .fetchByDivision(divisionId);
    });

final monApprenantProvider = FutureProvider.autoDispose
    .family<Apprenant?, String>((ref, profileId) {
      return ref
          .watch(apprenantsRepositoryProvider)
          .fetchByProfileId(profileId);
    });

final apprenantDiplomesProvider = FutureProvider.autoDispose
    .family<List<String>, String>((ref, apprenantId) {
      return ref.watch(apprenantsRepositoryProvider).fetchDiplomes(apprenantId);
    });

/// URL signée temporaire pour afficher la photo d'un apprenant (bucket privé).
final apprenantPhotoUrlProvider = FutureProvider.autoDispose
    .family<String, String>((ref, photoPath) {
      return ref
          .watch(apprenantsRepositoryProvider)
          .getPhotoSignedUrl(photoPath);
    });
