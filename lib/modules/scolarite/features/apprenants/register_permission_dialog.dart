import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:sig_ensoa/core/erreurs.dart';
import 'package:sig_ensoa/core/theme.dart' hide AlertLevel, AlertLevelColor;
import '../../models/apprenant.dart';
import '../../models/classe.dart';
import '../../models/division.dart';
import '../../models/permission.dart';
import 'data/permissions_repository.dart';
import 'providers/permissions_providers.dart';

/// [existante] non nulle : on corrige une permission déjà accordée plutôt
/// que d'en accorder une nouvelle. Le bénéficiaire ne se change pas — se
/// tromper d'élève se répare en supprimant la permission et en la reprenant,
/// car c'en est une autre.
Future<void> showRegisterPermissionDialog(
  BuildContext context, {
  required Division division,
  required Classe classe,
  required List<Apprenant> apprenants,
  Permission? existante,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.all(24),
      child: _RegisterPermissionDialog(
        division: division,
        classe: classe,
        apprenants: apprenants,
        existante: existante,
      ),
    ),
  );
}

class _RegisterPermissionDialog extends ConsumerStatefulWidget {
  const _RegisterPermissionDialog({
    required this.division,
    required this.classe,
    required this.apprenants,
    this.existante,
  });

  final Division division;
  final Classe classe;
  final List<Apprenant> apprenants;
  final Permission? existante;

  @override
  ConsumerState<_RegisterPermissionDialog> createState() =>
      _RegisterPermissionDialogState();
}

class _RegisterPermissionDialogState
    extends ConsumerState<_RegisterPermissionDialog> {
  final _localiteCtrl = TextEditingController();
  final _motifCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();

  Apprenant? _apprenant;
  DateTime? _dateDepart = DateTime.now();
  DateTime? _dateRetour;
  bool _submitting = false;
  String? _error;

  bool get _correction => widget.existante != null;

  @override
  void initState() {
    super.initState();
    final existante = widget.existante;
    if (existante == null) return;

    _localiteCtrl.text = existante.localite ?? '';
    _motifCtrl.text = existante.motif ?? '';
    _contactCtrl.text = existante.personneContact ?? '';
    _dateDepart = existante.dateDepart;
    _dateRetour = existante.dateRetour;
    _apprenant = widget.apprenants
        .where((a) => a.id == existante.apprenantId)
        .firstOrNull;
  }

  @override
  void dispose() {
    _localiteCtrl.dispose();
    _motifCtrl.dispose();
    _contactCtrl.dispose();
    super.dispose();
  }

  /// En correction, le bénéficiaire est celui de la permission d'origine —
  /// il n'a pas à être retrouvé dans la liste déroulante, qui peut être
  /// vide selon la portée depuis laquelle on ouvre la boîte.
  String? get _apprenantId => _apprenant?.id ?? widget.existante?.apprenantId;

  bool get _isValid =>
      _apprenantId != null && _dateDepart != null && _dateRetour != null;

  Future<void> _submit() async {
    if (!_isValid) return;
    if (_dateRetour!.isBefore(_dateDepart!)) {
      setState(
        () => _error = 'La date de retour doit être après la date de départ.',
      );
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      // En correction, on garde le rattachement d'origine : la permission
      // reste dans la classe et la division où elle a été accordée, même si
      // l'écran est ouvert sur une autre portée.
      final classeId = widget.existante?.classeId ?? widget.classe.id;

      final draft = PermissionDraft(
        apprenantId: _apprenantId!,
        divisionId: widget.existante?.divisionId ?? widget.division.id,
        classeId: classeId,
        dateDepart: _dateDepart!,
        dateRetour: _dateRetour!,
        localite: _emptyToNull(_localiteCtrl.text),
        motif: _emptyToNull(_motifCtrl.text),
        personneContact: _emptyToNull(_contactCtrl.text),
      );

      final depot = ref.read(permissionsRepositoryProvider);
      if (_correction) {
        await depot.updatePermission(widget.existante!.id, draft);
      } else {
        await depot.createPermission(draft);
      }
      // Trois listes montrent les permissions, selon la portée d'où l'on
      // vient : la phase, la division entière, ou la fiche de l'élève. Seule
      // la première était rafraîchie — sous « toutes phases », la
      // modification passait en base sans que l'écran change, ce qui donnait
      // à croire qu'elle avait échoué.
      ref.invalidate(permissionsByClasseProvider(classeId));
      ref.invalidate(
        permissionsByDivisionProvider(
          widget.existante?.divisionId ?? widget.division.id,
        ),
      );
      ref.invalidate(permissionsByApprenantProvider(_apprenantId!));
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _correction ? 'Permission modifiée.' : 'Permission enregistrée.',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Échec de l\'enregistrement : ${messageErreur(e)}';
          _submitting = false;
        });
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text('Erreur : ${messageErreur(e)}'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  String? _emptyToNull(String value) =>
      value.trim().isEmpty ? null : value.trim();

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final width = screenSize.width - 48 < 560 ? screenSize.width - 48 : 560.0;

    return SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _correction
                        ? 'Modifier la permission'
                        : 'Enregistrer une permission',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.blueMist,
                      borderRadius: BorderRadius.circular(AppRadii.control),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.groups_outlined,
                          size: 18,
                          color: AppColors.blueDeep,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${widget.classe.type == ClasseType.phase ? "Classe" : "Stage"} : ${widget.classe.nom} · ${widget.division.nom}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.blueDeep,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<Apprenant>(
                    initialValue: _apprenant,
                    decoration: const InputDecoration(
                      labelText: 'Élève / Stagiaire',
                    ),
                    isExpanded: true,
                    items: [
                      for (final a in widget.apprenants)
                        DropdownMenuItem(value: a, child: Text(a.nomComplet)),
                    ],
                    // Le bénéficiaire ne se change pas en correction : une
                    // permission accordée à quelqu'un d'autre est une autre
                    // permission, qui se reprend depuis le début.
                    onChanged: _correction
                        ? null
                        : (value) => setState(() => _apprenant = value),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _DatePickerField(
                          label: 'Date de départ',
                          value: _dateDepart,
                          onChanged: (v) => setState(() => _dateDepart = v),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: _DatePickerField(
                          label: 'Date de retour',
                          value: _dateRetour,
                          onChanged: (v) => setState(() => _dateRetour = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _localiteCtrl,
                    decoration: const InputDecoration(labelText: 'Localité'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _motifCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Motif'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _contactCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Personne à contacter',
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: const TextStyle(color: AppColors.danger),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                TextButton(
                  onPressed: _submitting
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Annuler'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: (!_isValid || _submitting) ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(_correction ? 'Modifier' : 'Enregistrer'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  const _DatePickerField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? now,
          firstDate: now.subtract(const Duration(days: 365)),
          lastDate: now.add(const Duration(days: 730)),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
        ),
        child: Text(
          value != null ? DateFormat('dd/MM/yyyy').format(value!) : '',
        ),
      ),
    );
  }
}
