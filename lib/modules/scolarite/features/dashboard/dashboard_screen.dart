import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sig_ensoa/core/erreurs.dart';

import 'package:sig_ensoa/modules/scolarite/compat.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/kpi_card.dart';
import 'providers/dashboard_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key, this.sansCadre = false});

  /// Rendre le contenu nu, sans titre ni défilement propre : la page unifiée
  /// s'en charge quand elle réunit les deux domaines.
  final bool sansCadre;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).value;

    if (profile?.role == AppRole.eleveStagiaire) {
      return const _EleveDashboard();
    }

    final statsAsync = ref.watch(dashboardStatsProvider);

    final contenu = <Widget>[
          if (!sansCadre) ...[
            Text("Vue d'ensemble", style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
          ],
          statsAsync.when(
            // Les cartes occupent toute la largeur : à quatre par rangée sur
            // le poste de travail, à deux sur la tablette en paysage, elles
            // se partagent l'espace au lieu de laisser une bande vide à
            // droite. La largeur minimale de 240 décide seulement du nombre
            // qui tient sur une ligne.
            data: (stats) => LayoutBuilder(
              builder: (context, contraintes) {
                final cartes = <(String, String, String, IconData)>[
                  (
                    'Effectif total',
                    '${stats.total}',
                    'Élèves & stagiaires',
                    Icons.groups_outlined,
                  ),
                  for (final entry in stats.parDivision)
                    (
                      entry.division.nom,
                      '${entry.count}',
                      'Effectif',
                      Icons.school_outlined,
                    ),
                ];

                const espace = 16.0;
                final large = contraintes.maxWidth;
                var parRangee = ((large + espace) / (240 + espace)).floor();
                if (parRangee < 1) parRangee = 1;
                if (parRangee > cartes.length) parRangee = cartes.length;
                final largeur =
                    (large - espace * (parRangee - 1)) / parRangee;

                return Wrap(
                  spacing: espace,
                  runSpacing: espace,
                  children: [
                    for (final (titre, valeur, sousTitre, icone) in cartes)
                      SizedBox(
                        width: largeur,
                        child: KpiCard(
                          titre: titre,
                          valeur: valeur,
                          sousTitre: sousTitre,
                          icone: icone,
                        ),
                      ),
                  ],
                );
              },
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => EmptyState(
              message: 'Erreur de chargement : ${messageErreur(error)}',
              icon: Icons.error_outline,
            ),
          ),
    ];

    // Sans cadre, on rend la suite de blocs telle quelle : c'est la page
    // unifiée qui porte le défilement, pour que scolarité et soutien
    // technique se lisent d'un seul mouvement.
    return sansCadre
        ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: contenu)
        : SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: contenu,
            ),
          );
  }
}

class _EleveDashboard extends StatelessWidget {
  const _EleveDashboard();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EmptyState(
            message:
                'Retrouvez votre profil et votre carrière dans « Mon profil ».',
            icon: Icons.badge_outlined,
          ),
        ],
      ),
    );
  }
}
