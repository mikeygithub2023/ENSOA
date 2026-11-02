import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:sig_ensoa/core/chargement.dart';
import 'package:sig_ensoa/core/roles.dart';
import 'package:sig_ensoa/core/theme.dart';
import 'package:sig_ensoa/modules/logistique/compat.dart';
import '../../data/models/maintenance.dart';
import '../../data/models/pannes.dart';
import '../../data/models/vehicule.dart';
import '../../data/repositories/fleet_providers.dart';
import '../../shared/widgets/widgets.dart';
import 'retour_sur_base_dialog.dart';

/// L'onglet des véhicules admis en réparation.
///
/// Chaque réparation ouverte y tient sa carte : le véhicule, depuis quand il
/// est au garage, les pannes qu'il y a apportées. Le retour sur base s'y
/// valide — les pannes réparées cochées, celles décelées en chemin
/// consignées, l'état au retour constaté. Les plus anciennes passent devant :
/// ce sont elles qui immobilisent le parc depuis le plus longtemps.
class ReparationsTab extends ConsumerWidget {
  const ReparationsTab({super.key});

  /// Ceux qui écrivent dans le garage — les mêmes que la base autorise.
  static const _peuventValider = {
    RoleLogistique.garage,
    RoleLogistique.chefSoutienTechnique,
    RoleLogistique.administrateur,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final charge = estCharge(ref, [
      'reparations',
      'vehicules',
      'pannes',
      'demandes_reparation',
    ]);
    final ouvertes =
        ref.watch(reparationsProvider).where((r) => !r.cloturee).toList()
          ..sort((a, b) => a.dateEntree.compareTo(b.dateEntree));
    final parId = {for (final v in ref.watch(vehiculesProvider)) v.id: v};
    final peutValider = _peuventValider.contains(
      ref.watch(sessionProvider)?.user.role,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!charge)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (ouvertes.isEmpty)
            const EmptyState(
              message:
                  'Aucun véhicule en réparation. Un véhicule y entre '
                  'quand sa demande de mise en réparation est validée.',
              icon: Icons.car_repair_outlined,
            )
          else
            for (final r in ouvertes)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _CarteReparation(
                  reparation: r,
                  vehicule: parId[r.vehiculeId],
                  peutValider: peutValider,
                ),
              ),
        ],
      ),
    );
  }
}

class _CarteReparation extends ConsumerWidget {
  const _CarteReparation({
    required this.reparation,
    required this.vehicule,
    required this.peutValider,
  });

  final Reparation reparation;
  final Vehicule? vehicule;
  final bool peutValider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = vehicule;
    final pannes = pannesDeLaReparation(ref, reparation);
    final jours = DateTime.now().difference(reparation.dateEntree).inDays;
    final depuis = jours == 0
        ? 'Entré aujourd\'hui'
        : jours == 1
        ? 'Au garage depuis 1 jour'
        : 'Au garage depuis $jours jours';
    final details = [
      'Entré le ${DateFormat('dd/MM/yyyy').format(reparation.dateEntree)}',
      if (reparation.lieu != null) reparation.lieu!,
      if (reparation.chefEquipe != null)
        'Chef d\'équipe : ${reparation.chefEquipe}',
    ].join(' · ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    v == null
                        ? 'Véhicule retiré du parc'
                        : '${v.marque} ${v.modele} — ${v.immatriculation}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _Pastille(
                  texte: depuis,
                  couleur: jours >= 7 ? AppColors.danger : AppColors.warning,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              v == null ? details : '${v.typeVehicule} · $details',
              style: const TextStyle(fontSize: 12, color: AppColors.inkMuted),
            ),
            const SizedBox(height: 10),
            if (pannes.isEmpty)
              Text(
                reparation.pannesConstatees,
                style: const TextStyle(fontSize: 13),
              )
            else
              for (final p in pannes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '•  [${p.gravite.label}] ${p.description}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
            if (peutValider && v != null) ...[
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => RetourSurBaseDialog(
                      reparation: reparation,
                      vehicule: v,
                    ),
                  ),
                  icon: const Icon(Icons.assignment_return_outlined),
                  label: const Text('Valider le retour sur base'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Pastille extends StatelessWidget {
  const _Pastille({required this.texte, required this.couleur});

  final String texte;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        texte,
        style: TextStyle(
          color: couleur,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}
