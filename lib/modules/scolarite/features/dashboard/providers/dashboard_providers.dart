import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/apprenant.dart';
import '../../../models/division.dart';
import '../../apprenants/providers/apprenants_providers.dart';

class DivisionCount {
  const DivisionCount({required this.division, required this.count});

  final Division division;
  final int count;
}

class DashboardStats {
  const DashboardStats({required this.total, required this.parDivision});

  final int total;
  final List<DivisionCount> parDivision;
}

/// Statistiques du tableau de bord — dérivées des données déjà filtrées par
/// RLS (chaque rôle ne voit que ce que Postgres lui autorise).
final dashboardStatsProvider = FutureProvider.autoDispose<DashboardStats>((
  ref,
) async {
  // Un reversé a quitté l'école : sa fiche reste, il ne compte plus.
  final apprenants = (await ref.watch(
    apprenantsListProvider.future,
  )).where((a) => a.statut != ApprenantStatut.reverse).toList();
  final divisions = await ref.watch(divisionsProvider.future);
  final divisionsById = {for (final d in divisions) d.id: d};

  final counts = <String, int>{};
  for (final apprenant in apprenants) {
    counts[apprenant.divisionId] = (counts[apprenant.divisionId] ?? 0) + 1;
  }

  final parDivision =
      counts.entries
          .where((e) => divisionsById.containsKey(e.key))
          .map(
            (e) =>
                DivisionCount(division: divisionsById[e.key]!, count: e.value),
          )
          .toList()
        ..sort((a, b) => a.division.nom.compareTo(b.division.nom));

  return DashboardStats(total: apprenants.length, parDivision: parDivision);
});
