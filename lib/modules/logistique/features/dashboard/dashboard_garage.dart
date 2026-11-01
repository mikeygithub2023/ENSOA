import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sig_ensoa/core/chargement.dart';
import 'package:sig_ensoa/core/theme.dart';
import '../../data/models/oa.dart';
import '../../data/models/vehicule.dart';
import '../../data/repositories/fleet_providers.dart';
import '../../data/repositories/oa_providers.dart';
import '../../shared/widgets/dashboard_widgets.dart';
import '../../shared/widgets/skeleton.dart';
import '../../shared/widgets/widgets.dart';
import 'alertes_card.dart';

/// Le tableau de bord du garage.
///
/// Il lisait celui du chef du soutien technique : le carburant en soute, les
/// dotations d'armes, les inspections d'armement. Son parc y tenait deux
/// lignes sur douze. Il a désormais le sien — les véhicules, les vidanges,
/// les réparations —, et les tâches que l'Officier Adjoint lui confie.
class DashboardGarage extends ConsumerWidget {
  const DashboardGarage({super.key, this.sansCadre = false});

  /// Rendre le contenu nu, sans titre ni défilement propre : la page unifiée
  /// s'en charge.
  final bool sansCadre;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Les providers Riverpod sont paresseux : on les lit tous avant de
    // décider d'afficher l'attente, sans quoi le chargement ne démarrerait
    // jamais.
    final vehicules = ref.watch(vehiculesProvider);
    final vidangeRequise = ref.watch(vehiculesEnAlerteVidangeProvider);
    final reparations = ref.watch(reparationsProvider);
    final mesTaches = ref.watch(mesTachesProvider);

    if (!estCharge(ref, ['vehicules', 'reparations'])) {
      // Sans cadre, le squelette se rend nu : la page qui réunit les onglets
      // porte déjà le titre et le défilement, et un ScreenScaffold imbriqué y
      // empilerait deux zones de défilement.
      return sansCadre
          ? const SkeletonDashboard()
          : const ScreenScaffold(
              title: 'Tableau de bord',
              children: [SkeletonDashboard()],
            );
    }

    // Un véhicule hors service ne se répare plus : le compter ferait baisser
    // une disponibilité sur laquelle le garage ne peut plus rien.
    final enService = vehicules
        .where((v) => v.etat != EtatVehicule.horsService)
        .toList();
    final disponibles = enService
        .where((v) => v.etat == EtatVehicule.disponible)
        .length;
    final horsService = vehicules.length - enService.length;
    final ouvertes = reparations.where((r) => r.dateSortie == null).toList();

    // Le parc par type : c'est ainsi qu'on demande un véhicule, et ainsi
    // qu'on constate qu'il n'en reste plus d'une sorte.
    final parType = <String, int>{};
    for (final v in enService) {
      parType[v.typeVehicule] = (parType[v.typeVehicule] ?? 0) + 1;
    }
    final types = parType.entries.map((e) => (e.key, e.value)).toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));

    void versParc() => context.go('/logistique/parc');
    void versActivites() => context.go('/logistique/activites');

    final alertes = <Alerte>[
      for (final r in ouvertes)
        Alerte(
          'En réparation — ${r.pannesConstatees}',
          versParc,
          icone: Icons.car_repair_rounded,
        ),
      for (final v in vidangeRequise)
        Alerte(
          '${v.marque} ${v.modele} — vidange à prévoir',
          versParc,
          icone: Icons.oil_barrel_rounded,
        ),
      // Les tâches confiées par l'Officier Adjoint sont du travail du garage
      // au même titre qu'une panne : elles se lisent au même endroit.
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
          final jauge = GaugeCard(
            title: 'Disponibilité du parc',
            subtitle: 'Disponibles sur l\'ensemble du parc enregistré',
            progress: vehicules.isEmpty ? 0 : disponibles / vehicules.length,
            centerValue: '$disponibles/${vehicules.length}',
            centerLabel: 'dispo.',
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
      // « Parc par type » et « Suivi du garage » tiennent sur une même ligne
      // là où la largeur le permet, empilés sinon : deux lectures
      // complémentaires du parc, qu'on embrasse d'un seul regard.
      LayoutBuilder(
        builder: (context, constraints) {
          final large = constraints.maxWidth > 820;

          final parType = SoutesStockCard(
            title: 'Parc par type',
            total: enService.length,
            soutes: types,
            unite: 'vhl',
          );

          final suivi = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: 'Suivi du garage'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Column(
                    children: [
                      DotProgressRow(
                        icon: Icons.directions_car_rounded,
                        iconColor: AppColors.blue,
                        title: 'Disponibilité',
                        subtitle: 'Véhicules prêts sur le parc en service',
                        completed: disponibles,
                        total: enService.length,
                        onTap: versParc,
                      ),
                      const Divider(height: 1),
                      DotProgressRow(
                        icon: Icons.oil_barrel_rounded,
                        iconColor: AppColors.warning,
                        title: 'Entretien',
                        subtitle: 'Véhicules à jour de vidange',
                        completed: enService.length - vidangeRequise.length,
                        total: enService.length,
                        onTap: versParc,
                      ),
                      const Divider(height: 1),
                      DotProgressRow(
                        icon: Icons.car_repair_rounded,
                        iconColor: AppColors.navy,
                        title: 'Réparations',
                        subtitle: 'Interventions clôturées',
                        completed: reparations.length - ouvertes.length,
                        total: reparations.length,
                        onTap: versParc,
                      ),
                      const Divider(height: 1),
                      // Le compteur montre ce qui roule, pas ce qui est cloué :
                      // « immobilisé » affiché avec « 15/22 » se lisait à
                      // l'envers (15 étaient en service). On nomme la ligne par
                      // ce qu'elle compte vraiment.
                      DotProgressRow(
                        icon: Icons.car_crash_rounded,
                        iconColor: AppColors.danger,
                        title: 'Parc en service',
                        subtitle:
                            'Véhicules non immobilisés — $horsService hors service',
                        completed: vehicules.length - horsService,
                        total: vehicules.length,
                        onTap: versParc,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );

          if (!large) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [parType, const SizedBox(height: 24), suivi],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: parType),
              const SizedBox(width: 16),
              Expanded(child: suivi),
            ],
          );
        },
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
