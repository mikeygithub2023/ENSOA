import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sig_ensoa/core/theme.dart';
import 'package:sig_ensoa/core/chargement.dart';
import '../../data/models/vehicule.dart';
import '../../data/repositories/fleet_providers.dart';
import '../../shared/widgets/skeleton.dart';
import '../../shared/widgets/widgets.dart';
import 'vehicle_form_dialog.dart';

class FleetScreen extends ConsumerStatefulWidget {
  const FleetScreen({super.key});

  @override
  ConsumerState<FleetScreen> createState() => _FleetScreenState();
}

class _FleetScreenState extends ConsumerState<FleetScreen> {
  EtatVehicule? _filtre;

  @override
  Widget build(BuildContext context) {
    final charge = estCharge(ref, ['vehicules']);
    final vehicules = ref.watch(vehiculesProvider);
    final filtres = _filtre == null
        ? vehicules
        : vehicules.where((v) => v.etat == _filtre).toList();

    return ScreenScaffold(
      title: 'Parc automobile',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDialog(
          context: context,
          builder: (_) => const VehicleFormDialog(),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Nouveau véhicule'),
      ),
      children: [
        Wrap(
          spacing: 8,
          children: [
            FilterChipPill(
              label: 'Tous',
              selected: _filtre == null,
              onTap: () => setState(() => _filtre = null),
            ),
            for (final e in EtatVehicule.values)
              FilterChipPill(
                label: e.label,
                selected: _filtre == e,
                onTap: () => setState(() => _filtre = e),
              ),
          ],
        ),
        const SizedBox(height: 20),
        if (!charge)
          const SkeletonGrid(
            itemCount: 6,
            maxCrossAxisExtent: 340,
            mainAxisExtent: 160,
          ),
        if (charge && filtres.isEmpty)
          const EmptyState(message: 'Aucun véhicule pour ce filtre'),
        if (charge)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filtres.length,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 340,
              mainAxisExtent: 160,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemBuilder: (context, i) {
              final v = filtres[i];
              return Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => context.go('/logistique/parc/detail', extra: v),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '${v.marque} ${v.modele}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            StatusChip(
                              label: v.etat.label,
                              level: _levelFor(v.etat),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          v.immatriculation,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            const Icon(Icons.speed, size: 16),
                            const SizedBox(width: 4),
                            Text('${v.kilometrage} km'),
                            const SizedBox(width: 16),
                            if (v.positionActuelle != null) ...[
                              const Icon(Icons.groups_outlined, size: 16),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  v.positionActuelle!,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  AlertLevel _levelFor(EtatVehicule e) {
    switch (e) {
      case EtatVehicule.disponible:
        return AlertLevel.info;
      case EtatVehicule.enMission:
        return AlertLevel.info;
      case EtatVehicule.enReparation:
        return AlertLevel.warning;
      case EtatVehicule.horsService:
        return AlertLevel.critical;
    }
  }
}
