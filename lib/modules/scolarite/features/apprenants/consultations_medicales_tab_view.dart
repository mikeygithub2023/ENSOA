import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:sig_ensoa/core/erreurs.dart';
import 'package:sig_ensoa/core/theme.dart' hide AlertLevel, AlertLevelColor;
import '../../models/apprenant.dart';
import '../../models/classe.dart';
import '../../models/consultation_medicale.dart';
import '../../models/division.dart';
import 'package:sig_ensoa/modules/scolarite/compat.dart';
import '../../shared/widgets/common.dart';
import '../matieres/providers/matieres_providers.dart';
import 'antecedents_medicaux_dialog.dart';
import 'complete_consultation_dialog.dart';
import 'consultation_history_dialog.dart';
import 'prescriptions_dialog.dart';
import 'portee_promotion.dart';
import 'providers/apprenants_providers.dart';
import 'providers/consultations_medicales_providers.dart';
import 'register_consultation_dialog.dart';
import 'register_urgence_consultation_dialog.dart';

class ConsultationsMedicalesTabView extends ConsumerWidget {
  const ConsultationsMedicalesTabView({
    super.key,
    required this.division,
    required this.classe,
    this.classesRetenues,
  });

  final Division division;
  final Classe? classe;

  /// Phases d'une promotion sélectionnée sans phase précise, nul sinon.
  final Set<String>? classesRetenues;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classe = this.classe;
    final portee = classe == null ? classesRetenues : null;
    final apprenantsAsync =
        (classe != null
                ? ref.watch(apprenantsByClasseProvider(classe.id))
                : ref.watch(apprenantsByDivisionProvider(division.id)))
            .dansLesClasses(portee, (a) => a.classeId);
    final consultationsAsync =
        (classe != null
                ? ref.watch(consultationsMedicalesByClasseProvider(classe.id))
                : ref.watch(
                    consultationsMedicalesByDivisionProvider(division.id),
                  ))
            .dansLesClasses(portee, (c) => c.classeId);
    final classesAsync = ref.watch(classesListProvider);
    final role = ref.watch(currentProfileProvider).value?.role;
    final canTraiter = role == AppRole.admin || role == AppRole.medecin;
    // Enregistrer une consultation de routine, c'est délivrer l'AUTORISATION
    // de consulter : cela relève du commandement, à quelque niveau qu'il
    // s'exerce — l'école, la division, la promotion. Le médecin, lui, ne fait
    // que traiter les consultations autorisées et enregistrer les urgences.
    final canAutoriser =
        role == AppRole.admin ||
        role == AppRole.chefDivision ||
        role == AppRole.commandantPromotion ||
        role == AppRole.commandantBrigade;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: SectionHeader(title: 'Consultations médicales'),
            ),
            if (canTraiter)
              OutlinedButton.icon(
                onPressed: apprenantsAsync.maybeWhen(
                  data: (apprenants) => apprenants.isEmpty
                      ? null
                      : () => showRegisterUrgenceConsultationDialog(
                          context,
                          apprenants: apprenants,
                        ),
                  orElse: () => null,
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: AppColors.danger),
                ),
                icon: const Icon(Icons.emergency_outlined, size: 18),
                label: const Text('Enregistrer une urgence'),
              ),
            if (canTraiter && canAutoriser) const SizedBox(width: 8),
            if (canAutoriser)
              FilledButton.icon(
                onPressed: apprenantsAsync.maybeWhen(
                  data: (apprenants) => apprenants.isEmpty
                      ? null
                      : () => showRegisterConsultationDialog(
                          context,
                          apprenants: apprenants,
                        ),
                  orElse: () => null,
                ),
                icon: const Icon(Icons.medical_services, size: 18),
                label: const Text('Enregistrer une consultation'),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: apprenantsAsync.when(
            data: (apprenants) {
              final apprenantsById = {for (final a in apprenants) a.id: a};
              final classesById = {
                for (final c in classesAsync.value ?? const <Classe>[]) c.id: c,
              };
              return consultationsAsync.when(
                data: (consultations) {
                  if (consultations.isEmpty) {
                    return EmptyState(
                      message: classe != null
                          ? 'Aucune consultation enregistrée pour cette phase ou ce stage.'
                          : 'Aucune consultation enregistrée pour cette division.',
                      icon: Icons.medical_services_outlined,
                    );
                  }
                  return ListView.separated(
                    itemCount: consultations.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final consultation = consultations[index];
                      return _ConsultationTile(
                        consultation: consultation,
                        apprenant: apprenantsById[consultation.apprenantId],
                        classeNom: classe == null
                            ? classesById[consultation.classeId]?.nom
                            : null,
                        canTraiter: canTraiter,
                        onDelete: () =>
                            _confirmDelete(context, ref, consultation),
                        onStart: () =>
                            _startConsultation(context, ref, consultation),
                        onComplete: () => showCompleteConsultationDialog(
                          context,
                          consultation: consultation,
                        ),
                        onViewPrescriptions: () =>
                            showPrescriptionsDialog(context, consultation),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => EmptyState(
                  message: 'Erreur de chargement : ${messageErreur(error)}',
                  icon: Icons.error_outline,
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => EmptyState(
              message: 'Erreur de chargement : ${messageErreur(error)}',
              icon: Icons.error_outline,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _startConsultation(
    BuildContext context,
    WidgetRef ref,
    ConsultationMedicale consultation,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(consultationsMedicalesRepositoryProvider)
          .startConsultation(consultation.id);
      ref.invalidate(
        consultationsMedicalesByClasseProvider(consultation.classeId),
      );
      ref.invalidate(
        consultationsMedicalesByDivisionProvider(consultation.divisionId),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Erreur : ${messageErreur(e)}'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    ConsultationMedicale consultation,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Supprimer la consultation'),
        content: const Text(
          'Voulez-vous vraiment supprimer cette consultation ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(consultationsMedicalesRepositoryProvider)
          .deleteConsultation(consultation.id);
      ref.invalidate(
        consultationsMedicalesByClasseProvider(consultation.classeId),
      );
      ref.invalidate(
        consultationsMedicalesByDivisionProvider(consultation.divisionId),
      );
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Consultation supprimée.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Erreur : ${messageErreur(e)}'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }
}

class _ConsultationTile extends StatelessWidget {
  const _ConsultationTile({
    required this.consultation,
    required this.apprenant,
    required this.canTraiter,
    required this.onDelete,
    required this.onStart,
    required this.onComplete,
    required this.onViewPrescriptions,
    this.classeNom,
  });

  final ConsultationMedicale consultation;
  final Apprenant? apprenant;
  final String? classeNom;
  final bool canTraiter;
  final VoidCallback onDelete;
  final VoidCallback onStart;
  final VoidCallback onComplete;
  final VoidCallback onViewPrescriptions;

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
                        '${apprenant?.nomComplet ?? 'Apprenant inconnu'}'
                        '${classeNom != null ? ' · $classeNom' : ''}',
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
                  const SizedBox(height: 2),
                  Text(
                    'Date souhaitée : ${fmt.format(consultation.dateSouhaitee)}',
                    style: const TextStyle(
                      color: AppColors.inkMuted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            StatusChip(label: consultation.statut.label, level: level),
            if (canTraiter && apprenant != null) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.assignment_outlined, size: 20),
                tooltip: 'Antécédents médicaux',
                onPressed: () => showAntecedentsMedicauxDialog(
                  context,
                  apprenant: apprenant!,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.history, size: 20),
                tooltip: 'Historique des consultations',
                onPressed: () => showConsultationHistoryDialog(
                  context,
                  apprenant: apprenant!,
                ),
              ),
            ],
            if (consultation.statut == ConsultationStatut.terminee) ...[
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: onViewPrescriptions,
                child: const Text('Voir les prescriptions'),
              ),
            ],
            if (canTraiter &&
                consultation.statut == ConsultationStatut.enAttente) ...[
              const SizedBox(width: 8),
              FilledButton(onPressed: onStart, child: const Text('Démarrer')),
            ],
            if (canTraiter &&
                consultation.statut == ConsultationStatut.enCours) ...[
              const SizedBox(width: 8),
              FilledButton(
                onPressed: onComplete,
                child: const Text('Compléter'),
              ),
            ],
            if (consultation.statut == ConsultationStatut.enAttente) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: AppColors.danger,
                ),
                onPressed: onDelete,
                tooltip: 'Supprimer',
              ),
            ],
          ],
        ),
      ),
    );
  }
}
