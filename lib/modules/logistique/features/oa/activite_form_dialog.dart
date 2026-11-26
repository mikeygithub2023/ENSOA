import 'package:sig_ensoa/core/formulaire.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sig_ensoa/modules/logistique/compat.dart';
import '../../data/models/oa.dart';
import '../../data/repositories/misc_providers.dart';
import '../../data/repositories/oa_providers.dart';
import '../../shared/widgets/widgets.dart';

/// Crée une activité, ou corrige une activité existante — la même boîte :
/// les champs sont les mêmes, seul le verbe change.
class ActiviteFormDialog extends ConsumerStatefulWidget {
  /// L'activité à corriger. Nulle pour une création.
  final Activite? activite;

  const ActiviteFormDialog({super.key, this.activite});

  @override
  ConsumerState<ActiviteFormDialog> createState() => _ActiviteFormDialogState();
}

class _ActiviteFormDialogState extends ConsumerState<ActiviteFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _titreCtrl = TextEditingController(
    text: widget.activite?.titre ?? '',
  );
  late final _descriptionCtrl = TextEditingController(
    text: widget.activite?.description ?? '',
  );
  late final _lieuCtrl = TextEditingController(
    text: widget.activite?.lieu ?? '',
  );
  late DateTime _date =
      widget.activite?.dateActivite.toLocal() ??
      DateTime.now().add(const Duration(days: 1));
  bool _envoi = false;

  bool get _correction => widget.activite != null;

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
      // Une activité déjà passée se corrige encore : sa date doit rester
      // proposée.
      firstDate: _date.isBefore(DateTime.now())
          ? _date
          : DateTime.now().subtract(const Duration(days: 1)),
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
      title: Text(_correction ? "Modifier l'activité" : 'Nouvelle activité'),
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
          child: Text(_correction ? 'Enregistrer' : 'Créer'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!validerFormulaire(context, _formKey)) return;
    setState(() => _envoi = true);
    final user = ref.read(sessionProvider)!.user;
    final description = _descriptionCtrl.text.trim().isEmpty
        ? null
        : _descriptionCtrl.text.trim();
    final lieu = _lieuCtrl.text.trim().isEmpty ? null : _lieuCtrl.text.trim();
    try {
      final activites = ref.read(activitesProvider.notifier);
      if (_correction) {
        await activites.modifier(
          id: widget.activite!.id,
          titre: _titreCtrl.text.trim(),
          description: description,
          dateActivite: _date,
          lieu: lieu,
        );
      } else {
        await activites.creer(
          titre: _titreCtrl.text.trim(),
          description: description,
          dateActivite: _date,
          lieu: lieu,
        );
      }
      ref
          .read(auditProvider.notifier)
          .log(
            auteurId: user.id,
            action: _correction ? 'ACTIVITE_MODIFIEE' : 'ACTIVITE_CREEE',
            cible: _titreCtrl.text.trim(),
          );
      if (mounted) {
        showSuccessSnackBar(
          context,
          _correction ? 'Activité modifiée.' : 'Activité créée avec succès.',
        );
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
