import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:sig_ensoa/modules/logistique/compat.dart';
import 'package:sig_ensoa/core/theme.dart';
import 'package:sig_ensoa/core/chargement.dart';
import '../../data/models/mouvement_vehicule.dart';
import '../../data/models/vehicule.dart';
import '../../data/repositories/fleet_providers.dart';
import '../../data/repositories/misc_providers.dart';
import '../../data/repositories/police_providers.dart';
import '../../shared/widgets/skeleton.dart';
import '../../shared/widgets/widgets.dart';
import 'retour_vehicule_dialog.dart';

enum _FiltrePassage { autorises, horsCamp, rentres }

/// Le poste de police ne décide plus lui-même quel véhicule sort : il valide
/// le franchissement physique du portail pour un mouvement déjà autorisé par
/// le Garage ("Autorisés à sortir"), puis suit son retour ("Hors du camp").
class VehiculesTabContent extends ConsumerStatefulWidget {
  const VehiculesTabContent({super.key});

  @override
  ConsumerState<VehiculesTabContent> createState() =>
      _VehiculesTabContentState();
}

class _VehiculesTabContentState extends ConsumerState<VehiculesTabContent> {
  _FiltrePassage _filtre = _FiltrePassage.autorises;
  final Set<String> _sortiesEnCours = {};

  Future<void> _enregistrerSortie(MouvementVehicule m, Vehicule v) async {
    setState(() => _sortiesEnCours.add(m.id));
    final user = ref.read(sessionProvider)?.user;
    try {
      await ref
          .read(passagesVehiculesProvider.notifier)
          .enregistrerSortie(
            vehiculeId: v.id,
            mouvementId: m.id,
            enregistrePar: user!.id,
          );
      ref
          .read(auditProvider.notifier)
          .log(
            auteurId: user.id,
            action: 'VEHICULE_SORTI_CAMP',
            cible: v.immatriculation,
            detail: m.destination,
          );
      if (mounted) {
        showSuccessSnackBar(context, 'Sortie enregistrée avec succès.');
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, e);
      }
    } finally {
      if (mounted) setState(() => _sortiesEnCours.remove(m.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final charge = estCharge(ref, [
      'passages_vehicules',
      'vehicules',
      'mouvements',
    ]);
    final vehicules = ref.watch(vehiculesProvider);
    final mouvements = ref.watch(mouvementsVehiculeProvider);
    final passages = List.of(ref.watch(passagesVehiculesProvider))
      ..sort((a, b) => b.dateSortie.compareTo(a.dateSortie));
    final df = DateFormat('dd/MM/yyyy HH:mm');

    if (!charge) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(4, 4, 4, 100),
        child: SkeletonList(itemCount: 4),
      );
    }

    Vehicule? vehiculeDe(String id) {
      for (final v in vehicules) {
        if (v.id == id) return v;
      }
      return null;
    }

    // Mouvements en cours côté Garage n'ayant pas encore de passage — la sortie
    // physique reste à valider par le poste de police.
    final idsMouvementsDejaValides = passages.map((p) => p.mouvementId).toSet();
    final autorises = mouvements
        .where(
          (m) =>
              m.etat == EtatMouvement.enCours &&
              !idsMouvementsDejaValides.contains(m.id),
        )
        .toList();

    Widget content;
    switch (_filtre) {
      case _FiltrePassage.autorises:
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(title: 'Autorisés à sortir (${autorises.length})'),
            if (autorises.isEmpty)
              const EmptyState(
                message: 'Aucun mouvement en attente de validation',
              ),
            for (final m in autorises) ...[
              Builder(
                builder: (context) {
                  final v = vehiculeDe(m.vehiculeId);
                  return Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.blueMist,
                        child: Icon(
                          Icons.directions_car_outlined,
                          color: AppColors.blueDeep,
                        ),
                      ),
                      title: Text(
                        v != null
                            ? '${v.immatriculation} — ${v.marque} ${v.modele}'
                            : 'Véhicule inconnu',
                      ),
                      subtitle: Text(
                        '${m.objet} vers ${m.destination} · Chef de bord ${m.nomChefBord} · Autorisé le ${df.format(m.dateDepart)}',
                      ),
                      isThreeLine: true,
                      trailing: v == null
                          ? null
                          : OutlinedButton(
                              onPressed: _sortiesEnCours.contains(m.id)
                                  ? null
                                  : () => _enregistrerSortie(m, v),
                              child: _sortiesEnCours.contains(m.id)
                                  ? const SizedBox(
                                      height: 16,
                                      width: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Enregistrer la sortie'),
                            ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
            ],
          ],
        );
      case _FiltrePassage.horsCamp:
      case _FiltrePassage.rentres:
        final horsCamp = _filtre == _FiltrePassage.horsCamp;
        final aujourdhui = DateTime.now();
        final filtres = passages.where((p) {
          if (horsCamp) return p.enCours;
          return !p.enCours &&
              p.dateRetour != null &&
              p.dateRetour!.year == aujourdhui.year &&
              p.dateRetour!.month == aujourdhui.month &&
              p.dateRetour!.day == aujourdhui.day;
        }).toList();
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title:
                  '${horsCamp ? 'Hors du camp' : 'Rentrés ce jour'} (${filtres.length})',
            ),
            if (filtres.isEmpty)
              const EmptyState(message: 'Aucun passage pour ce filtre'),
            for (final p in filtres) ...[
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        (p.enCours ? AppColors.ivoryOrange : AppColors.success)
                            .withValues(alpha: 0.12),
                    child: Icon(
                      p.enCours ? Icons.arrow_upward : Icons.arrow_downward,
                      color: p.enCours
                          ? AppColors.ivoryOrange
                          : AppColors.success,
                    ),
                  ),
                  title: Text(
                    vehiculeDe(p.vehiculeId) != null
                        ? '${vehiculeDe(p.vehiculeId)!.immatriculation} — ${vehiculeDe(p.vehiculeId)!.marque} ${vehiculeDe(p.vehiculeId)!.modele}'
                        : 'Véhicule inconnu',
                  ),
                  subtitle: Text(
                    'Sortie le ${df.format(p.dateSortie)}'
                    '${p.dateRetour != null ? ' · Retour le ${df.format(p.dateRetour!)} (${p.kmRetour} km)' : ''}',
                  ),
                  trailing: p.enCours
                      ? OutlinedButton(
                          onPressed: vehiculeDe(p.vehiculeId) == null
                              ? null
                              : () => showDialog(
                                  context: context,
                                  builder: (_) => RetourVehiculeDialog(
                                    passage: p,
                                    vehicule: vehiculeDe(p.vehiculeId)!,
                                  ),
                                ),
                          child: const Text('Enregistrer le retour'),
                        )
                      : StatusChip(label: 'Rentré', level: AlertLevel.info),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 100),
      children: [
        Wrap(
          spacing: 8,
          children: [
            FilterChipPill(
              label: 'Autorisés à sortir (${autorises.length})',
              selected: _filtre == _FiltrePassage.autorises,
              onTap: () => setState(() => _filtre = _FiltrePassage.autorises),
            ),
            FilterChipPill(
              label: 'Hors du camp',
              selected: _filtre == _FiltrePassage.horsCamp,
              onTap: () => setState(() => _filtre = _FiltrePassage.horsCamp),
            ),
            FilterChipPill(
              label: 'Rentrés ce jour',
              selected: _filtre == _FiltrePassage.rentres,
              onTap: () => setState(() => _filtre = _FiltrePassage.rentres),
            ),
          ],
        ),
        const SizedBox(height: 16),
        content,
      ],
    );
  }
}
