import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sig_ensoa/modules/logistique/compat.dart';
import '../../data/models/oa.dart';
import '../../data/repositories/misc_providers.dart';
import '../../data/repositories/oa_providers.dart';
import '../../shared/widgets/widgets.dart';

/// Assigne une tâche, ou corrige une tâche déjà assignée — la même boîte
/// pour les deux : les champs sont les mêmes, seul le verbe change.
class TacheFormDialog extends ConsumerStatefulWidget {
  final Activite activite;

  /// La tâche à corriger. Nulle pour une assignation.
  final TacheActivite? tache;

  const TacheFormDialog({super.key, required this.activite, this.tache});

  @override
  ConsumerState<TacheFormDialog> createState() => _TacheFormDialogState();
}

class _TacheFormDialogState extends ConsumerState<TacheFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _descriptionCtrl = TextEditingController(
    text: widget.tache?.description ?? '',
  );
  late ActeurTache _acteur = widget.tache?.acteur ?? ActeurTache.st;
  late DateTime? _dateLimite = widget.tache?.dateLimite;
  bool _envoi = false;

  bool get _correction => widget.tache != null;

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _choisirDateLimite() async {
    final date = await showDatePicker(
      context: context,
      initialDate: widget.activite.dateActivite,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (date != null) setState(() => _dateLimite = date);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: Text(
        '${_correction ? "Modifier la tâche" : "Assigner une tâche"}'
        ' — ${widget.activite.titre}',
      ),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<ActeurTache>(
                isExpanded: true,
                initialValue: _acteur,
                decoration: const InputDecoration(labelText: 'Acteur'),
                items: [
                  for (final a in ActeurTache.values)
                    DropdownMenuItem(value: a, child: Text(a.label)),
                ],
                onChanged: (v) => setState(() => _acteur = v ?? ActeurTache.st),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tâche à réaliser',
                ),
                maxLines: 2,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Requis' : null,
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _choisirDateLimite,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Échéance (optionnel)',
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _dateLimite == null
                              ? 'Aucune'
                              : '${_dateLimite!.day.toString().padLeft(2, '0')}/${_dateLimite!.month.toString().padLeft(2, '0')}/${_dateLimite!.year}',
                        ),
                      ),
                      const Icon(Icons.calendar_today_outlined, size: 18),
                    ],
                  ),
                ),
              ),
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
          child: Text(_correction ? 'Enregistrer' : 'Assigner'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _envoi = true);
    final user = ref.read(sessionProvider)!.user;
    try {
      if (_correction) {
        await ref
            .read(tachesProvider.notifier)
            .modifier(
              id: widget.tache!.id,
              acteur: _acteur,
              description: _descriptionCtrl.text.trim(),
              dateLimite: _dateLimite,
            );
      } else {
        await ref
            .read(tachesProvider.notifier)
            .assigner(
              activiteId: widget.activite.id,
              acteur: _acteur,
              description: _descriptionCtrl.text.trim(),
              dateLimite: _dateLimite,
              titreActivite: widget.activite.titre,
            );
      }
      ref
          .read(auditProvider.notifier)
          .log(
            auteurId: user.id,
            action: _correction ? 'TACHE_MODIFIEE' : 'TACHE_ASSIGNEE',
            cible: widget.activite.titre,
            detail: '${_acteur.label} — ${_descriptionCtrl.text.trim()}',
          );
      if (mounted) {
        showSuccessSnackBar(
          context,
          _correction ? 'Tâche modifiée.' : 'Tâche assignée avec succès.',
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _envoi = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur Supabase : $e')));
      }
    }
  }
}
