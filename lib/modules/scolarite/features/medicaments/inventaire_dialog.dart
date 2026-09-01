import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:sig_ensoa/core/theme.dart' hide AlertLevel, AlertLevelColor;
import '../../models/medicament.dart';
import '../../shared/widgets/common.dart';
import 'providers/medicaments_providers.dart';

final _dateFmt = DateFormat('dd/MM/yyyy');

/// Un écart constaté lors de l'inventaire (stock physiquement compté
/// différent du stock enregistré).
class _Ecart {
  const _Ecart({required this.medicament, required this.stockCompte});

  final Medicament medicament;
  final int stockCompte;

  int get delta => stockCompte - medicament.stock;
}

/// Inventaire de la pharmacie : on saisit le stock physiquement compté pour
/// chaque médicament (pré-rempli avec le stock enregistré, à ne modifier
/// que là où un écart est constaté) ; à la validation, seuls les
/// médicaments dont la quantité comptée diffère du stock enregistré
/// génèrent un mouvement de stock ("Inventaire du ..."), après confirmation
/// des écarts détectés.
Future<void> showInventaireDialog(
  BuildContext context, {
  required List<Medicament> medicaments,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.all(24),
      child: _InventaireDialog(medicaments: medicaments),
    ),
  );
}

class _InventaireDialog extends ConsumerStatefulWidget {
  const _InventaireDialog({required this.medicaments});

  final List<Medicament> medicaments;

  @override
  ConsumerState<_InventaireDialog> createState() => _InventaireDialogState();
}

class _InventaireDialogState extends ConsumerState<_InventaireDialog> {
  late final Map<String, TextEditingController> _controllers = {
    for (final m in widget.medicaments)
      m.id: TextEditingController(text: m.stock.toString()),
  };
  bool _submitting = false;

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  List<_Ecart> _ecarts() {
    final ecarts = <_Ecart>[];
    for (final medicament in widget.medicaments) {
      final saisie = _controllers[medicament.id]!.text.trim();
      final stockCompte = int.tryParse(saisie);
      if (stockCompte == null || stockCompte == medicament.stock) continue;
      ecarts.add(_Ecart(medicament: medicament, stockCompte: stockCompte));
    }
    return ecarts;
  }

  Future<void> _valider() async {
    final ecarts = _ecarts();
    final messenger = ScaffoldMessenger.of(context);
    if (ecarts.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Aucun écart détecté.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text('${ecarts.length} écart(s) détecté(s)'),
        content: SizedBox(
          width: 380,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final ecart in ecarts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            ecart.medicament.nom,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          '${ecart.medicament.stock} → ${ecart.stockCompte}',
                          style: TextStyle(
                            color: ecart.delta > 0
                                ? AppColors.success
                                : AppColors.danger,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirmer l\'inventaire'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _submitting = true);
    final motif = 'Inventaire du ${_dateFmt.format(DateTime.now())}';
    var failures = 0;
    for (final ecart in ecarts) {
      try {
        await ref
            .read(medicamentsRepositoryProvider)
            .ajusterStock(
              ecart.medicament.id,
              delta: ecart.delta,
              motif: motif,
            );
        ref.invalidate(mouvementsStockProvider(ecart.medicament.id));
      } catch (_) {
        failures++;
      }
    }
    ref.invalidate(medicamentsProvider);
    if (!mounted) return;
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          failures == 0
              ? 'Inventaire enregistré : ${ecarts.length} écart(s) corrigé(s).'
              : '${ecarts.length - failures} écart(s) corrigé(s), $failures échec(s).',
        ),
        backgroundColor: failures == 0 ? AppColors.success : AppColors.danger,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final width = screenSize.width - 48 < 560 ? screenSize.width - 48 : 560.0;
    final height = screenSize.height - 48 < 700
        ? screenSize.height - 48
        : 700.0;

    final parType = <TypeMedicament, List<Medicament>>{};
    for (final medicament in widget.medicaments) {
      parType.putIfAbsent(medicament.type, () => []).add(medicament);
    }
    for (final groupe in parType.values) {
      groupe.sort((a, b) => a.nom.toLowerCase().compareTo(b.nom.toLowerCase()));
    }

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
                  child: Text(
                    'Inventaire de la pharmacie',
                    style: TextStyle(
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
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Saisissez le stock physiquement compté — laissez '
                'inchangé partout où il correspond déjà.',
                style: const TextStyle(color: AppColors.inkMuted, fontSize: 12),
              ),
            ),
          ),
          Expanded(
            child: widget.medicaments.isEmpty
                ? const EmptyState(
                    message: 'Aucun médicament au catalogue.',
                    icon: Icons.medication_outlined,
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final type in TypeMedicament.values)
                          if (parType[type] != null) ...[
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                type.label.toUpperCase(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.ink,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            for (final medicament in parType[type]!) ...[
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        medicament.nom,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      'Enregistré : ${medicament.stock}',
                                      style: const TextStyle(
                                        color: AppColors.inkMuted,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    SizedBox(
                                      width: 90,
                                      child: TextField(
                                        controller: _controllers[medicament.id],
                                        decoration: const InputDecoration(
                                          labelText: 'Compté',
                                          isDense: true,
                                        ),
                                        keyboardType: TextInputType.number,
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
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
                Text(
                  '${_ecarts().length} écart(s)',
                  style: const TextStyle(color: AppColors.inkMuted),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _submitting
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Annuler'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: (_submitting || widget.medicaments.isEmpty)
                      ? null
                      : _valider,
                  child: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Valider l\'inventaire'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
