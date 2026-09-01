import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:sig_ensoa/core/erreurs.dart';
import 'package:sig_ensoa/core/theme.dart' hide AlertLevel, AlertLevelColor;
import '../../models/medicament.dart';
import 'data/demandes_reapprovisionnement_repository.dart';
import 'providers/demandes_reapprovisionnement_providers.dart';

final _dateFmt = DateFormat('dd/MM/yyyy');

/// Saisie d'une fiche de demande de réapprovisionnement : le médecin coche
/// les médicaments à commander et ajuste les quantités.
///
/// Le formulaire ne part pas d'une page blanche — tout ce qui peut être
/// déduit du catalogue l'est : les médicaments en rupture, au seuil ou sur
/// le point de l'atteindre arrivent déjà cochés, avec une quantité
/// proposée. Le médecin n'a plus qu'à corriger ce qui doit l'être.
Future<void> showRegisterDemandeReapprovisionnementDialog(
  BuildContext context, {
  required List<Medicament> medicaments,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.all(24),
      child: _RegisterDemandeDialog(medicaments: medicaments),
    ),
  );
}

/// Quantité proposée pour ramener le stock au double du seuil d'alerte —
/// une commande qui laisse de la marge sans immobiliser inutilement. Jamais
/// moins d'une unité, pour que la ligne cochée ait toujours un sens.
int _quantiteProposee(Medicament medicament) {
  final cible = medicament.seuilAlerte * 2;
  final manque = cible - medicament.stock;
  return manque < 1 ? 1 : manque;
}

class _RegisterDemandeDialog extends ConsumerStatefulWidget {
  const _RegisterDemandeDialog({required this.medicaments});

  final List<Medicament> medicaments;

  @override
  ConsumerState<_RegisterDemandeDialog> createState() =>
      _RegisterDemandeDialogState();
}

class _RegisterDemandeDialogState
    extends ConsumerState<_RegisterDemandeDialog> {
  final Set<String> _coches = {};
  final Map<String, TextEditingController> _quantites = {};
  final _observationsController = TextEditingController();
  final _rechercheController = TextEditingController();
  DateTime _date = DateTime.now();
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final medicament in widget.medicaments) {
      _quantites[medicament.id] = TextEditingController(
        text: _quantiteProposee(medicament).toString(),
      );
      if (medicament.etatStock != EtatStock.suffisant) {
        _coches.add(medicament.id);
      }
    }
    _rechercheController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final controller in _quantites.values) {
      controller.dispose();
    }
    _observationsController.dispose();
    _rechercheController.dispose();
    super.dispose();
  }

  List<Medicament> get _visibles {
    final recherche = _rechercheController.text.trim().toLowerCase();
    if (recherche.isEmpty) return widget.medicaments;
    return widget.medicaments
        .where((m) => m.nom.toLowerCase().contains(recherche))
        .toList();
  }

  Future<void> _submit() async {
    final lignes = <LigneReapprovisionnementDraft>[];
    for (final medicament in widget.medicaments) {
      if (!_coches.contains(medicament.id)) continue;
      final quantite = int.tryParse(_quantites[medicament.id]!.text.trim());
      if (quantite == null || quantite <= 0) {
        setState(
          () => _error =
              'Quantité invalide pour « ${medicament.nom} » : '
              'indiquez un nombre supérieur à 0.',
        );
        return;
      }
      lignes.add(
        LigneReapprovisionnementDraft(
          medicamentId: medicament.id,
          quantiteDemandee: quantite,
          stockActuel: medicament.stock,
        ),
      );
    }
    if (lignes.isEmpty) {
      setState(() => _error = 'Cochez au moins un médicament à commander.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(demandesReapprovisionnementRepositoryProvider)
          .createDemande(
            dateDemande: _date,
            observations: _observationsController.text.trim().isEmpty
                ? null
                : _observationsController.text.trim(),
            lignes: lignes,
          );
      ref.invalidate(demandesReapprovisionnementProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Demande enregistrée : ${lignes.length} médicament(s).',
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final width = screenSize.width - 48 < 760 ? screenSize.width - 48 : 760.0;
    final height = screenSize.height - 48 < 800
        ? screenSize.height - 48
        : 800.0;
    final visibles = _visibles;

    return SizedBox(
      width: width,
      height: height,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 12, 0),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Demande de réapprovisionnement',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      Text(
                        'Les médicaments à commander sont déjà cochés, '
                        'avec une quantité proposée.',
                        style: TextStyle(
                          color: AppColors.inkMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime(now.year - 1),
                        lastDate: now.add(const Duration(days: 365)),
                      );
                      if (picked != null) setState(() => _date = picked);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Date de la demande',
                        suffixIcon: Icon(
                          Icons.calendar_today_outlined,
                          size: 18,
                        ),
                      ),
                      child: Text(_dateFmt.format(_date)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _rechercheController,
                    decoration: const InputDecoration(
                      labelText: 'Rechercher un médicament',
                      prefixIcon: Icon(Icons.search, size: 18),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Text(
                  '${_coches.length} médicament(s) coché(s)',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.ink,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(_coches.clear),
                  child: const Text('Tout décocher'),
                ),
              ],
            ),
          ),
          Expanded(
            child: visibles.isEmpty
                ? const Center(
                    child: Text(
                      'Aucun médicament ne correspond à cette recherche.',
                      style: TextStyle(color: AppColors.inkMuted),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                    itemCount: visibles.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final medicament = visibles[index];
                      return _LigneMedicament(
                        medicament: medicament,
                        coche: _coches.contains(medicament.id),
                        quantite: _quantites[medicament.id]!,
                        onCoche: (coche) => setState(() {
                          if (coche) {
                            _coches.add(medicament.id);
                          } else {
                            _coches.remove(medicament.id);
                          }
                        }),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: TextField(
              controller: _observationsController,
              decoration: const InputDecoration(
                labelText: 'Observations (facultatif)',
              ),
              maxLines: 2,
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.danger),
              ),
            ),
          Container(
            margin: const EdgeInsets.only(top: 12),
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
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Valider la demande'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LigneMedicament extends StatelessWidget {
  const _LigneMedicament({
    required this.medicament,
    required this.coche,
    required this.quantite,
    required this.onCoche,
  });

  final Medicament medicament;
  final bool coche;
  final TextEditingController quantite;
  final ValueChanged<bool> onCoche;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: coche ? AppColors.blueMist : AppColors.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onCoche(!coche),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 16, 6),
          child: Row(
            children: [
              Checkbox(
                value: coche,
                onChanged: (value) => onCoche(value ?? false),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      medicament.nom,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      [
                        medicament.type.label,
                        if (medicament.unite != null &&
                            medicament.unite!.isNotEmpty)
                          medicament.unite!,
                      ].join(' · '),
                      style: const TextStyle(
                        color: AppColors.inkMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Stock : ${medicament.stock}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: medicament.etatStock == EtatStock.suffisant
                      ? AppColors.inkMuted
                      : AppColors.danger,
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 110,
                child: TextField(
                  controller: quantite,
                  enabled: coche,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Quantité',
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
