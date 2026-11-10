import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:sig_ensoa/core/formulaire.dart';
import 'package:sig_ensoa/core/roles.dart';
import 'package:sig_ensoa/features/administration/providers/comptes_providers.dart';
import 'package:sig_ensoa/features/auth/providers/auth_providers.dart';
import '../../data/models/oa.dart';
import '../../data/repositories/oa_providers.dart';
import '../../shared/widgets/widgets.dart';

/// Écrit une tâche quotidienne, pour soi — ou, pour un administrateur, pour
/// quelqu'un d'autre. La même boîte sert à la corriger.
class TacheQuotidienneFormDialog extends ConsumerStatefulWidget {
  const TacheQuotidienneFormDialog({super.key, this.tache, this.jour});

  final TacheQuotidienne? tache;

  /// Le jour choisi sur le calendrier, proposé comme échéance.
  final DateTime? jour;

  @override
  ConsumerState<TacheQuotidienneFormDialog> createState() =>
      _TacheQuotidienneFormDialogState();
}

class _TacheQuotidienneFormDialogState
    extends ConsumerState<TacheQuotidienneFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _descriptionCtrl = TextEditingController(
    text: widget.tache?.description ?? '',
  );
  late DateTime? _echeance = widget.tache?.echeance?.toLocal() ?? widget.jour;
  late PrioriteTache _priorite =
      widget.tache?.priorite ?? PrioriteTache.normale;
  late String? _assigneA = widget.tache?.assigneA;
  bool _envoi = false;

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    super.dispose();
  }

  bool get _aUneHeure =>
      _echeance != null && (_echeance!.hour != 0 || _echeance!.minute != 0);

  Future<void> _choisirDate() async {
    final maintenant = DateTime.now();
    final depart = _echeance ?? maintenant;
    final date = await showDatePicker(
      context: context,
      initialDate: depart,
      // Une échéance déjà passée doit rester corrigeable.
      firstDate: depart.isBefore(maintenant) ? depart : maintenant,
      lastDate: maintenant.add(const Duration(days: 730)),
    );
    if (date == null) return;
    setState(
      () => _echeance = DateTime(
        date.year,
        date.month,
        date.day,
        _echeance?.hour ?? 0,
        _echeance?.minute ?? 0,
      ),
    );
  }

  Future<void> _choisirHeure() async {
    final base = _echeance ?? DateTime.now();
    final heure = await showTimePicker(
      context: context,
      initialTime: _aUneHeure
          ? TimeOfDay.fromDateTime(base)
          : const TimeOfDay(hour: 8, minute: 0),
    );
    if (heure == null) return;
    setState(
      () => _echeance = DateTime(
        base.year,
        base.month,
        base.day,
        heure.hour,
        heure.minute,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profil = ref.watch(profilCourantProvider).value;
    final administrateur =
        profil?.peut(Permission.administrerPlateforme) ?? false;
    final correction = widget.tache != null;
    final comptes = administrateur
        ? (ref.watch(comptesProvider).value ?? const [])
              .where((c) => c.actif)
              .toList()
        : const [];
    comptes.sort((a, b) => a.nomDUsage.compareTo(b.nomDUsage));

    return AlertDialog(
      scrollable: true,
      title: Text(correction ? 'Modifier la tâche' : 'Nouvelle tâche'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _descriptionCtrl,
                autofocus: !correction,
                decoration: const InputDecoration(
                  labelText: 'Tâche à réaliser',
                ),
                maxLines: 2,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Requis' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: InkWell(
                      onTap: _choisirDate,
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Échéance (optionnel)',
                          suffixIcon: _echeance == null
                              ? const Icon(Icons.calendar_today_outlined)
                              : IconButton(
                                  tooltip: "Retirer l'échéance",
                                  icon: const Icon(Icons.close),
                                  onPressed: () =>
                                      setState(() => _echeance = null),
                                ),
                        ),
                        child: Text(
                          _echeance == null
                              ? 'Aucune'
                              : DateFormat('dd/MM/yyyy').format(_echeance!),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: InkWell(
                      onTap: _echeance == null ? null : _choisirHeure,
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Heure',
                          enabled: _echeance != null,
                        ),
                        child: Text(
                          _aUneHeure
                              ? DateFormat("HH'h'mm").format(_echeance!)
                              : '—',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<PrioriteTache>(
                initialValue: _priorite,
                decoration: const InputDecoration(labelText: 'Priorité'),
                items: [
                  for (final p in PrioriteTache.values)
                    DropdownMenuItem(value: p, child: Text(p.label)),
                ],
                onChanged: (v) => setState(() => _priorite = v ?? _priorite),
              ),
              // Seul un administrateur impute : pour les autres, la tâche est
              // la leur, et la base refuserait toute autre chose.
              if (administrateur) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _assigneA ?? profil?.id,
                  decoration: const InputDecoration(labelText: 'Imputée à'),
                  items: [
                    if (profil != null &&
                        !comptes.any((c) => c.id == profil.id))
                      DropdownMenuItem(
                        value: profil.id,
                        child: const Text('Moi'),
                      ),
                    for (final c in comptes)
                      DropdownMenuItem(
                        value: c.id,
                        child: Text(
                          c.id == profil?.id ? 'Moi' : c.identiteComplete,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() => _assigneA = v),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _envoi ? null : _submit,
          child: Text(correction ? 'Enregistrer' : 'Ajouter'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!validerFormulaire(context, _formKey)) return;
    final moi = ref.read(profilCourantProvider).value?.id;
    final assigneA = _assigneA ?? moi;
    if (assigneA == null) return;

    setState(() => _envoi = true);
    final notifier = ref.read(tachesQuotidiennesProvider.notifier);
    try {
      if (widget.tache != null) {
        await notifier.modifier(
          id: widget.tache!.id,
          description: _descriptionCtrl.text.trim(),
          echeance: _echeance,
          priorite: _priorite,
          assigneA: assigneA,
        );
      } else {
        await notifier.creer(
          description: _descriptionCtrl.text.trim(),
          echeance: _echeance,
          priorite: _priorite,
          assigneA: assigneA,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _envoi = false);
        showErrorSnackBar(context, e);
      }
    }
  }
}
