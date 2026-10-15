import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sig_ensoa/core/chargement.dart';
import 'package:sig_ensoa/core/theme.dart';
import 'package:sig_ensoa/shared/widgets/icone_arme.dart';
import '../../data/models/armement.dart';
import '../../data/repositories/armament_providers.dart';
import '../../shared/widgets/dashboard_widgets.dart';
import '../../shared/widgets/skeleton.dart';
import '../../shared/widgets/widgets.dart';
import 'alertes_card.dart';

/// Le tableau de bord de l'armurier.
///
/// Il tenait jusqu'ici celui du chef du soutien technique : la disponibilité
/// du parc, le carburant en soute, les trois services réunis. Rien de tout
/// cela ne relève de lui, et les deux chiffres qui le concernaient se
/// perdaient au milieu. Il a désormais le sien — les armes, les dotations,
/// les munitions, les équipements de protection —, et rien d'autre.
class DashboardArmurerie extends ConsumerWidget {
  const DashboardArmurerie({super.key, this.sansCadre = false});

  /// Rendre le contenu nu, sans titre ni défilement propre : la page unifiée
  /// s'en charge.
  final bool sansCadre;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Les providers Riverpod sont paresseux : on les lit tous avant de
    // décider d'afficher l'attente, sans quoi le chargement ne démarrerait
    // jamais.
    final armes = ref.watch(armesProvider);
    final armesRetard = ref.watch(armesInspectionEnRetardProvider);
    final dotations = ref.watch(dotationsProvider);
    final dotationsRetard = ref.watch(dotationsEnRetardProvider);
    final munitions = ref.watch(munitionsProvider);
    final munitionsAlerte = ref.watch(munitionsEnAlerteProvider);
    final equipements = ref.watch(equipementsProvider);
    final equipementsAlerte = ref.watch(equipementsEnAlerteProvider);

    if (!estCharge(ref, [
      'armes',
      'dotations_armes',
      'munitions',
      'equipements',
    ])) {
      return const ScreenScaffold(
        title: 'Tableau de bord',
        children: [SkeletonDashboard()],
      );
    }

    // Une arme réformée n'est plus du parc : la compter ferait baisser une
    // disponibilité sur laquelle personne ne peut plus rien.
    final enService = armes.where((a) => a.etat != EtatArme.reforme).toList();
    final enArmurerie = enService
        .where((a) => a.etat == EtatArme.enArmurerie)
        .length;
    final enDotation = dotations
        .where((d) => d.dateRetourEffective == null)
        .length;

    // Les munitions se comptent par calibre, tous casiers confondus : c'est
    // ainsi qu'on les demande, et ainsi qu'on en manque.
    final parCalibre = <String, int>{};
    for (final m in munitions) {
      parCalibre[m.calibre] =
          (parCalibre[m.calibre] ?? 0) + m.quantiteDisponible;
    }
    final calibres = parCalibre.entries.map((e) => (e.key, e.value)).toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));
    final totalMunitions = parCalibre.values.fold<int>(0, (s, q) => s + q);

    void versArmement() => context.go('/logistique/armement');

    final alertes = <Alerte>[
      for (final d in dotationsRetard)
        Alerte(
          'Retour en retard — '
          '${d.beneficiaireNom.isEmpty ? d.beneficiaireId : d.beneficiaireNom}',
          versArmement,
          icone: Icons.assignment_late_rounded,
        ),
      for (final a in armesRetard)
        Alerte(
          '${a.designationComplete} — inspection en retard',
          versArmement,
          iconeWidget: const IconeArmeTeintee(
            couleur: AppColors.blueBright,
            size: 18,
          ),
        ),
      for (final m in munitionsAlerte)
        Alerte(
          'Munitions ${m.calibre} — stock critique',
          versArmement,
          icone: Icons.inventory_2_rounded,
        ),
      for (final e in equipementsAlerte)
        Alerte(
          '${e.libelle} — stock critique',
          versArmement,
          icone: Icons.health_and_safety_rounded,
        ),
    ];

    final contenu = <Widget>[
      LayoutBuilder(
        builder: (context, constraints) {
          final large = constraints.maxWidth > 820;
          final jauge = GaugeCard(
            title: 'Armes en armurerie',
            subtitle: 'Rentrées sur le parc en service',
            progress: enService.isEmpty ? 0 : enArmurerie / enService.length,
            centerValue: '$enArmurerie/${enService.length}',
            centerLabel: 'rentrées',
            color: AppColors.success,
          );
          final alerte = AlertesCard(alertes: alertes);
          if (!large) {
            return Column(
              children: [jauge, const SizedBox(height: 16), alerte],
            );
          }
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 6, child: jauge),
                const SizedBox(width: 16),
                Expanded(flex: 5, child: alerte),
              ],
            ),
          );
        },
      ),
      const SizedBox(height: 16),
      SoutesStockCard(
        title: 'Munitions par calibre',
        total: totalMunitions,
        soutes: calibres,
        unite: 'cart.',
      ),
      const SizedBox(height: 24),
      const SectionHeader(title: 'Suivi de l\'armurerie'),
      Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              DotProgressRow(
                icon: Icons.assignment_ind_rounded,
                iconColor: AppColors.navy,
                title: 'Dotations en cours',
                subtitle: 'Retours dans les délais',
                completed: enDotation - dotationsRetard.length,
                total: enDotation,
                onTap: versArmement,
              ),
              const Divider(height: 1),
              DotProgressRow(
                iconWidget: const IconeArmeTeintee(
                  couleur: AppColors.success,
                  size: 22,
                ),
                iconColor: AppColors.success,
                title: 'Inspections',
                subtitle: 'Armes à jour de contrôle',
                completed: enService.length - armesRetard.length,
                total: enService.length,
                onTap: versArmement,
              ),
              const Divider(height: 1),
              DotProgressRow(
                icon: Icons.inventory_2_rounded,
                iconColor: AppColors.blue,
                title: 'Munitions',
                subtitle: 'Calibres au-dessus du seuil critique',
                completed: munitions.length - munitionsAlerte.length,
                total: munitions.length,
                onTap: versArmement,
              ),
              const Divider(height: 1),
              DotProgressRow(
                icon: Icons.health_and_safety_rounded,
                iconColor: AppColors.warning,
                title: 'Équipements de protection',
                subtitle: 'Références au-dessus du seuil critique',
                completed: equipements.length - equipementsAlerte.length,
                total: equipements.length,
                onTap: versArmement,
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
