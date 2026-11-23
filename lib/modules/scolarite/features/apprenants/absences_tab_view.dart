import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:sig_ensoa/core/erreurs.dart';
import 'package:sig_ensoa/core/theme.dart' hide AlertLevel, AlertLevelColor;
import '../../models/absence.dart';
import '../../models/apprenant.dart';
import '../../models/classe.dart';
import '../../models/division.dart';
import '../../shared/widgets/common.dart';
import '../matieres/providers/matieres_providers.dart';
import 'bureaux.dart';
import 'portee_promotion.dart';
import 'providers/absences_providers.dart';
import 'providers/apprenants_providers.dart';
import 'register_absence_dialog.dart';

class AbsencesTabView extends ConsumerWidget {
  const AbsencesTabView({
    super.key,
    required this.division,
    required this.classe,
    this.classesRetenues,
    this.apprenantsRetenus,
  });

  /// Nulle sous « Toutes » : la vue cumule alors ce que l'utilisateur a le
  /// droit de voir, divisions confondues.
  final Division? division;
  final Classe? classe;

  /// Phases d'une promotion sélectionnée sans phase précise, nul sinon.
  final Set<String>? classesRetenues;

  /// Les élèves d'une section retenue, nommément — nul sous « toutes les
  /// sections ». Une section traverse les phases de sa promotion : elle ne
  /// se dit pas en classes, mais par ceux qu'elle tient.
  final Set<String>? apprenantsRetenus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classe = this.classe;
    final portee = classe == null ? classesRetenues : null;
    final division = this.division;
    final apprenantsAsync =
        (classe != null
                ? ref.watch(apprenantsByClasseProvider(classe.id))
                : division != null
                ? ref.watch(apprenantsByDivisionProvider(division.id))
                : ref.watch(apprenantsListProvider))
            .dansLesClasses(portee, (a) => a.classeId)
            .pourLesApprenants(apprenantsRetenus, (a) => a.id);
    final absencesAsync =
        (classe != null
                ? ref.watch(absencesByClasseProvider(classe.id))
                : division != null
                ? ref.watch(absencesByDivisionProvider(division.id))
                : ref.watch(absencesToutesProvider))
            .dansLesClasses(portee, (a) => a.classeId)
            .pourLesApprenants(apprenantsRetenus, (a) => a.apprenantId);
    final classesAsync = ref.watch(classesListProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: SectionHeader(title: 'Absences')),
            // La saisie demande une division, et une phase quand il y en a
            // une. Le personnel de l'école n'en a pas : c'est sa division
            // qui le délimite. Sous « Toutes », en revanche, il n'y a rien à
            // quoi rattacher l'enregistrement.
            if (division != null &&
                ouvreUneFiche(division: division, classeInscription: classe))
              FilledButton.icon(
                onPressed: apprenantsAsync.maybeWhen(
                  data: (apprenants) => apprenants.isEmpty
                      ? null
                      : () => showRegisterAbsenceDialog(
                          context,
                          division: division,
                          classe: classe,
                          apprenants: apprenants,
                        ),
                  orElse: () => null,
                ),
                icon: const Icon(Icons.event_busy, size: 18),
                label: const Text('Enregistrer une absence'),
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
              return absencesAsync.when(
                data: (absences) {
                  if (absences.isEmpty) {
                    return EmptyState(
                      message: classe != null
                          ? 'Aucune absence enregistrée pour cette phase ou ce stage.'
                          : 'Aucune absence enregistrée pour cette division.',
                      icon: Icons.event_busy_outlined,
                    );
                  }
                  return ListView.separated(
                    itemCount: absences.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final absence = absences[index];
                      final classeId = absence.classeId;
                      return _AbsenceTile(
                        absence: absence,
                        apprenant: apprenantsById[absence.apprenantId],
                        classeNom: classe == null && classeId != null
                            ? classesById[classeId]?.nom
                            : null,
                        onDelete: () => _confirmDelete(context, ref, absence),
                        onMarkRetour: () => _markRetour(context, ref, absence),
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

  /// Tout ce qui peut porter cette absence : la phase quand il y en a une,
  /// la division toujours, et la vue d'ensemble.
  void _rafraichir(WidgetRef ref, Absence absence) {
    final classeId = absence.classeId;
    if (classeId != null) {
      ref.invalidate(absencesByClasseProvider(classeId));
    }
    ref.invalidate(absencesByDivisionProvider(absence.divisionId));
    ref.invalidate(absencesToutesProvider);
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Absence absence,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Supprimer l\'absence'),
        content: const Text('Voulez-vous vraiment supprimer cette absence ?'),
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
      await ref.read(absencesRepositoryProvider).deleteAbsence(absence.id);
      _rafraichir(ref, absence);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Absence supprimée.'),
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

  Future<void> _markRetour(
    BuildContext context,
    WidgetRef ref,
    Absence absence,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await showDialog<_RetourResult>(
      context: context,
      builder: (context) => _MarkRetourDialog(dateDebut: absence.dateDebut),
    );
    if (result == null) return;
    try {
      await ref
          .read(absencesRepositoryProvider)
          .markRetour(
            absence.id,
            dateFin: result.dateFin,
            justifiee: result.justifiee,
            motif: result.motif,
          );
      _rafraichir(ref, absence);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Retour enregistré.'),
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

class _AbsenceTile extends StatelessWidget {
  const _AbsenceTile({
    required this.absence,
    required this.apprenant,
    required this.onDelete,
    required this.onMarkRetour,
    this.classeNom,
  });

  final Absence absence;
  final Apprenant? apprenant;
  final String? classeNom;
  final VoidCallback onDelete;
  final VoidCallback onMarkRetour;

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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${apprenant?.nomComplet ?? 'Apprenant inconnu'}'
                    '${classeNom != null ? ' · $classeNom' : ''}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    (absence.enCours
                            ? 'Depuis le ${fmt.format(absence.dateDebut)}'
                            : '${fmt.format(absence.dateDebut)} → ${fmt.format(absence.dateFin!)}') +
                        (absence.motif != null ? ' · ${absence.motif}' : ''),
                    style: const TextStyle(
                      color: AppColors.inkMuted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            if (absence.enCours) ...[
              const StatusChip(label: 'En cours', level: AlertLevel.warning),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: onMarkRetour,
                child: const Text('Marquer le retour'),
              ),
            ] else ...[
              const StatusChip(label: 'Terminée', level: AlertLevel.info),
              const SizedBox(width: 8),
              StatusChip(
                label: absence.justifiee ? 'Justifiée' : 'Non justifiée',
                level: absence.justifiee
                    ? AlertLevel.success
                    : AlertLevel.critical,
              ),
            ],
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
        ),
      ),
    );
  }
}

typedef _RetourResult = ({DateTime dateFin, bool justifiee, String? motif});

/// Petite boîte de dialogue pour marquer le retour d'un apprenant jusque-là
/// absent : date de retour, caractère justifié et motif (visible et
/// obligatoire seulement si justifiée).
class _MarkRetourDialog extends StatefulWidget {
  const _MarkRetourDialog({required this.dateDebut});

  final DateTime dateDebut;

  @override
  State<_MarkRetourDialog> createState() => _MarkRetourDialogState();
}

class _MarkRetourDialogState extends State<_MarkRetourDialog> {
  final _motifCtrl = TextEditingController();

  DateTime? _dateFin = DateTime.now();
  bool _justifiee = false;

  @override
  void initState() {
    super.initState();
    _motifCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _motifCtrl.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _dateFin != null && (!_justifiee || _motifCtrl.text.trim().isNotEmpty);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: const Text('Marquer le retour'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _dateFin ?? now,
                  firstDate: widget.dateDebut,
                  lastDate: now.add(const Duration(days: 730)),
                );
                if (picked != null) setState(() => _dateFin = picked);
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date de retour',
                  suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                ),
                child: Text(
                  _dateFin != null
                      ? DateFormat('dd/MM/yyyy').format(_dateFin!)
                      : '',
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Expanded(child: Text('Absence justifiée')),
                Switch(
                  value: _justifiee,
                  onChanged: (value) => setState(() => _justifiee = value),
                ),
              ],
            ),
            if (_justifiee) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _motifCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Motif'),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: !_isValid
              ? null
              : () => Navigator.of(context).pop((
                  dateFin: _dateFin!,
                  justifiee: _justifiee,
                  motif: _justifiee ? _emptyToNull(_motifCtrl.text) : null,
                )),
          child: const Text('Confirmer'),
        ),
      ],
    );
  }

  String? _emptyToNull(String value) =>
      value.trim().isEmpty ? null : value.trim();
}
