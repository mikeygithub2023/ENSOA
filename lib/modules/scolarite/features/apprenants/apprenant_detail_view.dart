import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:sig_ensoa/core/erreurs.dart';
import 'package:sig_ensoa/core/theme.dart' hide AlertLevel, AlertLevelColor;
import '../../models/absence.dart';
import '../../models/apprenant.dart';
import '../../models/classe.dart';
import '../../models/consultation_medicale.dart';
import '../../models/controle.dart';
import '../../models/division.dart';
import '../../models/matiere.dart';
import '../../models/note.dart';
import '../../models/permission.dart';
import 'package:sig_ensoa/modules/scolarite/compat.dart';
import '../../models/sous_module.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/pdf_preview_dialog.dart';
import '../matieres/providers/matieres_providers.dart';
import 'antecedents_medicaux_dialog.dart';
import 'bulletins_pdf.dart';
import 'moyennes.dart';
import 'pdf_fonts.dart';
import 'providers/absences_providers.dart';
import 'providers/apprenants_providers.dart';
import 'providers/consultations_medicales_providers.dart';
import 'providers/controles_providers.dart';
import 'providers/permissions_providers.dart';
import 'providers/sous_modules_providers.dart';
import 'providers/sport_providers.dart';
import 'register_apprenant_dialog.dart';
import 'statistiques_apprenant_section.dart';

/// Le sexe tel qu'on le lit sur une fiche, plutôt que la lettre stockée.
/// Il décide du barème appliqué aux épreuves sportives, d'où sa place en
/// tête de l'identité.
String _libelleSexe(String? valeur) => switch (valeur) {
  'M' => 'Masculin',
  'F' => 'Féminin',
  _ => '—',
};

/// Regroupe les chiffres d'un numéro par paires ("0908070405" ->
/// "09 08 07 04 05") pour l'affichage. Les caractères non numériques
/// (espaces déjà présents, "RAS", etc.) sont laissés tels quels.
String _formatPhone(String? value) {
  if (value == null || value.trim().isEmpty) return '—';
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return value;
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i += 2) {
    if (i > 0) buffer.write(' ');
    final end = i + 2 > digits.length ? digits.length : i + 2;
    buffer.write(digits.substring(i, end));
  }
  return buffer.toString();
}

/// Panneau d'identité/carrière d'un apprenant — reprend toutes les rubriques
/// de la fiche signalétique saisies à l'enregistrement, avec les actions
/// Modifier/Supprimer, puis ses statistiques personnelles et le détail de
/// ses permissions, absences, consultations et notes.
class ApprenantDetailView extends ConsumerWidget {
  const ApprenantDetailView({
    super.key,
    required this.apprenant,
    required this.division,
    required this.classe,
    this.showActions = true,
  });

  final Apprenant apprenant;
  final Division division;
  final Classe classe;
  final bool showActions;

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Supprimer cet apprenant'),
        content: Text(
          'Voulez-vous vraiment supprimer la fiche de ${apprenant.nomComplet} ? Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Supprimer',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref
          .read(apprenantsRepositoryProvider)
          .deleteApprenant(apprenant.id);
      ref.invalidate(apprenantsListProvider);
      if (router.canPop()) {
        router.pop();
      } else {
        router.go('/apprenants');
      }
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Apprenant supprimé.'),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diplomesAsync = ref.watch(apprenantDiplomesProvider(apprenant.id));
    final permissionsAsync = ref.watch(
      permissionsByApprenantProvider(apprenant.id),
    );
    final absencesAsync = ref.watch(absencesByApprenantProvider(apprenant.id));
    final consultationsAsync = ref.watch(
      consultationsMedicalesByApprenantProvider(apprenant.id),
    );
    final notesAsync = ref.watch(notesByApprenantProvider(apprenant.id));
    final controlesAsync = ref.watch(controlesByClasseProvider(classe.id));
    final matieresAsync = ref.watch(matieresCatalogueProvider);
    final sousModulesAsync = ref.watch(sousModulesByClasseProvider(classe.id));
    final performancesAsync = ref.watch(
      performancesApprenantProvider(apprenant.id),
    );
    final photoPath = apprenant.photoPath;
    final photoUrlAsync = photoPath == null
        ? null
        : ref.watch(apprenantPhotoUrlProvider(photoPath));
    final role = ref.watch(currentProfileProvider).value?.role;
    final canSeeAntecedents = role == AppRole.admin || role == AppRole.medecin;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Retour',
                onPressed: () => context.canPop()
                    ? context.pop()
                    : context.go('/scolarite/apprenants'),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.blueMist,
                backgroundImage: photoUrlAsync?.value != null
                    ? NetworkImage(photoUrlAsync!.value!)
                    : null,
                child: photoUrlAsync?.value != null
                    ? null
                    : const Icon(
                        Icons.person_outline,
                        color: AppColors.blueDeep,
                        size: 26,
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      apprenant.nomComplet,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${apprenant.matricule ?? "Sans matricule"} · ${division.nom}',
                      style: const TextStyle(
                        color: AppColors.inkMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              StatusChip(
                label: apprenant.statut.label,
                level: apprenant.statut == ApprenantStatut.actif
                    ? AlertLevel.success
                    : AlertLevel.warning,
              ),
              if (canSeeAntecedents) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.assignment_outlined),
                  tooltip: 'Antécédents médicaux',
                  onPressed: () => showAntecedentsMedicauxDialog(
                    context,
                    apprenant: apprenant,
                  ),
                ),
              ],
              if (showActions) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Modifier',
                  onPressed: () => showRegisterApprenantDialog(
                    context,
                    division: division,
                    classe: classe,
                    existing: apprenant,
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppColors.danger,
                  ),
                  tooltip: 'Supprimer',
                  onPressed: () => _confirmDelete(context, ref),
                ),
              ],
            ],
          ),
          const SizedBox(height: 24),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionHeader(title: 'Carrière'),
                          const SizedBox(height: 10),
                          _InfoRow(label: 'Type', value: apprenant.type.label),
                          _InfoRow(
                            label: apprenant.type == ApprenantType.eleve
                                ? 'Classe'
                                : 'Stage',
                            value: classe.nom,
                          ),
                          _InfoRow(
                            label: 'Grade',
                            value: apprenant.grade ?? '—',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionHeader(title: 'Identité'),
                          const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _PhotoField(photoUrl: photoUrlAsync?.value),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _InfoRow(
                                      label: 'Téléphone',
                                      value: _formatPhone(apprenant.telephone),
                                    ),
                                    _InfoRow(
                                      label: 'Sexe',
                                      value: _libelleSexe(apprenant.sexe),
                                    ),
                                    _InfoRow(
                                      label: 'Né(e) le',
                                      value: apprenant.dateNaissance == null
                                          ? '—'
                                          : DateFormat(
                                              'dd/MM/yyyy',
                                            ).format(apprenant.dateNaissance!),
                                    ),
                                    _InfoRow(
                                      label: 'Lieu de naissance',
                                      value: apprenant.lieuNaissance ?? '—',
                                    ),
                                    _InfoRow(
                                      label: 'E-mail',
                                      value: apprenant.email ?? '—',
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionHeader(title: 'Filiation'),
                          const SizedBox(height: 16),
                          _InfoRow(
                            label: 'Ethnie',
                            value: apprenant.ethnie ?? '—',
                          ),
                          _InfoRow(
                            label: 'Situation matrimoniale',
                            value: apprenant.situationMatrimoniale ?? '—',
                          ),
                          _InfoRow(
                            label: 'Enfant(s)',
                            value: apprenant.nombreEnfants?.toString() ?? '—',
                          ),
                          _InfoRow(
                            label: 'Nom et prénoms du père',
                            value: apprenant.nomPere ?? '—',
                          ),
                          _InfoRow(
                            label: 'Nom et prénoms de la mère',
                            value: apprenant.nomMere ?? '—',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionHeader(title: 'Urgence & santé'),
                          const SizedBox(height: 16),
                          _InfoRow(
                            label: 'Contact d\'urgence',
                            value: apprenant.urgenceNom ?? '—',
                          ),
                          _InfoRow(
                            label: 'Lien de parenté',
                            value: apprenant.urgenceLien ?? '—',
                          ),
                          _InfoRow(
                            label: 'Contact(s)',
                            value: _formatPhone(apprenant.urgenceContact),
                          ),
                          _InfoRow(
                            label: 'Taille / Poids',
                            value:
                                '${apprenant.tailleCm != null ? "${apprenant.tailleCm} cm" : "—"} / '
                                '${apprenant.poidsKg != null ? "${apprenant.poidsKg} kg" : "—"}',
                          ),
                          _InfoRow(
                            label: 'Groupe sanguin',
                            value: apprenant.groupeSanguin ?? '—',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(title: 'Formation civile'),
                  const SizedBox(height: 16),
                  diplomesAsync.when(
                    data: (diplomes) => diplomes.isEmpty
                        ? const Text(
                            'Aucun diplôme renseigné.',
                            style: TextStyle(color: AppColors.inkMuted),
                          )
                        : Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final d in diplomes)
                                StatusChip(label: d, level: AlertLevel.info),
                            ],
                          ),
                    loading: () => const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    error: (_, _) => const Text(
                      '—',
                      style: TextStyle(color: AppColors.inkMuted),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                    label: 'Qualification',
                    value: apprenant.qualification ?? '—',
                  ),
                  _InfoRow(
                    label: 'Permis de conduire',
                    value: apprenant.permisConduire ?? '—',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const SectionHeader(title: 'Statistiques personnelles'),
          const SizedBox(height: 4),
          const Text(
            'Situation de l\'apprenant dans sa promotion — les listes qui '
            'suivent en donnent le détail.',
            style: TextStyle(color: AppColors.inkMuted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          StatistiquesApprenantSection(apprenant: apprenant, classe: classe),
          const SizedBox(height: 20),
          const SectionHeader(title: 'Permissions'),
          const SizedBox(height: 12),
          permissionsAsync.when(
            data: (permissions) => permissions.isEmpty
                ? const EmptyState(
                    message: 'Aucune permission enregistrée.',
                    icon: Icons.assignment_turned_in_outlined,
                  )
                : Column(
                    children: [
                      for (final p in permissions) ...[
                        _PermissionTile(permission: p),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (error, _) => EmptyState(
              message: 'Erreur de chargement : ${messageErreur(error)}',
              icon: Icons.error_outline,
            ),
          ),
          const SizedBox(height: 20),
          const SectionHeader(title: 'Absences'),
          const SizedBox(height: 12),
          absencesAsync.when(
            data: (absences) => absences.isEmpty
                ? const EmptyState(
                    message: 'Aucune absence enregistrée.',
                    icon: Icons.event_busy_outlined,
                  )
                : Column(
                    children: [
                      for (final a in absences) ...[
                        _AbsenceTile(absence: a),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (error, _) => EmptyState(
              message: 'Erreur de chargement : ${messageErreur(error)}',
              icon: Icons.error_outline,
            ),
          ),
          const SizedBox(height: 20),
          const SectionHeader(title: 'Consultations médicales'),
          const SizedBox(height: 12),
          consultationsAsync.when(
            data: (consultations) => consultations.isEmpty
                ? const EmptyState(
                    message: 'Aucune consultation enregistrée.',
                    icon: Icons.medical_services_outlined,
                  )
                : Column(
                    children: [
                      for (final c in consultations) ...[
                        _ConsultationTile(consultation: c),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (error, _) => EmptyState(
              message: 'Erreur de chargement : ${messageErreur(error)}',
              icon: Icons.error_outline,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(child: SectionHeader(title: 'Notes')),
              _ImprimerBulletinButton(
                apprenant: apprenant,
                classe: classe,
                division: division,
              ),
            ],
          ),
          const SizedBox(height: 12),
          controlesAsync.when(
            data: (controles) => notesAsync.when(
              data: (notes) => matieresAsync.when(
                data: (matieres) => _NotesSummary(
                  classe: classe,
                  controles: controles,
                  notes: notes,
                  matieres: matieres,
                  sousModules: sousModulesAsync.value ?? const [],
                  performances: performancesAsync.value ?? const {},
                ),
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                error: (error, _) => EmptyState(
                  message: 'Erreur de chargement : ${messageErreur(error)}',
                  icon: Icons.error_outline,
                ),
              ),
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              error: (error, _) => EmptyState(
                message: 'Erreur de chargement : ${messageErreur(error)}',
                icon: Icons.error_outline,
              ),
            ),
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (error, _) => EmptyState(
              message: 'Erreur de chargement : ${messageErreur(error)}',
              icon: Icons.error_outline,
            ),
          ),
        ],
      ),
    );
  }
}

/// Champ dédié à l'affichage de la photo — cadre visible même sans photo,
/// pour que l'emplacement soit clair dans la fiche.
class _PhotoField extends StatelessWidget {
  const _PhotoField({required this.photoUrl});

  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 148,
      height: 148,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadii.control),
        color: AppColors.blueMist,
      ),
      child: photoUrl != null
          ? Image.network(
              photoUrl!,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              width: 148,
              height: 148,
            )
          : const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.person_outline,
                    color: AppColors.inkMuted,
                    size: 28,
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Photo',
                    style: TextStyle(color: AppColors.inkMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

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
            width: 215,
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

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({required this.permission});

  final Permission permission;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');
    final statut = permission.statut;
    final level = switch (statut) {
      PermissionStatut.aVenir => AlertLevel.info,
      PermissionStatut.enCours => AlertLevel.success,
      PermissionStatut.terminee => AlertLevel.warning,
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
                  Text(
                    '${fmt.format(permission.dateDepart)} → ${fmt.format(permission.dateRetour)}'
                    '${permission.localite != null ? ' · ${permission.localite}' : ''}'
                    '${permission.motif != null ? ' · ${permission.motif}' : ''}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (permission.personneContact != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Personne à prévenir : ${permission.personneContact}',
                      style: const TextStyle(
                        color: AppColors.inkMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 16),
            StatusChip(label: statut.label, level: level),
          ],
        ),
      ),
    );
  }
}

class _AbsenceTile extends StatelessWidget {
  const _AbsenceTile({required this.absence});

  final Absence absence;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');

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
              child: Text(
                (absence.enCours
                        ? 'Depuis le ${fmt.format(absence.dateDebut)}'
                        : '${fmt.format(absence.dateDebut)} → ${fmt.format(absence.dateFin!)}') +
                    (absence.motif != null ? ' · ${absence.motif}' : ''),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 16),
            if (absence.enCours)
              const StatusChip(label: 'En cours', level: AlertLevel.warning)
            else ...[
              const StatusChip(label: 'Terminée', level: AlertLevel.info),
              const SizedBox(width: 8),
              StatusChip(
                label: absence.justifiee ? 'Justifiée' : 'Non justifiée',
                level: absence.justifiee
                    ? AlertLevel.success
                    : AlertLevel.critical,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ConsultationTile extends StatelessWidget {
  const _ConsultationTile({required this.consultation});

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
              child: Text(
                'Date souhaitée : ${fmt.format(consultation.dateSouhaitee)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 16),
            StatusChip(label: consultation.statut.label, level: level),
          ],
        ),
      ),
    );
  }
}

String _formatNote(num value) {
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toString();
}

/// Récapitulatif des notes de l'apprenant, en conservant la même hiérarchie
/// que la rubrique Modules/Contrôle continu/Examen : les modules d'abord
/// (une note par sous-module, et la moyenne pondérée qui en fait la note du
/// module), puis pour chaque contrôle continu et chaque examen, les notes
/// rangées par matière.
class _NotesSummary extends StatelessWidget {
  const _NotesSummary({
    required this.classe,
    required this.controles,
    required this.notes,
    required this.matieres,
    required this.sousModules,
    required this.performances,
  });

  final Classe classe;
  final List<Controle> controles;
  final List<Note> notes;
  final List<Matiere> matieres;
  final List<SousModule> sousModules;

  /// Ce que l'apprenant a réalisé à chaque séance sportive, mis en forme,
  /// par sous-module. Vide tant que le module Sport n'a rien pour lui.
  final Map<String, String> performances;

  @override
  Widget build(BuildContext context) {
    final matieresById = {for (final m in matieres) m.id: m};
    final notesByControle = <String, List<Note>>{};
    for (final note in notes) {
      notesByControle.putIfAbsent(note.controleId, () => []).add(note);
    }

    // Le Sport est un module : sa note se forme comme celle des autres, à
    // partir de ses séances. L'omettre ici le rendait invisible sur la
    // fiche alors qu'il compte dans la moyenne.
    final modules = classe.type == ClasseType.phase
        ? controles
              .where(
                (c) =>
                    (c.type == ControleType.module ||
                        c.type == ControleType.sport) &&
                    notesByControle.containsKey(c.id),
              )
              .toList()
        : const <Controle>[];
    final continus = controles
        .where(
          (c) =>
              c.type == ControleType.continu &&
              notesByControle.containsKey(c.id),
        )
        .toList();
    final examens = controles
        .where(
          (c) =>
              c.type == ControleType.examen &&
              notesByControle.containsKey(c.id),
        )
        .toList();

    if (modules.isEmpty && continus.isEmpty && examens.isEmpty) {
      return const EmptyState(
        message: 'Aucune note enregistrée.',
        icon: Icons.grading_outlined,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (modules.isNotEmpty) ...[
          const SectionHeader(title: 'Modules'),
          const SizedBox(height: 8),
          for (final controle in modules) ...[
            _ModuleNotesGroup(
              module: controle,
              notes: notesByControle[controle.id]!,
              sousModules: sousModules
                  .where((s) => s.moduleId == controle.id)
                  .toList(),
              performances: performances,
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 4),
        ],
        if (continus.isNotEmpty) ...[
          const SectionHeader(title: 'Contrôle continu'),
          const SizedBox(height: 8),
          for (final controle in continus) ...[
            _ControleNotesGroup(
              controle: controle,
              notes: notesByControle[controle.id]!,
              matieresById: matieresById,
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 4),
        ],
        if (examens.isNotEmpty) ...[
          const SectionHeader(title: 'Examen'),
          const SizedBox(height: 8),
          for (final controle in examens) ...[
            _ControleNotesGroup(
              controle: controle,
              notes: notesByControle[controle.id]!,
              matieresById: matieresById,
            ),
            const SizedBox(height: 12),
          ],
        ],
      ],
    );
  }
}

/// Notes d'un module, rangées par sous-module, précédées de la note du
/// module — qui n'est pas saisie mais calculée : c'est la moyenne pondérée
/// des sous-modules notés (voir `moyennes.dart`). Un sous-module non noté
/// n'entre pas dans le calcul : l'apprenant n'y est pas classé, il n'y a
/// pas zéro.
class _ModuleNotesGroup extends StatelessWidget {
  const _ModuleNotesGroup({
    required this.module,
    required this.notes,
    required this.sousModules,
    this.performances = const {},
  });

  final Controle module;
  final List<Note> notes;
  final List<SousModule> sousModules;

  /// Renseigné pour le module Sport : la performance réalisée à chaque
  /// séance, à lire sous son nom.
  final Map<String, String> performances;

  @override
  Widget build(BuildContext context) {
    final sousModulesById = {for (final s in sousModules) s.id: s};
    final sortedNotes = [...notes]
      ..sort((a, b) {
        final nomA = sousModulesById[a.sousModuleId]?.nom ?? '';
        final nomB = sousModulesById[b.sousModuleId]?.nom ?? '';
        return nomA.toLowerCase().compareTo(nomB.toLowerCase());
      });
    final moyenne = moyenneSousModules(notes, module.id, sousModules);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${module.libelle} · Coefficient ${module.coefficient}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppColors.ink,
                ),
              ),
            ),
            StatusChip(
              label: moyenne == null
                  ? 'Non classé'
                  : 'Moyenne ${_formatNote(moyenne)} / 20',
              level: moyenne == null ? AlertLevel.warning : AlertLevel.info,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Column(
          children: [
            for (final note in sortedNotes) ...[
              _NoteTile(
                label:
                    sousModulesById[note.sousModuleId]?.nom ??
                    'Sous-module inconnu',
                note: note,
                detail: performances[note.sousModuleId],
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ],
    );
  }
}

/// Notes d'un contrôle continu/examen précis, rangées par matière — un même
/// contrôle peut couvrir plusieurs matières.
class _ControleNotesGroup extends StatelessWidget {
  const _ControleNotesGroup({
    required this.controle,
    required this.notes,
    required this.matieresById,
  });

  final Controle controle;
  final List<Note> notes;
  final Map<String, Matiere> matieresById;

  @override
  Widget build(BuildContext context) {
    final sortedNotes = [...notes]
      ..sort((a, b) {
        final nomA = matieresById[a.matiereId]?.nom ?? '';
        final nomB = matieresById[b.matiereId]?.nom ?? '';
        return nomA.toLowerCase().compareTo(nomB.toLowerCase());
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${controle.libelle} · Coefficient ${controle.coefficient}',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 8),
        Column(
          children: [
            for (final note in sortedNotes) ...[
              _NoteTile(
                label: matieresById[note.matiereId]?.nom ?? 'Matière inconnue',
                note: note,
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ],
    );
  }
}

class _NoteTile extends StatelessWidget {
  const _NoteTile({required this.label, required this.note, this.detail});

  final String label;
  final Note note;

  /// Une ligne sous le nom : pour une séance sportive, la performance
  /// réalisée. La note en est tirée par le barème, elle ne la remplace pas.
  final String? detail;

  @override
  Widget build(BuildContext context) {
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
                  Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (detail != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      detail!,
                      style: const TextStyle(
                        color: AppColors.inkMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 16),
            StatusChip(
              label: '${_formatNote(note.note)} / 20',
              level: AlertLevel.info,
            ),
          ],
        ),
      ),
    );
  }
}

/// Imprime le bulletin de cet apprenant, en ne prenant en compte que les
/// contrôles cochés par l'administrateur pour sa classe/stage (menu
/// "Bulletins" — voir [Controle.inclusBulletin]).
class _ImprimerBulletinButton extends ConsumerStatefulWidget {
  const _ImprimerBulletinButton({
    required this.apprenant,
    required this.classe,
    required this.division,
  });

  final Apprenant apprenant;
  final Classe classe;
  final Division division;

  @override
  ConsumerState<_ImprimerBulletinButton> createState() =>
      _ImprimerBulletinButtonState();
}

class _ImprimerBulletinButtonState
    extends ConsumerState<_ImprimerBulletinButton> {
  bool _printing = false;

  Future<void> _print() async {
    if (_printing) return;
    setState(() => _printing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Le bulletin d'un élève porte sur toute sa promotion, phases
      // réunies : ses notes s'y répartissent, et n'en imprimer qu'une
      // donnerait un bulletin partiel. Un stagiaire, lui, n'a que son
      // stage.
      final promotionId = widget.classe.promotionId;
      final phases = promotionId == null
          ? [widget.classe]
          : (await ref.read(
              classesListProvider.future,
            )).where((c) => c.promotionId == promotionId).toList();
      final promotion = promotionId == null
          ? null
          : (await ref.read(
              promotionsListProvider.future,
            )).where((p) => p.id == promotionId).firstOrNull;

      final controles = <Controle>[];
      final sousModules = <SousModule>[];
      for (final phase in phases) {
        controles.addAll(
          await ref.read(controlesByClasseProvider(phase.id).future),
        );
        sousModules.addAll(
          await ref.read(sousModulesRepositoryProvider).fetchByClasse(phase.id),
        );
      }
      final included = controles.where((c) => c.inclusBulletin).toList();
      if (included.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Aucun contrôle coché pour le calcul des bulletins (menu Bulletins).',
            ),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }
      final notes = await ref.read(
        notesByApprenantProvider(widget.apprenant.id).future,
      );
      final matieres = await ref.read(matieresCatalogueProvider.future);
      final matiereModules = await ref.read(matiereModulesProvider.future);
      final photoPath = widget.apprenant.photoPath;
      Uint8List? photo;
      if (photoPath != null) {
        try {
          photo = await ref
              .read(apprenantsRepositoryProvider)
              .downloadPhoto(photoPath);
        } catch (_) {
          // Pas de photo affichable -> cadre vide dans le PDF.
        }
      }
      final armoiries = (await rootBundle.load(
        'assets/images/armoiries_ci.png',
      )).buffer.asUint8List();
      final doc = buildBulletinsPdf(
        [
          BulletinPrintData(
            apprenant: widget.apprenant,
            classe: widget.classe,
            division: widget.division,
            promotion: promotion,
            phases: promotion == null ? const [] : phases,
            controles: included,
            notes: notes,
            matieres: matieres,
            matiereModules: matiereModules,
            sousModules: sousModules,
            photo: photo,
          ),
        ],
        armoiries: armoiries,
        theme: await chargerThemePdf(),
      );
      final bytes = await doc.save();
      if (!mounted) return;
      await showPdfPreviewDialog(context, bytes);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Erreur : ${messageErreur(e)}'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _printing ? null : _print,
      icon: const Icon(Icons.print_outlined, size: 18),
      label: const Text('Imprimer le bulletin'),
    );
  }
}
