import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:sig_ensoa/modules/logistique/compat.dart';
import 'package:sig_ensoa/core/theme.dart';
import 'package:sig_ensoa/core/chargement.dart';
import '../../data/models/armement.dart';
import '../../data/repositories/armament_providers.dart';
import '../../data/repositories/misc_providers.dart';
import '../../shared/widgets/skeleton.dart';
import '../../shared/widgets/widgets.dart';
import 'dotation_form_dialog.dart';
import 'weapon_form_dialog.dart';

class WeaponDetailScreen extends ConsumerStatefulWidget {
  final Arme arme;
  const WeaponDetailScreen({super.key, required this.arme});

  @override
  ConsumerState<WeaponDetailScreen> createState() => _WeaponDetailScreenState();
}

class _WeaponDetailScreenState extends ConsumerState<WeaponDetailScreen> {
  bool _retourEnCours = false;

  Future<void> _enregistrerRetour(DotationArme enCours, Arme current) async {
    setState(() => _retourEnCours = true);
    final user = ref.read(sessionProvider)?.user;
    try {
      await ref
          .read(dotationsProvider.notifier)
          .enregistrerRetour(enCours.id, current.id);
      if (user != null) {
        ref
            .read(auditProvider.notifier)
            .log(
              auteurId: user.id,
              action: 'ARME_RETOURNEE',
              cible: current.numeroSerie,
              detail: 'Retour de ${enCours.beneficiaireId}',
            );
      }
      if (mounted) {
        showSuccessSnackBar(context, 'Retour enregistré avec succès.');
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, e);
      }
    } finally {
      if (mounted) setState(() => _retourEnCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final armes = ref.watch(armesProvider);
    final current = armes.firstWhere(
      (a) => a.id == widget.arme.id,
      orElse: () => widget.arme,
    );
    final dotations =
        ref
            .watch(dotationsProvider)
            .where((d) => d.armeId == current.id)
            .toList()
          ..sort((a, b) => b.dateRemise.compareTo(a.dateRemise));
    final charge = estCharge(ref, ['armes', 'dotations_armes']);
    final enCours = dotations.where((d) => d.enCours).isEmpty
        ? null
        : dotations.firstWhere((d) => d.enCours);
    final df = DateFormat('dd/MM/yyyy');

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
                  onPressed: () => context.go('/logistique/armement'),
                  icon: const Icon(Icons.arrow_back),
                ),
                const SizedBox(width: 8),
                Text(
                  current.designationComplete,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 12),
                StatusChip(
                  label: current.etat.label,
                  level: current.etat == EtatArme.defectueux
                      ? AlertLevel.critical
                      : (current.inspectionEnRetard
                            ? AlertLevel.warning
                            : AlertLevel.info),
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
                  'Numéro de série',
                  current.numeroSerie,
                ),
                _infoTile(
                  context,
                  Icons.place_outlined,
                  'Position actuelle',
                  (current.positionActuelle ?? '').trim().isEmpty
                      ? '—'
                      : current.positionActuelle!,
                ),
                _infoTile(
                  context,
                  Icons.event_available_outlined,
                  'Acquisition',
                  current.dateAcquisition != null
                      ? df.format(current.dateAcquisition!)
                      : '—',
                ),
                _infoTile(
                  context,
                  Icons.fact_check_outlined,
                  'Dernière inspection',
                  current.derniereInspection != null
                      ? df.format(current.derniereInspection!)
                      : '—',
                ),
                _infoTile(
                  context,
                  Icons.event_repeat_outlined,
                  'Prochaine inspection',
                  current.prochaineInspection != null
                      ? df.format(current.prochaineInspection!)
                      : '—',
                ),
              ],
            ),
            if ((current.observations ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Observations',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.inkMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(current.observations!),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton.icon(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => WeaponFormDialog(arme: current),
                  ),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Modifier'),
                ),
                // Une arme se remet si elle n'est pas déjà dehors. C'est
                // le bon de sortie en cours qui le dit, et non une colonne
                // d'état tenue à côté : deux sources pour un même fait
                // finissent par se contredire.
                if (charge && enCours == null)
                  FilledButton.icon(
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => DotationFormDialog(arme: current),
                    ),
                    icon: const Icon(Icons.assignment_ind_outlined),
                    label: const Text('Remettre à un militaire'),
                  ),
              ],
            ),
            if (!charge)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: SkeletonTile(),
              ),
            if (charge && enCours != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Card(
                  color: current.inspectionEnRetard || enCours.retourEnRetard
                      ? AppColors.danger.withValues(alpha: 0.08)
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'En dotation chez ${_libelleBeneficiaire(enCours)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'Remise le ${df.format(enCours.dateRemise)}'
                                '${enCours.dateRetourPrevue != null ? ' — retour prévu le ${df.format(enCours.dateRetourPrevue!)}' : ''}',
                              ),
                            ],
                          ),
                        ),
                        FilledButton.tonal(
                          onPressed: _retourEnCours
                              ? null
                              : () => _enregistrerRetour(enCours, current),
                          child: _retourEnCours
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Enregistrer le retour'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 32),
            SectionHeader(
              title:
                  'Historique des dotations (${charge ? dotations.length : '…'})',
            ),
            if (!charge) const SkeletonList(itemCount: 2),
            if (charge && dotations.isEmpty)
              const EmptyState(message: 'Aucune dotation enregistrée'),
            if (charge)
              for (final d in dotations)
                Card(
                  child: ListTile(
                    leading: Icon(
                      Icons.person_outline,
                      color: d.retourEnRetard
                          ? AppColors.danger
                          : AppColors.militaryGreen,
                    ),
                    title: Text('Bénéficiaire ${_libelleBeneficiaire(d)}'),
                    subtitle: Text(
                      'Remise le ${df.format(d.dateRemise)}'
                      '${d.dateRetourEffective != null ? ' · retourné le ${df.format(d.dateRetourEffective!)}' : (d.dateRetourPrevue != null ? ' · retour prévu le ${df.format(d.dateRetourPrevue!)}' : '')}'
                      '${d.motif != null ? ' · ${d.motif}' : ''}',
                    ),
                    trailing: StatusChip(
                      label: d.enCours
                          ? (d.retourEnRetard ? 'En retard' : 'En cours')
                          : 'Clôturée',
                      level: d.retourEnRetard
                          ? AlertLevel.critical
                          : (d.enCours ? AlertLevel.warning : AlertLevel.info),
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

String _libelleBeneficiaire(DotationArme d) => d.beneficiaireNom.isEmpty
    ? d.beneficiaireId
    : '${d.beneficiaireNom} (${d.beneficiaireId})';
