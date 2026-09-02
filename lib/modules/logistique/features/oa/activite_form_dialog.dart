import 'package:sig_ensoa/core/formulaire.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sig_ensoa/modules/logistique/compat.dart';
import '../../data/repositories/misc_providers.dart';
import '../../data/repositories/oa_providers.dart';
import '../../shared/widgets/widgets.dart';

class ActiviteFormDialog extends ConsumerStatefulWidget {
  const ActiviteFormDialog({super.key});

  @override
  ConsumerState<ActiviteFormDialog> createState() => _ActiviteFormDialogState();
}

class _ActiviteFormDialogState extends ConsumerState<ActiviteFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titreCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _lieuCtrl = TextEditingController();
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  bool _envoi = false;

  @override
  void dispose() {
    _titreCtrl.dispose();
    _descriptionCtrl.dispose();
    _lieuCtrl.dispose();
    super.dispose();
  }

  Future<void> _choisirDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (date == null || !mounted) return;
    final heure = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_date),
    );
    setState(
      () => _date = DateTime(
        date.year,
        date.month,
        date.day,
        heure?.hour ?? 8,
        heure?.minute ?? 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final df =
        '${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year} à '
        '${_date.hour.toString().padLeft(2, '0')}:${_date.minute.toString().padLeft(2, '0')}';
    return AlertDialog(
      scrollable: true,
      title: const Text('Nouvelle activité'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titreCtrl,
                decoration: const InputDecoration(labelText: 'Titre'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Requis' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionCtrl,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _lieuCtrl,
                decoration: const InputDecoration(labelText: 'Lieu'),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _choisirDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date et heure de l\'activité',
                  ),
                  child: Row(
                    children: [
                      Expanded(child: Text(df)),
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
          child: const Text('Créer'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!validerFormulaire(context, _formKey)) return;
    setState(() => _envoi = true);
    final user = ref.read(sessionProvider)!.user;
    try {
      await ref
          .read(activitesProvider.notifier)
          .creer(
            titre: _titreCtrl.text.trim(),
            description: _descriptionCtrl.text.trim().isEmpty
                ? null
                : _descriptionCtrl.text.trim(),
            dateActivite: _date,
            lieu: _lieuCtrl.text.trim().isEmpty ? null : _lieuCtrl.text.trim(),
          );
      ref
          .read(auditProvider.notifier)
          .log(
            auteurId: user.id,
            action: 'ACTIVITE_CREEE',
            cible: _titreCtrl.text.trim(),
          );
      if (mounted) {
        showSuccessSnackBar(context, 'Activité créée avec succès.');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _envoi = false);
        showErrorSnackBar(context, e);
      }
    }
  }
}
