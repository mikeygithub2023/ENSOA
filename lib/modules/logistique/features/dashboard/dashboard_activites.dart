import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:sig_ensoa/core/chargement.dart';
import 'package:sig_ensoa/core/theme.dart';
import '../../data/models/oa.dart';
import '../../data/repositories/oa_providers.dart';
import '../../shared/widgets/dashboard_widgets.dart';
import '../../shared/widgets/skeleton.dart';
import '../../shared/widgets/widgets.dart';
import 'alertes_card.dart';

/// Le tableau de bord de l'Officier Adjoint.
///
/// Il relève du soutien technique sans en tenir aucun service : il monte les
/// activités de l'école et vise les tâches que les services déclarent faites.
/// La disponibilité du parc et le carburant en soute ne lui apprenaient rien.
/// Son accueil avait déjà été séparé ; son tableau de bord ne l'était pas.
class DashboardActivites extends ConsumerWidget {
  const DashboardActivites({super.key, this.sansCadre = false});

  /// Rendre le contenu nu, sans titre ni défilement propre : la page unifiée
  /// s'en charge.
  final bool sansCadre;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activites = ref.watch(activitesProvider);
    final taches = ref.watch(tachesProvider);
    final aValider = ref.watch(tachesEnAttenteValidationProvider);

    if (!estCharge(ref, ['activites', 'taches'])) {
      return const ScreenScaffold(
        title: 'Tableau de bord',
        children: [SkeletonDashboard()],
      );
    }

    // Une activité annulée et ses tâches ne comptent plus : il n'y a plus
    // rien à faire, ni rien à viser.
    final vivantes = activites
        .where((a) => a.statut != StatutActivite.annulee)
        .toList();
    final enCours = vivantes
        .where((a) => a.statut != StatutActivite.terminee)
        .length;
    final aVenir =
        vivantes.where((a) => a.dateActivite.isAfter(DateTime.now())).toList()
          ..sort((a, b) => a.dateActivite.compareTo(b.dateActivite));

    final suivies = taches
        .where((t) => t.statut != StatutTache.annulee)
        .toList();
    final visees = suivies.where((t) => t.statut == StatutTache.validee).length;
    final enRetard = suivies.where((t) => t.enRetard).toList();

    // Ce que chaque service porte encore : c'est la seule répartition sur
    // laquelle il peut relancer quelqu'un.
    final parActeur = <String, int>{};
    for (final t in suivies) {
      if (t.statut == StatutTache.validee) continue;
      parActeur[t.acteur.label] = (parActeur[t.acteur.label] ?? 0) + 1;
    }
    final services = parActeur.entries.map((e) => (e.key, e.value)).toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));
    final restantes = parActeur.values.fold<int>(0, (s, n) => s + n);

    final jour = DateFormat('dd/MM');
    void versActivites() => context.go('/logistique/activites');

    final alertes = <Alerte>[
      for (final t in aValider)
        Alerte(
          'À viser : ${t.description}',
          versActivites,
          icone: Icons.how_to_reg_rounded,
        ),
      for (final t in enRetard)
        Alerte(
          'En retard — ${t.description}',
          versActivites,
          icone: Icons.schedule_rounded,
        ),
      for (final a in aVenir.take(3))
        Alerte(
          '${jour.format(a.dateActivite)} — ${a.titre}',
          versActivites,
          icone: Icons.event_rounded,
        ),
    ];

    final contenu = <Widget>[
      LayoutBuilder(
        builder: (context, constraints) {
          final large = constraints.maxWidth > 820;
          final jauge = GaugeCard(
            title: 'Tâches visées',
            subtitle: 'Clôturées sur celles qui restent suivies',
            progress: suivies.isEmpty ? 0 : visees / suivies.length,
            centerValue: '$visees/${suivies.length}',
            centerLabel: 'visées',
            color: AppColors.success,
          );
          final alerte = AlertesCard(alertes: alertes, titre: 'À traiter');
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
        title: 'Tâches restantes par service',
        total: restantes,
        soutes: services,
        unite: 'tâches',
      ),
      const SizedBox(height: 24),
      const SectionHeader(title: 'Suivi des activités'),
      Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              DotProgressRow(
                icon: Icons.event_available_rounded,
                iconColor: AppColors.blue,
                title: 'Activités',
                subtitle: 'Terminées sur celles qui tiennent',
                completed: vivantes.length - enCours,
                total: vivantes.length,
                onTap: versActivites,
              ),
              const Divider(height: 1),
              DotProgressRow(
                icon: Icons.verified_rounded,
                iconColor: AppColors.success,
                title: 'Validations',
                subtitle: 'Tâches rendues et visées',
                completed: visees,
                total: visees + aValider.length,
                onTap: versActivites,
              ),
              const Divider(height: 1),
              DotProgressRow(
                icon: Icons.schedule_rounded,
                iconColor: AppColors.warning,
                title: 'Délais',
                subtitle: 'Tâches encore dans les temps',
                completed: suivies.length - enRetard.length,
                total: suivies.length,
                onTap: versActivites,
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
