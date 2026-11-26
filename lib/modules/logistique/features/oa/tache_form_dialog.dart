import 'package:sig_ensoa/core/formulaire.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sig_ensoa/modules/logistique/compat.dart';
import '../../data/models/oa.dart';
import '../../data/repositories/misc_providers.dart';
import '../../data/repositories/oa_providers.dart';
import 'package:sig_ensoa/features/administration/providers/profils_personnalises_providers.dart';
import '../../shared/widgets/widgets.dart';

/// Le service destinataire d'une tâche, tel que la liste déroulante le
/// manipule.
///
/// Deux familles cohabitent : les quatre services écrits dans le code et
/// les profils que l'administrateur crée en base. Une clé de texte les
/// réunit dans une seule liste — « acteur:garage », « profil:identifiant » —, ce
/// qui évite deux listes côte à côte où l'on choisirait les deux.
String _cleActeur(ActeurTache a) => 'acteur:${a.name}';
String _cleProfil(String id) => 'profil:$id';

/// À qui la tâche va : à un service (et, au besoin, à l'une de ses
/// personnes), ou à un membre du personnel de l'école, sans service.
enum _Destination { service, personnel }

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
  final _personnelCtrl = TextEditingController();

  late _Destination _destination =
      widget.tache != null &&
          widget.tache!.acteur == null &&
          widget.tache!.profilPersonnaliseId == null
      ? _Destination.personnel
      : _Destination.service;

  late String _service = widget.tache?.profilPersonnaliseId != null
      ? _cleProfil(widget.tache!.profilPersonnaliseId!)
      : _cleActeur(widget.tache?.acteur ?? ActeurTache.st);

  /// La personne désignée, dans le service ou seule.
  late String? _personne = widget.tache?.assigneA;

  late DateTime? _dateLimite = widget.tache?.dateLimite;
  bool _envoi = false;
  String? _erreurPersonnel;

  bool get _correction => widget.tache != null;

  ActeurTache? get _acteurChoisi => _service.startsWith('acteur:')
      ? ActeurTache.values.firstWhere((a) => _cleActeur(a) == _service)
      : null;

  String? get _profilChoisi =>
      _service.startsWith('profil:') ? _service.substring(7) : null;

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    _personnelCtrl.dispose();
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
    final personnes =
        ref.watch(personnesPourTachesProvider).value ??
        const <PersonneAssignable>[];
    final duService = personnes
        .where(
          (p) => p.estDuService(
            acteur: _acteurChoisi,
            profilPersonnaliseId: _profilChoisi,
          ),
        )
        .toList();

    return AlertDialog(
      scrollable: true,
      title: Text(
        '${_correction ? "Modifier la tâche" : "Assigner une tâche"}'
        ' — ${widget.activite.titre}',
      ),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<_Destination>(
                segments: const [
                  ButtonSegment(
                    value: _Destination.service,
                    icon: Icon(Icons.groups_outlined),
                    label: Text('Un service'),
                  ),
                  ButtonSegment(
                    value: _Destination.personnel,
                    icon: Icon(Icons.person_outline),
                    label: Text("Un personnel de l'école"),
                  ),
                ],
                selected: {_destination},
                onSelectionChanged: (s) => setState(() {
                  _destination = s.first;
                  _personne = null;
                  _personnelCtrl.clear();
                  _erreurPersonnel = null;
                }),
              ),
              const SizedBox(height: 16),
              if (_destination == _Destination.service) ...[
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _service,
                  decoration: const InputDecoration(labelText: 'Service'),
                  items: [
                    for (final a in ActeurTache.values)
                      DropdownMenuItem(
                        value: _cleActeur(a),
                        child: Text(a.label),
                      ),
                    // Les services créés par l'administrateur. Ceux qui ont
                    // été retirés ne paraissent plus : on ne confie pas de
                    // travail à un service dissous.
                    for (final p in ref.watch(
                      profilsPersonnalisesActifsProvider,
                    ))
                      DropdownMenuItem(
                        value: _cleProfil(p.id),
                        child: Text(p.libelle),
                      ),
                  ],
                  onChanged: (v) => setState(() {
                    _service = v ?? _service;
                    // Une personne d'un autre service ne suit pas.
                    _personne = null;
                  }),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  // La clé suit le service : changer de service repart
                  // d'une liste neuve.
                  key: ValueKey('personne-$_service'),
                  isExpanded: true,
                  initialValue: duService.any((p) => p.id == _personne)
                      ? _personne
                      : null,
                  decoration: InputDecoration(
                    labelText: 'Personne du service (facultatif)',
                    helperText: duService.isEmpty
                        ? 'Aucun compte rattaché à ce service.'
                        : null,
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Tout le service'),
                    ),
                    for (final p in duService)
                      DropdownMenuItem<String?>(
                        value: p.id,
                        child: Text(p.nom, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) => setState(() => _personne = v),
                ),
              ] else
                LayoutBuilder(
                  builder: (context, contraintes) => DropdownMenu<String>(
                    controller: _personnelCtrl,
                    width: contraintes.maxWidth,
                    menuHeight: 320,
                    enableFilter: true,
                    requestFocusOnTap: true,
                    initialSelection: _personne,
                    label: const Text("Personnel de l'école"),
                    hintText: 'Tapez un nom',
                    errorText: _erreurPersonnel,
                    dropdownMenuEntries: [
                      for (final p in personnes)
                        DropdownMenuEntry(value: p.id, label: p.nom),
                    ],
                    onSelected: (v) => setState(() {
                      _personne = v;
                      _erreurPersonnel = null;
                    }),
                  ),
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
    final versPersonnel = _destination == _Destination.personnel;
    if (versPersonnel && _personne == null) {
      setState(() => _erreurPersonnel = 'Choisissez la personne dans la liste');
    }
    if (!validerFormulaire(context, _formKey)) return;
    if (versPersonnel && _personne == null) return;
    setState(() => _envoi = true);
    final user = ref.read(sessionProvider)!.user;

    final acteur = versPersonnel ? null : _acteurChoisi;
    final profilId = versPersonnel ? null : _profilChoisi;
    final personnes =
        ref.read(personnesPourTachesProvider).value ??
        const <PersonneAssignable>[];
    String? nomPersonne;
    for (final p in personnes) {
      if (p.id == _personne) nomPersonne = p.nom;
    }
    final nomService =
        acteur?.label ??
        (profilId == null
            ? null
            : ref
                  .read(profilsPersonnalisesActifsProvider)
                  .firstWhere((p) => p.id == profilId)
                  .libelle);
    final nomDestinataire = [
      nomService,
      nomPersonne,
    ].whereType<String>().join(' — ');
    try {
      if (_correction) {
        await ref
            .read(tachesProvider.notifier)
            .modifier(
              id: widget.tache!.id,
              acteur: acteur,
              profilPersonnaliseId: profilId,
              assigneA: _personne,
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
              assigneA: _personne,
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
