import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sig_ensoa/core/theme.dart';
import 'package:sig_ensoa/core/chargement.dart';
import 'package:sig_ensoa/core/format.dart';
import '../../data/models/armement.dart';
import '../../data/repositories/armament_providers.dart';
import '../../shared/widgets/dashboard_widgets.dart';
import '../../shared/widgets/skeleton.dart';
import 'package:sig_ensoa/shared/widgets/icone_arme.dart';
import '../../shared/widgets/widgets.dart';

/// Sous-rubrique « Inventaire » de l'Armement — l'état du registre d'armes.
///
/// L'inventaire était auparavant unique pour les trois domaines. Il est
/// désormais rendu à chacun : on fait l'inventaire des armes, ou celui des
/// munitions, mais rarement les deux dans le même geste.
class InventaireArmesTabContent extends ConsumerWidget {
  const InventaireArmesTabContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final charge = estCharge(ref, ['armes', 'dotations_armes']);
    final armes = ref.watch(armesProvider);
    final dotationsRetard = ref.watch(dotationsEnRetardProvider);
    final armesRetard = ref.watch(armesInspectionEnRetardProvider);
    final enDotation = ref
        .watch(dotationsProvider)
        .where((d) => d.enCours)
        .length;

    if (!charge) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(4, 4, 4, 100),
        child: SkeletonGrid(
          itemCount: 4,
          maxCrossAxisExtent: 260,
          mainAxisExtent: 168,
        ),
      );
    }

    final parEtat = {
      for (final e in EtatArme.values)
        e: armes.where((a) => a.etat == e).length,
    };
    // Une position vide n'est pas une position : elle est comptée à part
    // plutôt que rangée sous une étiquette inventée.
    final parPosition = <String, int>{};
    var sansPosition = 0;
    for (final a in armes) {
      final p = a.positionActuelle?.trim() ?? '';
      if (p.isEmpty) {
        sansPosition++;
      } else {
        parPosition[p] = (parPosition[p] ?? 0) + 1;
      }
    }
    final positions = parPosition.keys.toList()..sort();

    return ListView(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 100),
      children: [
        SectionHeader(title: 'Vue d\'ensemble'),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(
              width: 240,
              child: StatCard(
                label: 'Armes au registre',
                value: '${armes.length}',
                iconWidget: const IconeArme(size: 30),
                color: AppColors.navy,
              ),
            ),
            SizedBox(
              width: 240,
              child: StatCard(
                label: 'En armurerie',
                value: '${parEtat[EtatArme.enArmurerie]}',
                icon: Icons.lock_outline,
                color: AppColors.militaryGreen,
              ),
            ),
            SizedBox(
              width: 240,
              child: StatCard(
                label: 'Sorties en cours',
                value: '$enDotation',
                icon: Icons.assignment_ind_outlined,
                color: enDotation == 0
                    ? AppColors.militaryGreen
                    : AppColors.ivoryOrange,
              ),
            ),
            SizedBox(
              width: 240,
              child: StatCard(
                label: 'Retours en retard',
                value: '${dotationsRetard.length}',
                icon: Icons.assignment_late_outlined,
                color: dotationsRetard.isEmpty
                    ? AppColors.militaryGreen
                    : AppColors.danger,
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        SectionHeader(title: 'Répartition des armes par état'),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                for (final e in EtatArme.values) ...[
                  DotProgressRow(
                    iconWidget: const IconeArme(size: 28),
                    iconColor: AppColors.navy,
                    title: e.label,
                    subtitle: '${parEtat[e]} arme(s)',
                    completed: parEtat[e] ?? 0,
                    total: armes.isEmpty ? 1 : armes.length,
                  ),
                  if (e != EtatArme.values.last) const Divider(height: 1),
                ],
              ],
            ),
          ),
        ),
        if (positions.isNotEmpty || sansPosition > 0) ...[
          const SizedBox(height: 28),
          SectionHeader(title: 'Répartition par position'),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  for (final p in positions) ...[
                    DotProgressRow(
                      icon: Icons.place_outlined,
                      iconColor: AppColors.navy,
                      title: p,
                      subtitle: '${parPosition[p]} arme(s)',
                      completed: parPosition[p] ?? 0,
                      total: armes.isEmpty ? 1 : armes.length,
                    ),
                    const Divider(height: 1),
                  ],
                  if (sansPosition > 0)
                    DotProgressRow(
                      icon: Icons.help_outline,
                      iconColor: AppColors.inkMuted,
                      title: 'Position non renseignée',
                      subtitle: '$sansPosition arme(s)',
                      completed: sansPosition,
                      total: armes.isEmpty ? 1 : armes.length,
                    ),
                ],
              ),
            ),
          ),
        ],
        if (armesRetard.isNotEmpty) ...[
          const SizedBox(height: 28),
          SectionHeader(title: 'Inspections en retard (${armesRetard.length})'),
          for (final a in armesRetard)
            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.danger,
                ),
                title: Text(a.designationComplete),
                subtitle: Text('N° série ${a.numeroSerie}'),
              ),
            ),
        ],
      ],
    );
  }
}

/// Sous-rubrique « Inventaire » des munitions et des équipements.
///
/// Les deux familles se comptent de la même façon — une quantité, un seuil
/// critique, un journal —, d'où un seul écran paramétré.
class InventaireStockTabContent extends ConsumerWidget {
  const InventaireStockTabContent({super.key, required this.famille});

  final FamilleArticle famille;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final munitions = famille == FamilleArticle.munition;
    final cle = munitions ? 'munitions' : 'equipements';
    final charge = estCharge(ref, [cle, 'mouvements_articles']);

    if (!charge) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(4, 4, 4, 100),
        child: SkeletonGrid(
          itemCount: 4,
          maxCrossAxisExtent: 260,
          mainAxisExtent: 168,
        ),
      );
    }

    // Articles et seuils, ramenés à une forme commune aux deux familles.
    final articles = munitions
        ? [
            for (final m in ref.watch(munitionsProvider))
              (
                nom: 'Calibre ${m.calibre}',
                quantite: m.quantiteDisponible,
                seuil: m.seuilCritique,
                critique: m.seuilAtteint,
              ),
          ]
        : [
            for (final e in ref.watch(equipementsProvider))
              (
                nom: e.libelle,
                quantite: e.quantiteDisponible,
                seuil: e.seuilCritique,
                critique: e.seuilAtteint,
              ),
          ];
    final mouvements = ref.watch(mouvementsParFamilleProvider(famille));

    final total = articles.fold<int>(0, (s, a) => s + a.quantite);
    final critiques = articles.where((a) => a.critique).toList();

    // Les trente derniers jours : la fenêtre sur laquelle un armurier
    // raisonne, plus parlante qu'un cumul depuis l'origine.
    final depuis = DateTime.now().subtract(const Duration(days: 30));
    final recents = mouvements.where((m) => m.date.isAfter(depuis));
    final sortis = recents
        .where((m) => m.sens == SensMouvement.sortie)
        .fold<int>(0, (s, m) => s + m.quantite);
    final entres = recents
        .where((m) => m.sens == SensMouvement.entree)
        .fold<int>(0, (s, m) => s + m.quantite);

    return ListView(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 100),
      children: [
        SectionHeader(title: 'Vue d\'ensemble'),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(
              width: 240,
              child: StatCard(
                label: munitions ? 'Munitions en stock' : 'Articles en stock',
                value: formatMilliers(total),
                icon: munitions
                    ? Icons.scatter_plot_outlined
                    : Icons.shield_outlined,
                color: critiques.isEmpty
                    ? AppColors.militaryGreen
                    : AppColors.danger,
                sublabel: critiques.isEmpty
                    ? null
                    : '${critiques.length} '
                          '${munitions ? 'calibre' : 'article'}(s) critique(s)',
              ),
            ),
            SizedBox(
              width: 240,
              child: StatCard(
                label: munitions ? 'Calibres suivis' : 'Articles suivis',
                value: '${articles.length}',
                icon: Icons.inventory_2_outlined,
                color: AppColors.navy,
              ),
            ),
            SizedBox(
              width: 240,
              child: StatCard(
                label: 'Sorties sur 30 jours',
                value: formatMilliers(sortis),
                icon: Icons.arrow_upward,
                color: AppColors.ivoryOrange,
              ),
            ),
            SizedBox(
              width: 240,
              child: StatCard(
                label: 'Entrées sur 30 jours',
                value: formatMilliers(entres),
                icon: Icons.arrow_downward,
                color: AppColors.militaryGreen,
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        SectionHeader(
          title: munitions ? 'Détail par calibre' : 'Détail par article',
        ),
        if (articles.isEmpty)
          EmptyState(
            message: munitions
                ? 'Aucun calibre enregistré'
                : 'Aucun équipement enregistré',
            icon: Icons.inventory_2_outlined,
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  for (var i = 0; i < articles.length; i++) ...[
                    DotProgressRow(
                      icon: munitions
                          ? Icons.scatter_plot_outlined
                          : Icons.shield_outlined,
                      iconColor: articles[i].critique
                          ? AppColors.danger
                          : AppColors.navy,
                      title: articles[i].nom,
                      subtitle:
                          '${formatMilliers(articles[i].quantite)} en stock '
                          '· seuil ${formatMilliers(articles[i].seuil)}',
                      completed: articles[i].quantite,
                      total: total == 0 ? 1 : total,
                    ),
                    if (i != articles.length - 1) const Divider(height: 1),
                  ],
                ],
              ),
            ),
          ),
        if (critiques.isNotEmpty) ...[
          const SizedBox(height: 28),
          SectionHeader(title: 'Sous le seuil critique (${critiques.length})'),
          for (final a in critiques)
            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.danger,
                ),
                title: Text(a.nom),
                subtitle: Text(
                  '${formatMilliers(a.quantite)} en stock pour un seuil de '
                  '${formatMilliers(a.seuil)}',
                ),
              ),
            ),
        ],
      ],
    );
  }
}
