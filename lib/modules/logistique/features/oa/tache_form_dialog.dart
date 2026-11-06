import 'package:sig_ensoa/core/formulaire.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sig_ensoa/modules/logistique/compat.dart';
import '../../data/models/oa.dart';
import '../../data/repositories/misc_providers.dart';
import '../../data/repositories/oa_providers.dart';
import 'package:sig_ensoa/features/administration/providers/profils_personnalises_providers.dart';
import '../../shared/widgets/widgets.dart';

/// Le destinataire d'une tâche, tel que la liste déroulante le manipule.
///
/// Deux familles cohabitent : les quatre services écrits dans le code et
/// les profils que l'administrateur crée en base. Une clé de texte les
/// réunit dans une seule liste — « acteur:garage », « profil:identifiant » —, ce
/// qui évite deux listes côte à côte où l'on choisirait les deux.
String _cleActeur(ActeurTache a) => 'acteur:${a.name}';
String _cleProfil(String id) => 'profil:$id';

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
  late String _destinataire = widget.tache?.profilPersonnaliseId != null
      ? _cleProfil(widget.tache!.profilPersonnaliseId!)
      : _cleActeur(widget.tache?.acteur ?? ActeurTache.st);
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
      // Une activité déjà commencée a sa date dans le passé, que le calendrier
      // ne proposerait pas.
      initialDate: widget.activite.dateActivite.isBefore(DateTime.now())
          ? DateTime.now()
          : widget.activite.dateActivite,
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
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _destinataire,
                decoration: const InputDecoration(labelText: 'Acteur'),
                items: [
                  for (final a in ActeurTache.values)
                    DropdownMenuItem(
                      value: _cleActeur(a),
                      child: Text(a.label),
                    ),
                  // Les services créés par l'administrateur. Ceux qui ont
                  // été retirés ne paraissent plus : on ne confie pas de
                  // travail à un service dissous.
                  for (final p in ref.watch(profilsPersonnalisesActifsProvider))
                    DropdownMenuItem(
                      value: _cleProfil(p.id),
                      child: Text(p.libelle),
                    ),
                ],
                onChanged: (v) =>
                    setState(() => _destinataire = v ?? _destinataire),
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
    if (!validerFormulaire(context, _formKey)) return;
    setState(() => _envoi = true);
    final user = ref.read(sessionProvider)!.user;

    final versProfil = _destinataire.startsWith('profil:');
    final profilId = versProfil ? _destinataire.substring(7) : null;
    final acteur = versProfil
        ? null
        : ActeurTache.values.firstWhere((a) => _cleActeur(a) == _destinataire);
    final nomDestinataire = versProfil
        ? ref
              .read(profilsPersonnalisesActifsProvider)
              .firstWhere((p) => p.id == profilId)
              .libelle
        : acteur!.label;
    try {
      if (_correction) {
        await ref
            .read(tachesProvider.notifier)
            .modifier(
              id: widget.tache!.id,
              acteur: acteur,
              profilPersonnaliseId: profilId,
              description: _descriptionCtrl.text.trim(),
              dateLimite: _dateLimite,
            );
      } else {
        await ref
            .read(tachesProvider.notifier)
            .assigner(
              activiteId: widget.activite.id,
              acteur: acteur,
              profilPersonnaliseId: profilId,
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
            detail: '$nomDestinataire — ${_descriptionCtrl.text.trim()}',
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
        showErrorSnackBar(context, e);
      }
    }
  }
}
