import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sig_ensoa/core/chargement.dart';
import 'package:sig_ensoa/core/format.dart';
import 'package:sig_ensoa/core/theme.dart';
import '../../data/models/oa.dart';
import '../../data/repositories/fuel_providers.dart';
import '../../data/repositories/oa_providers.dart';
import '../../shared/widgets/dashboard_widgets.dart';
import '../../shared/widgets/skeleton.dart';
import '../../shared/widgets/widgets.dart';
import 'alertes_card.dart';

/// Le tableau de bord du soutien pétrolier.
///
/// Il lisait celui du chef du soutien technique : la disponibilité du parc,
/// les dotations d'armes, les inspections d'armement. Ses soutes y tenaient
/// deux lignes sur douze. Il a désormais le sien — les soutes, les dépotages,
/// les distributions —, et les tâches que l'Officier Adjoint lui confie.
class DashboardCarburant extends ConsumerWidget {
  const DashboardCarburant({super.key, this.sansCadre = false});

  /// Rendre le contenu nu, sans titre ni défilement propre : la page unifiée
  /// s'en charge.
  final bool sansCadre;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Les providers Riverpod sont paresseux : on les lit tous avant de
    // décider d'afficher l'attente, sans quoi le chargement ne démarrerait
    // jamais.
    final soutesAvecStock = ref.watch(soutesAvecStockProvider);
    final soutesAlerte = ref.watch(soutesEnAlerteProvider);
    final journal = ref.watch(journalCarburantProvider);
    final mesTaches = ref.watch(mesTachesProvider);

    if (!estCharge(ref, [
      'soutes',
      'soute_stocks',
      'depotages',
      'distributions',
    ])) {
      // Sans cadre, le squelette se rend nu : la page qui réunit les onglets
      // porte déjà le titre et le défilement.
      return sansCadre
          ? const SkeletonDashboard()
          : const ScreenScaffold(
              title: 'Tableau de bord',
              children: [SkeletonDashboard()],
            );
    }

    final totalStock = soutesAvecStock.fold<int>(
      0,
      (s, x) => s + x.stock.quantiteTotale,
    );

    // Une soute peut porter plusieurs répartitions : on additionne les lignes
    // qui la concernent, pour n'annoncer qu'un chiffre par soute.
    final parSoute = <String, int>{};
    for (final x in soutesAvecStock) {
      parSoute[x.soute.libelle] =
          (parSoute[x.soute.libelle] ?? 0) + x.stock.quantiteTotale;
    }
    final soutesParVolume =
        parSoute.entries.map((e) => (e.key, e.value)).toList()
          ..sort((a, b) => b.$2.compareTo(a.$2));

    // « Du jour » veut dire du jour. Le journal porte tout l'historique : le
    // filtrer ici est ce qui rend le titre vrai.
    final maintenant = DateTime.now();
    bool aujourdhui(DateTime d) =>
        d.year == maintenant.year &&
        d.month == maintenant.month &&
        d.day == maintenant.day;
    final duJour = journal.where((j) => aujourdhui(j.date)).toList();
    final entreesJour = duJour
        .where((j) => j.entree)
        .fold<int>(0, (s, j) => s + j.quantite);
    final sortiesJour = duJour
        .where((j) => !j.entree)
        .fold<int>(0, (s, j) => s + j.quantite);

    void versCarburant() => context.go('/logistique/carburant');
    void versActivites() => context.go('/logistique/activites');

    final alertes = <Alerte>[
      for (final s in soutesAlerte)
        Alerte(
          '${s.soute.libelle} — stock critique',
          versCarburant,
          icone: Icons.warehouse_rounded,
        ),
      // Les tâches confiées par l'Officier Adjoint sont du travail du service
      // au même titre qu'un dépotage : elles se lisent au même endroit.
      for (final t in mesTaches.where((t) => t.statut == StatutTache.aFaire))
        Alerte(
          'Tâche confiée — ${t.description}',
          versActivites,
          icone: Icons.assignment_turned_in_rounded,
        ),
    ];

    final contenu = <Widget>[
      LayoutBuilder(
        builder: (context, constraints) {
          final large = constraints.maxWidth > 820;
          final apercu = FuelOverviewCard(
            title: 'Aperçu carburant du jour',
            subtitle: 'Entrées / sorties / stock total',
            stockLabel: 'Stock total (toutes soutes)',
            stockValue: '${formatMilliers(totalStock)} L',
            entrees: entreesJour,
            sorties: sortiesJour,
          );
          final alerte = AlertesCard(alertes: alertes);
          if (!large) {
            return Column(
              children: [apercu, const SizedBox(height: 16), alerte],
            );
          }
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 6, child: apercu),
                const SizedBox(width: 16),
                Expanded(flex: 5, child: alerte),
              ],
            ),
          );
        },
      ),
      const SizedBox(height: 16),
      SoutesStockCard(
        title: 'Carburant en soute',
        total: totalStock,
        soutes: soutesParVolume,
      ),
      const SizedBox(height: 24),
      const SectionHeader(title: 'Suivi du soutien pétrolier'),
      Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              DotProgressRow(
                icon: Icons.warehouse_rounded,
                iconColor: AppColors.blue,
                title: 'Soutes',
                subtitle: 'Au-dessus du seuil critique',
                completed: soutesAvecStock.length - soutesAlerte.length,
                total: soutesAvecStock.length,
                onTap: versCarburant,
              ),
              const Divider(height: 1),
              DotProgressRow(
                icon: Icons.local_shipping_rounded,
                iconColor: AppColors.success,
                title: 'Dépotages du jour',
                subtitle: '${formatMilliers(entreesJour)} L reçus',
                completed: duJour.where((j) => j.entree).length,
                total: duJour.isEmpty ? 1 : duJour.length,
                onTap: versCarburant,
              ),
              const Divider(height: 1),
              DotProgressRow(
                icon: Icons.local_gas_station_rounded,
                iconColor: AppColors.ivoryOrange,
                title: 'Distributions du jour',
                subtitle: '${formatMilliers(sortiesJour)} L délivrés',
                completed: duJour.where((j) => !j.entree).length,
                total: duJour.isEmpty ? 1 : duJour.length,
                onTap: versCarburant,
              ),
            ],
          ),
        ),
      ),
    ];

    return sansCadre
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: contenu,
          )
        : ScreenScaffold(title: 'Tableau de bord', children: contenu);
  }
}
