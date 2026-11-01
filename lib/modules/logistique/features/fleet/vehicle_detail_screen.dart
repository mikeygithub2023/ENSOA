import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:sig_ensoa/core/theme.dart';
import 'package:sig_ensoa/core/chargement.dart';
import '../../data/models/mouvement_vehicule.dart';
import '../../data/models/vehicule.dart';
import '../../data/repositories/fleet_providers.dart';
import '../../shared/widgets/skeleton.dart';
import '../../shared/widgets/widgets.dart';
import 'close_repair_dialog.dart';
import 'mouvement_form_dialog.dart';
import 'repair_form_dialog.dart';
import 'vehicle_form_dialog.dart';
import 'vidange_form_dialog.dart';

class VehicleDetailScreen extends ConsumerStatefulWidget {
  final Vehicule vehicule;
  const VehicleDetailScreen({super.key, required this.vehicule});

  @override
  ConsumerState<VehicleDetailScreen> createState() =>
      _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends ConsumerState<VehicleDetailScreen> {
  bool _suppressionEnCours = false;

  Future<void> _confirmerSuppression(Vehicule current) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Supprimer le véhicule'),
        content: Text(
          '${current.marque} ${current.modele} (${current.immatriculation}) sera retiré du parc actif. '
          'Son historique (réparations, vidanges, mouvements) reste conservé.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirme != true || !mounted) return;
    setState(() => _suppressionEnCours = true);
    try {
      await ref.read(vehiculesProvider.notifier).supprimer(current.id);
      if (mounted) {
        showSuccessSnackBar(context, 'Véhicule supprimé avec succès.');
        context.go('/logistique/parc');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _suppressionEnCours = false);
        showErrorSnackBar(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicule = widget.vehicule;
    final vehicules = ref.watch(vehiculesProvider);
    final current = vehicules.firstWhere(
      (v) => v.id == vehicule.id,
      orElse: () => vehicule,
    );
    final reparations = ref
        .watch(reparationsProvider)
        .where((r) => r.vehiculeId == current.id)
        .toList();
    final vidanges = ref
        .watch(vidangesProvider)
        .where((v) => v.vehiculeId == current.id)
        .toList();
    final trajets = ref
        .watch(mouvementsVehiculeProvider)
        .where((m) => m.vehiculeId == current.id)
        .toList();
    final charge = estCharge(ref, ['reparations', 'vidanges', 'mouvements']);
    final df = DateFormat('dd/MM/yyyy');
    final peutDemarrerMouvement =
        current.etat == EtatVehicule.disponible &&
        current.positionActuelle == 'Garage central ENSOA';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => context.go('/logistique/parc'),
                  icon: const Icon(Icons.arrow_back),
                ),
                const SizedBox(width: 8),
                Text(
                  '${current.marque} ${current.modele}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 12),
                StatusChip(
                  label: current.etat.label,
                  level: current.etat == EtatVehicule.horsService
                      ? AlertLevel.critical
                      : AlertLevel.info,
                ),
                if (current.vidangeRequise) ...[
                  const SizedBox(width: 8),
                  const StatusChip(
                    label: 'Vidange à prévoir',
                    level: AlertLevel.warning,
                  ),
                ],
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => VehicleFormDialog(vehicule: current),
                  ),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Modifier'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _suppressionEnCours
                      ? null
                      : () => _confirmerSuppression(current),
                  icon: _suppressionEnCours
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(
                          Icons.delete_outline,
                          color: AppColors.danger,
                        ),
                  label: const Text(
                    'Supprimer',
                    style: TextStyle(color: AppColors.danger),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.danger),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _infoTile(
                  context,
                  Icons.confirmation_number_outlined,
                  'Immatriculation',
                  current.immatriculation,
                ),
                _infoTile(
                  context,
                  Icons.pin_outlined,
                  'N° châssis',
                  current.chassis,
                ),
                _infoTile(
                  context,
                  Icons.category_outlined,
                  'Type',
                  current.typeVehicule,
                ),
                _infoTile(
                  context,
                  Icons.speed,
                  'Kilométrage',
                  '${current.kilometrage} km',
                ),
                _infoTile(
                  context,
                  Icons.event_repeat_outlined,
                  'Prochaine vidange',
                  '${current.kilometrageVidangeProchaine} km',
                ),
                _infoTile(
                  context,
                  Icons.event_seat_outlined,
                  'Places',
                  '${current.nbrePlaces}',
                ),
                _infoTile(
                  context,
                  Icons.place_outlined,
                  'Position actuelle',
                  current.positionActuelle ?? '—',
                ),
              ],
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => RepairFormDialog(vehicule: current),
                  ),
                  icon: const Icon(Icons.build_outlined),
                  label: const Text('Déclarer une réparation'),
                ),
                OutlinedButton.icon(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => VidangeFormDialog(vehicule: current),
                  ),
                  icon: const Icon(Icons.oil_barrel_outlined),
                  label: const Text('Enregistrer une vidange'),
                ),
                if (peutDemarrerMouvement)
                  OutlinedButton.icon(
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => MouvementFormDialog(vehicule: current),
                    ),
                    icon: const Icon(Icons.route_outlined),
                    label: const Text('Créer un mouvement'),
                  ),
              ],
            ),
            // L'ordre suit la vie du véhicule : ce qu'il a fait (ses missions),
            // son entretien courant (les vidanges), puis l'exceptionnel (les
            // réparations).
            const SizedBox(height: 32),
            SectionHeader(
              title: 'Missions effectuées (${charge ? trajets.length : '…'})',
            ),
            if (!charge) const SkeletonList(itemCount: 2),
            if (charge && trajets.isEmpty)
              const EmptyState(message: 'Aucune mission effectuée'),
            if (charge)
              for (final m in trajets)
                Card(
                  child: ListTile(
                    leading: Icon(
                      Icons.route_outlined,
                      color: m.etat == EtatMouvement.enCours
                          ? AppColors.ivoryOrange
                          : AppColors.success,
                    ),
                    title: Text('${m.objet} — ${m.destination}'),
                    subtitle: Text(
                      '${df.format(m.dateDepart)} · conducteur ${m.nomChefBord}'
                      '${m.kmArrivee != null ? ' · ${m.kmArrivee! - m.kmDepart} km parcourus' : ''}',
                    ),
                    trailing: StatusChip(
                      label: m.etat == EtatMouvement.enCours
                          ? 'En cours (poste de police)'
                          : m.etat.label,
                      level: m.etat == EtatMouvement.enCours
                          ? AlertLevel.warning
                          : AlertLevel.info,
                    ),
                  ),
                ),
            const SizedBox(height: 32),
            SectionHeader(
              title:
                  'Historique des vidanges (${charge ? vidanges.length : '…'})',
            ),
            if (!charge) const SkeletonList(itemCount: 2),
            if (charge && vidanges.isEmpty)
              const EmptyState(message: 'Aucune vidange enregistrée'),
            if (charge)
              for (final v in vidanges)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.oil_barrel_outlined),
                    title: Text('${v.typeHuile} — ${v.qteHuile} L'),
                    subtitle: Text(
                      '${df.format(v.date)}${v.filtreVidange != null ? ' · ${v.filtreVidange}' : ''}',
                    ),
                  ),
                ),
            const SizedBox(height: 32),
            SectionHeader(
              title:
                  'Historique des réparations (${charge ? reparations.length : '…'})',
            ),
            if (!charge) const SkeletonList(itemCount: 2),
            if (charge && reparations.isEmpty)
              const EmptyState(message: 'Aucune réparation enregistrée'),
            if (charge)
              for (final r in reparations)
                Card(
                  child: ListTile(
                    leading: Icon(
                      Icons.build,
                      color: r.cloturee ? AppColors.success : AppColors.warning,
                    ),
                    title: Text(r.pannesConstatees),
                    subtitle: Text(
                      '${df.format(r.dateEntree)}'
                      '${r.chefEquipe != null ? ' — ${r.chefEquipe}' : ''}'
                      '${r.lieu != null ? '\nLieu : ${r.lieu}' : ''}'
                      '${r.solutionsApportees != null ? '\nSolution : ${r.solutionsApportees}' : ''}',
                    ),
                    isThreeLine: r.lieu != null || r.solutionsApportees != null,
                    trailing: r.cloturee
                        ? const StatusChip(
                            label: 'Clôturée',
                            level: AlertLevel.info,
                          )
                        : OutlinedButton(
                            onPressed: () => showDialog(
                              context: context,
                              builder: (_) => CloseRepairDialog(
                                reparation: r,
                                vehicule: current,
                              ),
                            ),
                            child: const Text('Clôturer'),
                          ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _infoTile(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
