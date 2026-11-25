// Inscrire un mouvement du personnel.
//
// Le formulaire ne demande que ce que le mouvement exige : le service pour
// une mutation ou une mise à disposition, l'unité d'accueil pour un
// reversement. Il dit aussi, avant qu'on valide, ce que le mouvement fera
// du militaire — un reversement le retire de l'effectif, et ce n'est pas
// une chose qu'on doit découvrir après coup.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:sig_ensoa/core/erreurs.dart';
import 'package:sig_ensoa/core/theme.dart';
import '../../models/apprenant.dart';
import '../../models/mouvement_personnel.dart';
import 'data/mouvements_repository.dart';
import 'providers/apprenants_providers.dart';
import 'providers/mouvements_providers.dart';

Future<void> showRegisterMouvementDialog(
  BuildContext context, {
  required Apprenant apprenant,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.all(24),
      child: RegisterMouvementDialog(apprenant: apprenant),
    ),
  );
}

/// Les mouvements qui ont un sens pour ce militaire, aujourd'hui : on ne
/// fait pas revenir quelqu'un qui n'est parti nulle part.
List<NatureMouvement> naturesPossibles(Apprenant a) {
  final parti =
      a.statut == ApprenantStatut.reverse ||
      (a.positionStatutaire ?? '').toUpperCase() == 'MIS A DISPOSITION';
  if (a.statut == ApprenantStatut.reverse) {
    return const [NatureMouvement.retour];
  }
  return [
    NatureMouvement.affectation,
    NatureMouvement.mutation,
    NatureMouvement.miseADisposition,
    NatureMouvement.reversement,
    if (parti) NatureMouvement.retour,
  ];
}

class RegisterMouvementDialog extends ConsumerStatefulWidget {
  const RegisterMouvementDialog({super.key, required this.apprenant});

  final Apprenant apprenant;

  @override
  ConsumerState<RegisterMouvementDialog> createState() =>
      _RegisterMouvementDialogState();
}

class _RegisterMouvementDialogState
    extends ConsumerState<RegisterMouvementDialog> {
  final _formKey = GlobalKey<FormState>();
  final _serviceCtrl = TextEditingController();
  final _uniteCtrl = TextEditingController();
  final _referenceCtrl = TextEditingController();
  final _observationCtrl = TextEditingController();

  late NatureMouvement _nature;
  DateTime _date = DateTime.now();
  bool _envoi = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _nature = naturesPossibles(widget.apprenant).first;
  }

  @override
  void dispose() {
    _serviceCtrl.dispose();
    _uniteCtrl.dispose();
    _referenceCtrl.dispose();
    _observationCtrl.dispose();
    super.dispose();
  }

  String? _vide(String texte) => texte.trim().isEmpty ? null : texte.trim();

  Future<void> _soumettre() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _envoi = true;
      _erreur = null;
    });
    try {
      await ref
          .read(mouvementsRepositoryProvider)
          .inscrire(
            MouvementDraft(
              apprenantId: widget.apprenant.id,
              nature: _nature,
              dateEffet: _date,
              serviceApres: _vide(_serviceCtrl.text)?.toUpperCase(),
              uniteAccueil: _vide(_uniteCtrl.text)?.toUpperCase(),
              reference: _vide(_referenceCtrl.text),
              observation: _vide(_observationCtrl.text),
            ),
          );
      // La fiche a changé avec le mouvement : statut, service, unité.
      ref.invalidate(mouvementsByApprenantProvider(widget.apprenant.id));
      ref.invalidate(apprenantByIdProvider(widget.apprenant.id));
      ref.invalidate(apprenantsListProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _envoi = false;
          _erreur = messageErreur(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.apprenant;
    final natures = naturesPossibles(a);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enregistrer un mouvement',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                [
                  '${a.grade ?? ''} ${a.nom} ${a.prenom}'.trim(),
                  if ((a.serviceAffectation ?? '').isNotEmpty)
                    a.serviceAffectation!,
                ].join(' · '),
                style: const TextStyle(color: AppColors.inkMuted),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<NatureMouvement>(
                initialValue: _nature,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Mouvement *'),
                items: [
                  for (final n in natures)
                    DropdownMenuItem(value: n, child: Text(n.libelle)),
                ],
                onChanged: _envoi
                    ? null
                    : (n) => setState(() => _nature = n ?? _nature),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _nature == NatureMouvement.reversement
                      ? AppColors.warning.withValues(alpha: 0.10)
                      : AppColors.blueMist,
                  borderRadius: BorderRadius.circular(AppRadii.control),
                ),
                child: Text(
                  _nature.explication,
                  style: const TextStyle(fontSize: 13, color: AppColors.ink),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Date d\'effet *',
                      ),
                      child: Text(DateFormat('dd/MM/yyyy').format(_date)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _envoi
                        ? null
                        : () async {
                            final choix = await showDatePicker(
                              context: context,
                              initialDate: _date,
                              firstDate: DateTime(1980),
                              lastDate: DateTime.now().add(
                                const Duration(days: 366),
                              ),
                            );
                            if (choix != null) setState(() => _date = choix);
                          },
                    child: const Text('Choisir'),
                  ),
                ],
              ),
              if (_nature.demandeService) ...[
                const SizedBox(height: 12),
                TextFormField(
                  key: ValueKey('service-${_nature.name}'),
                  controller: _serviceCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: switch (_nature) {
                      NatureMouvement.miseADisposition =>
                        'Formation d\'accueil *',
                      NatureMouvement.mutation => 'Nouveau service *',
                      _ => 'Service (facultatif)',
                    },
                    hintText: _nature == NatureMouvement.miseADisposition
                        ? 'EMGA/DES, CCAS/AFA…'
                        : 'ENSOA/BRH, CCAS/ENSOA…',
                  ),
                  validator: (v) =>
                      _nature.serviceObligatoire && _vide(v ?? '') == null
                      ? 'Indiquez où il va'
                      : null,
                ),
              ],
              if (_nature.demandeUnite) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _uniteCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Unité d\'accueil *',
                    hintText: 'AFA, 1er BPP…',
                  ),
                  validator: (v) =>
                      _vide(v ?? '') == null ? 'Indiquez l\'unité' : null,
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _referenceCtrl,
                decoration: const InputDecoration(
                  labelText: 'Référence',
                  hintText: 'Décision, note de service, message',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _observationCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Observation'),
              ),
              const SizedBox(height: 8),
              const Text(
                'Un mouvement inscrit ne se modifie plus : il entre au '
                'journal du militaire.',
                style: TextStyle(fontSize: 12, color: AppColors.inkMuted),
              ),
              if (_erreur != null) ...[
                const SizedBox(height: 12),
                Text(_erreur!, style: const TextStyle(color: AppColors.danger)),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  const Spacer(),
                  TextButton(
                    onPressed: _envoi
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _envoi ? null : _soumettre,
                    child: _envoi
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Enregistrer'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
