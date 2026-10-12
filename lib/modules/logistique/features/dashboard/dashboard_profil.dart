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

/// Le tableau de bord d'un service créé par l'administrateur.
///
/// Ces profils existent pour recevoir du travail, non pour ouvrir l'ERP :
/// leur tableau ne montre donc que ce qu'on leur a confié, rangé par
/// activité. Une tâche lue hors de son activité ne dit pas grand-chose —
/// « monter la tribune » se comprend quand on sait que c'est pour la prise
/// d'armes de jeudi.
class DashboardProfilPersonnalise extends ConsumerWidget {
  const DashboardProfilPersonnalise({super.key, this.sansCadre = false});

  /// Rendre le contenu nu, sans titre ni défilement propre : la page unifiée
  /// s'en charge.
  final bool sansCadre;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taches = ref.watch(mesTachesProvider);
    final activites = ref.watch(activitesProvider);

    if (!estCharge(ref, ['activites', 'taches'])) {
      return const ScreenScaffold(
        title: 'Tableau de bord',
        children: [SkeletonDashboard()],
      );
    }

    // Une tâche annulée ne demande plus rien : son activité a été annulée, et
    // la compter ferait croire à du retard sur du travail qui n'existe plus.
    final vivantes = taches
        .where((t) => t.statut != StatutTache.annulee)
        .toList();
    final aFaire = vivantes
        .where((t) => t.statut == StatutTache.aFaire)
        .toList();
    final rendues = vivantes
        .where((t) => t.statut == StatutTache.terminee)
        .length;
    final visees = vivantes
        .where((t) => t.statut == StatutTache.validee)
        .length;
    final enRetard = aFaire.where((t) => t.enRetard).toList();

    final titres = {for (final a in activites) a.id: a};
    final jour = DateFormat('dd/MM');

    void versMesTaches() => context.go('/logistique/mes-taches');

    final alertes = <Alerte>[
      for (final t in enRetard)
        Alerte(
          'En retard — ${t.description}',
          versMesTaches,
          icone: Icons.schedule_rounded,
        ),
      for (final t in aFaire.where((t) => !t.enRetard))
        Alerte(
          t.dateLimite == null
              ? t.description
              : '${jour.format(t.dateLimite!)} — ${t.description}',
          versMesTaches,
          icone: Icons.assignment_turned_in_rounded,
        ),
    ];

    // Le travail restant, rangé sous l'activité qui l'a demandé.
    final parActivite = <String, List<TacheActivite>>{};
    for (final t in vivantes.where((t) => t.statut != StatutTache.validee)) {
      parActivite.putIfAbsent(t.activiteId, () => []).add(t);
    }
    final groupes = parActivite.entries.toList()
      ..sort((a, b) {
        final da = titres[a.key]?.dateActivite;
        final db = titres[b.key]?.dateActivite;
        if (da == null || db == null) return 0;
        return da.compareTo(db);
      });

    final contenu = <Widget>[
      LayoutBuilder(
        builder: (context, constraints) {
          final large = constraints.maxWidth > 820;
          final jauge = GaugeCard(
            title: 'Travail rendu',
            subtitle: 'Tâches rendues ou visées',
            progress: vivantes.isEmpty
                ? 0
                : (rendues + visees) / vivantes.length,
            centerValue: '${rendues + visees}/${vivantes.length}',
            centerLabel: 'rendues',
            color: AppColors.success,
          );
          final alerte = AlertesCard(alertes: alertes, titre: 'À faire');
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
      const SizedBox(height: 24),
      const SectionHeader(title: 'Par activité'),
      if (groupes.isEmpty)
        const Card(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: EmptyState(
              message: 'Aucune tâche en cours. Tout est rendu.',
              icon: Icons.task_alt_rounded,
            ),
          ),
        ),
      for (final groupe in groupes) ...[
        _CarteActivite(
          activite: titres[groupe.key],
          taches: groupe.value,
          onTap: versMesTaches,
        ),
        const SizedBox(height: 12),
      ],
    ];

    return sansCadre
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: contenu,
          )
        : ScreenScaffold(title: 'Tableau de bord', children: contenu);
  }
}

/// Une activité et ce qu'elle demande à ce service.
class _CarteActivite extends StatelessWidget {
  const _CarteActivite({
    required this.activite,
    required this.taches,
    required this.onTap,
  });

  /// Nulle si l'activité n'est pas lisible — la RLS n'ouvre que celles dont
  /// une tâche lui revient, et une tâche peut survivre à son activité.
  final Activite? activite;

  final List<TacheActivite> taches;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final jour = DateFormat('EEEE d MMMM', 'fr_FR');
    final a = activite;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.event_note_rounded,
                    size: 20,
                    color: AppColors.blueDeep,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      a?.titre ?? 'Activité retirée',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  if (a != null)
                    Text(
                      jour.format(a.dateActivite),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.inkMuted,
                      ),
                    ),
                ],
              ),
              if (a?.lieu != null && a!.lieu!.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 30),
                  child: Text(
                    a.lieu!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              for (final t in taches)
                Padding(
                  padding: const EdgeInsets.only(left: 30, bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        t.statut == StatutTache.terminee
                            ? Icons.hourglass_bottom_rounded
                            : t.enRetard
                            ? Icons.error_outline_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: 16,
                        color: t.statut == StatutTache.terminee
                            ? AppColors.warning
                            : t.enRetard
                            ? AppColors.danger
                            : AppColors.inkMuted,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          t.description,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      Text(
                        t.statut.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: t.statut == StatutTache.terminee
                              ? AppColors.warning
                              : AppColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
