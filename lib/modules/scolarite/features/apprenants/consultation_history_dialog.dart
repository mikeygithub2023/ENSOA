import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:sig_ensoa/core/erreurs.dart';
import 'package:sig_ensoa/core/theme.dart' hide AlertLevel, AlertLevelColor;
import '../../models/apprenant.dart';
import '../../models/consultation_medicale.dart';
import '../../shared/widgets/common.dart';
import 'prescriptions_dialog.dart';
import 'providers/consultations_medicales_providers.dart';

/// Historique complet des consultations médicales d'un apprenant, toutes
/// classes/divisions et tous filtres confondus — accessible depuis l'écran
/// Consultations médicales pour que le médecin puisse le consulter sans
/// avoir à parcourir l'effectif.
Future<void> showConsultationHistoryDialog(
  BuildContext context, {
  required Apprenant apprenant,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.all(24),
      child: _ConsultationHistoryDialog(apprenant: apprenant),
    ),
  );
}

class _ConsultationHistoryDialog extends ConsumerWidget {
  const _ConsultationHistoryDialog({required this.apprenant});

  final Apprenant apprenant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenSize = MediaQuery.of(context).size;
    final width = screenSize.width - 48 < 520 ? screenSize.width - 48 : 520.0;
    final height = screenSize.height - 48 < 640
        ? screenSize.height - 48
        : 640.0;
    final consultationsAsync = ref.watch(
      consultationsMedicalesByApprenantProvider(apprenant.id),
    );

    return SizedBox(
      width: width,
      height: height,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Historique des consultations',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      Text(
                        apprenant.nomComplet,
                        style: const TextStyle(
                          color: AppColors.inkMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Expanded(
            child: consultationsAsync.when(
              data: (consultations) {
                if (consultations.isEmpty) {
                  return const EmptyState(
                    message: 'Aucune consultation enregistrée.',
                    icon: Icons.medical_services_outlined,
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(24),
                  itemCount: consultations.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) =>
                      _HistoryTile(consultation: consultations[index]),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Text(
                  'Erreur de chargement : ${messageErreur(error)}',
                  style: const TextStyle(color: AppColors.danger),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.consultation});

  final ConsultationMedicale consultation;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');
    final level = switch (consultation.statut) {
      ConsultationStatut.enAttente => AlertLevel.warning,
      ConsultationStatut.enCours => AlertLevel.info,
      ConsultationStatut.terminee => AlertLevel.success,
    };

    return Material(
      color: AppColors.blueMist,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        fmt.format(consultation.dateSouhaitee),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if (consultation.type == ConsultationType.urgence) ...[
                        const SizedBox(width: 8),
                        const StatusChip(
                          label: 'Urgence',
                          level: AlertLevel.critical,
                        ),
                      ],
                    ],
                  ),
                  // La pathologie est ce qu'on cherche en parcourant un
                  // historique : elle se lit sans ouvrir chaque consultation.
                  if (consultation.pathologie != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      consultation.pathologieDetails?.isNotEmpty == true
                          ? '${consultation.pathologie!.label} — '
                                '${consultation.pathologieDetails}'
                          : consultation.pathologie!.label,
                      style: const TextStyle(
                        color: AppColors.inkMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            StatusChip(label: consultation.statut.label, level: level),
            if (consultation.statut == ConsultationStatut.terminee) ...[
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => showPrescriptionsDialog(context, consultation),
                child: const Text('Voir'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
