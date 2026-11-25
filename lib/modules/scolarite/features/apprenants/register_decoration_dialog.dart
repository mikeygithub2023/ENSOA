// Inscrire une décoration reçue.
//
// Une attribution se prouve par un texte — décret, arrêté, décision, ordre
// général. La référence n'est donc pas une coquetterie d'archiviste : c'est
// ce qui permet de répondre quand la Direction des Ressources Humaines
// demande au nom de quoi cet homme porte cette médaille.
//
// La date reste facultative. Une médaille portée depuis quinze ans dont le
// décret ne se retrouve pas vaut mieux inscrite sans date que pas inscrite
// du tout — et l'écran le dit, pour qu'on ne croie pas à un oubli.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:sig_ensoa/core/erreurs.dart';
import 'package:sig_ensoa/core/theme.dart' hide AlertLevel, AlertLevelColor;
import 'package:sig_ensoa/modules/scolarite/compat.dart';
import '../../models/apprenant.dart';
import '../../models/decoration.dart';
import 'catalogues_rh_dialog.dart';
import 'data/decorations_repository.dart';
import 'providers/decorations_providers.dart';

/// Ouvre la saisie d'une décoration.
///
/// [apprenants] est l'effectif où choisir le récipiendaire — nul quand on
/// vient de la fiche d'un militaire, qui est alors imposé par [apprenant].
/// [existante] remplit le formulaire pour une correction.
Future<void> showRegisterDecorationDialog(
  BuildContext context, {
  List<Apprenant>? apprenants,
  Apprenant? apprenant,
  DecorationRecue? existante,
}) {
  assert(
    apprenants != null || apprenant != null,
    'Il faut un effectif où choisir, ou un militaire imposé.',
  );
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.all(24),
      child: _RegisterDecorationDialog(
        apprenants: apprenants,
        apprenantImpose: apprenant,
        existante: existante,
      ),
    ),
  );
}

class _RegisterDecorationDialog extends ConsumerStatefulWidget {
  const _RegisterDecorationDialog({
    required this.apprenants,
    required this.apprenantImpose,
    required this.existante,
  });

  final List<Apprenant>? apprenants;
  final Apprenant? apprenantImpose;
  final DecorationRecue? existante;

  @override
  ConsumerState<_RegisterDecorationDialog> createState() =>
      _RegisterDecorationDialogState();
}

class _RegisterDecorationDialogState
    extends ConsumerState<_RegisterDecorationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _referenceCtrl = TextEditingController();
  final _echelonCtrl = TextEditingController();
  final _observationCtrl = TextEditingController();

  String? _apprenantId;
  String? _decorationId;
  DateTime? _date;
  bool _envoi = false;
  String? _erreur;

  bool get _correction => widget.existante != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existante;
    _apprenantId = e?.apprenantId ?? widget.apprenantImpose?.id;
    _decorationId = e?.decorationId;
    _date = e?.dateAttribution;
    _referenceCtrl.text = e?.reference ?? '';
    _echelonCtrl.text = e?.echelon ?? '';
    _observationCtrl.text = e?.observation ?? '';
  }

  @override
  void dispose() {
    _referenceCtrl.dispose();
    _echelonCtrl.dispose();
    _observationCtrl.dispose();
    super.dispose();
  }

  String? _vide(String texte) => texte.trim().isEmpty ? null : texte.trim();

  Future<void> _soumettre() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final apprenantId = _apprenantId;
    final decorationId = _decorationId;
    if (apprenantId == null || decorationId == null) return;

    setState(() {
      _envoi = true;
      _erreur = null;
    });
    final draft = DecorationRecueDraft(
      apprenantId: apprenantId,
      decorationId: decorationId,
      dateAttribution: _date,
      reference: _vide(_referenceCtrl.text),
      echelon: _vide(_echelonCtrl.text),
      observation: _vide(_observationCtrl.text),
    );
    try {
      final depot = ref.read(decorationsRepositoryProvider);
      if (_correction) {
        await depot.modifier(widget.existante!.id, draft);
      } else {
        await depot.creer(draft);
      }
      ref.invalidate(decorationsRecuesProvider);
      ref.invalidate(decorationsRecuesByApprenantProvider(apprenantId));
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _correction ? 'Décoration corrigée.' : 'Décoration inscrite.',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _envoi = false;
        _erreur = 'Enregistrement refusé : ${messageErreur(e)}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalogueAsync = ref.watch(catalogueDecorationsProvider);
    final catalogue = catalogueAsync.value ?? const <TypeDecoration>[];
    final estAdmin =
        ref.watch(currentProfileProvider).value?.role == AppRole.admin;
    final effectif = widget.apprenants;

    final taille = MediaQuery.of(context).size;
    final largeur = taille.width - 48 < 620 ? taille.width - 48 : 620.0;

    return SizedBox(
      width: largeur,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _correction
                          ? 'Corriger une décoration'
                          : 'Inscrire une décoration',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _envoi
                        ? null
                        : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (catalogue.isEmpty) ...[
                const Text(
                  'Le catalogue des décorations est vide. Il se saisit une '
                  'fois, par l\'administrateur, et sert à toute l\'école.',
                  style: TextStyle(color: AppColors.inkMuted, fontSize: 13),
                ),
                const SizedBox(height: 12),
                if (estAdmin)
                  FilledButton.icon(
                    onPressed: () => showCatalogueDecorationsDialog(context),
                    icon: const Icon(Icons.playlist_add, size: 18),
                    label: const Text('Saisir le catalogue'),
                  ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Fermer'),
                  ),
                ),
              ] else ...[
                if (effectif != null) ...[
                  DropdownButtonFormField<String>(
                    initialValue: _apprenantId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Militaire *'),
                    items: [
                      for (final a in effectif)
                        DropdownMenuItem(
                          value: a.id,
                          child: Text(
                            a.grade == null
                                ? a.nomComplet
                                : '${a.grade} ${a.nomComplet}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    validator: (v) =>
                        v == null ? 'Désignez le récipiendaire' : null,
                    onChanged: _envoi
                        ? null
                        : (v) => setState(() => _apprenantId = v),
                  ),
                  const SizedBox(height: 12),
                ] else if (widget.apprenantImpose != null) ...[
                  Text(
                    widget.apprenantImpose!.grade == null
                        ? widget.apprenantImpose!.nomComplet
                        : '${widget.apprenantImpose!.grade} '
                              '${widget.apprenantImpose!.nomComplet}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                DropdownButtonFormField<String>(
                  initialValue: _decorationId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Décoration *'),
                  items: [
                    for (final d in catalogue)
                      DropdownMenuItem(
                        value: d.id,
                        child: Text(d.libelle, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  validator: (v) =>
                      v == null ? 'Choisissez la décoration' : null,
                  onChanged: _envoi
                      ? null
                      : (v) => setState(() => _decorationId = v),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date d\'attribution',
                        ),
                        child: Text(
                          _date == null
                              ? 'Non renseignée'
                              : DateFormat('dd/MM/yyyy').format(_date!),
                          style: TextStyle(
                            color: _date == null
                                ? AppColors.inkMuted
                                : AppColors.ink,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: _envoi
                          ? null
                          : () async {
                              final choix = await showDatePicker(
                                context: context,
                                initialDate: _date ?? DateTime.now(),
                                firstDate: DateTime(1960),
                                lastDate: DateTime.now(),
                              );
                              if (choix != null) {
                                setState(() => _date = choix);
                              }
                            },
                      child: const Text('Choisir'),
                    ),
                    if (_date != null)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        tooltip: 'Retirer la date',
                        onPressed: _envoi
                            ? null
                            : () => setState(() => _date = null),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Facultative : une médaille dont le texte ne se retrouve '
                  'plus vaut mieux inscrite sans date que pas inscrite.',
                  style: TextStyle(color: AppColors.inkMuted, fontSize: 12),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _referenceCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Référence du texte',
                    hintText: 'Décret, arrêté, décision, ordre général',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _echelonCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Échelon ou agrafe',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _observationCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Observation'),
                ),
                if (_erreur != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _erreur!,
                    style: const TextStyle(color: AppColors.danger),
                  ),
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
                          : Text(_correction ? 'Corriger' : 'Inscrire'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
