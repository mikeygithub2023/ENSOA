import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sig_ensoa/core/erreurs.dart';
import 'package:sig_ensoa/core/theme.dart' hide AlertLevel, AlertLevelColor;
import '../../models/consultation_medicale.dart';
import '../../models/medicament.dart';
import '../medicaments/providers/medicaments_providers.dart';
import 'providers/consultations_medicales_providers.dart';

/// Détail d'une consultation clôturée (repos, exemption, hospitalisations,
/// examens demandés, médicaments prescrits) — utilisé à la fois depuis
/// l'écran Consultations médicales et depuis l'historique d'un apprenant.
Future<void> showPrescriptionsDialog(
  BuildContext context,
  ConsultationMedicale consultation,
) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      scrollable: true,
      title: const Text('Prescriptions du médecin'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: _PrescriptionsDialogContent(consultation: consultation),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fermer'),
        ),
      ],
    ),
  );
}

/// N'affiche "RAS" que si la consultation n'a réellement rien donné lieu —
/// aucun repos, aucune exemption, aucune hospitalisation, aucun examen
/// demandé et aucun médicament prescrit. Dès qu'un seul de ces éléments est
/// renseigné, le détail complet est affiché à la place.
class _PrescriptionsDialogContent extends ConsumerWidget {
  const _PrescriptionsDialogContent({required this.consultation});

  final ConsultationMedicale consultation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lignesAsync = ref.watch(
      ordonnanceLignesByConsultationProvider(consultation.id),
    );

    return lignesAsync.when(
      data: (lignes) {
        final estRAS =
            consultation.pathologie == null &&
            consultation.joursRepos == null &&
            !consultation.exemption &&
            !consultation.hospitalisationInterne &&
            !consultation.hospitalisationExterne &&
            (consultation.examensDemandes?.trim().isEmpty ?? true) &&
            lignes.isEmpty;

        if (estRAS) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'RAS — Rien à signaler.',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PrescriptionRow(
              label: 'Pathologie constatée',
              value: consultation.pathologie == null
                  ? 'Non renseignée'
                  : (consultation.pathologieDetails?.isNotEmpty == true
                        ? '${consultation.pathologie!.label} — '
                              '${consultation.pathologieDetails}'
                        : consultation.pathologie!.label),
            ),
            _PrescriptionRow(
              label: 'Jours de repos',
              value: consultation.joursRepos?.toString() ?? 'Aucun',
            ),
            _PrescriptionRow(
              label: 'Exemption',
              value: consultation.exemption
                  ? (consultation.exemptionDetails?.isNotEmpty == true
                        ? 'Oui — ${consultation.exemptionDetails}'
                        : 'Oui')
                  : 'Non',
            ),
            _PrescriptionRow(
              label: 'Hospitalisation interne',
              value: consultation.hospitalisationInterne
                  ? (consultation.hospitalisationInterneLieu?.isNotEmpty == true
                        ? 'Oui — ${consultation.hospitalisationInterneLieu}'
                        : 'Oui')
                  : 'Non',
            ),
            _PrescriptionRow(
              label: 'Hospitalisation externe',
              value: consultation.hospitalisationExterne
                  ? (consultation.hospitalisationExterneLieu?.isNotEmpty == true
                        ? 'Oui — ${consultation.hospitalisationExterneLieu}'
                        : 'Oui')
                  : 'Non',
            ),
            _PrescriptionRow(
              label: 'Examens demandés',
              value: consultation.examensDemandes?.isNotEmpty == true
                  ? consultation.examensDemandes!
                  : 'Aucun',
            ),
            const SizedBox(height: 12),
            const Text(
              'Médicaments',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            _OrdonnanceLignesList(consultationId: consultation.id),
          ],
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (error, _) => Text(
        'Erreur de chargement : ${messageErreur(error)}',
        style: const TextStyle(color: AppColors.danger),
      ),
    );
  }
}

class _OrdonnanceLignesList extends ConsumerWidget {
  const _OrdonnanceLignesList({required this.consultationId});

  final String consultationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lignesAsync = ref.watch(
      ordonnanceLignesByConsultationProvider(consultationId),
    );
    final medicamentsAsync = ref.watch(medicamentsProvider);

    return lignesAsync.when(
      data: (lignes) {
        if (lignes.isEmpty) {
          return const Text(
            'Aucun médicament prescrit.',
            style: TextStyle(color: AppColors.inkMuted),
          );
        }
        final medicamentsById = {
          for (final m in medicamentsAsync.value ?? const <Medicament>[])
            m.id: m,
        };
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final ligne in lignes)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${medicamentsById[ligne.medicamentId]?.nom ?? 'Médicament inconnu'} × ${ligne.quantite}'
                  '${ligne.posologie != null ? ' — ${ligne.posologie}' : ''}',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
          ],
        );
      },
      loading: () => const SizedBox(
        height: 20,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (error, _) => Text(
        'Erreur : $error',
        style: const TextStyle(color: AppColors.danger),
      ),
    );
  }
}

class _PrescriptionRow extends StatelessWidget {
  const _PrescriptionRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.inkMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
