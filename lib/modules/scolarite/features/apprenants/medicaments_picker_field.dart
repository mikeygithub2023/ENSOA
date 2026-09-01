import 'package:flutter/material.dart';

import 'package:sig_ensoa/core/theme.dart' hide AlertLevel, AlertLevelColor;
import '../../models/medicament.dart';

/// Une ligne de prescription en cours de saisie (pas encore enregistrée).
class PrescriptionLigne {
  const PrescriptionLigne({
    required this.medicament,
    required this.quantite,
    this.posologie,
  });

  final Medicament medicament;
  final int quantite;
  final String? posologie;
}

/// Poignée que le formulaire hôte garde pour interroger le champ au moment
/// d'enregistrer.
///
/// Sans elle, un médicament choisi dans la ligne de saisie mais pour lequel
/// « Ajouter » n'a pas été cliqué serait silencieusement perdu à
/// l'enregistrement — le médecin croit avoir prescrit deux médicaments et
/// n'en retrouve qu'un dans les prescriptions.
class MedicamentsPickerController {
  _MedicamentsPickerFieldState? _state;

  /// Valide la ligne encore en cours de saisie, s'il y en a une. Renvoie un
  /// message d'erreur si elle est inexploitable (quantité invalide, stock
  /// insuffisant), `null` s'il n'y avait rien à valider ou si la ligne a été
  /// ajoutée.
  String? validerLigneEnCours() => _state?.validerLigneEnCours();
}

/// Champ de saisie des médicaments prescrits — ajoute des lignes (médicament
/// + quantité + posologie facultative) à une liste, prélevée sur le stock
/// unique de l'infirmerie au moment de l'ajout.
///
/// Le stock proposé tient compte de l'ordonnance en cours : une fois trois
/// boîtes ajoutées, le médicament n'en affiche plus que le reste, et la même
/// enveloppe est vérifiée à chaque ajout. Le stock réel, lui, n'est décompté
/// qu'à l'enregistrement final de la consultation.
class MedicamentsPickerField extends StatefulWidget {
  const MedicamentsPickerField({
    super.key,
    required this.medicaments,
    required this.value,
    required this.onChanged,
    this.controller,
  });

  final List<Medicament> medicaments;
  final List<PrescriptionLigne> value;
  final ValueChanged<List<PrescriptionLigne>> onChanged;
  final MedicamentsPickerController? controller;

  @override
  State<MedicamentsPickerField> createState() => _MedicamentsPickerFieldState();
}

class _MedicamentsPickerFieldState extends State<MedicamentsPickerField> {
  Medicament? _selected;
  final _quantiteController = TextEditingController(text: '1');
  final _posologieController = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;
  }

  @override
  void didUpdateWidget(covariant MedicamentsPickerField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._state = null;
      widget.controller?._state = this;
    }
  }

  @override
  void dispose() {
    widget.controller?._state = null;
    _quantiteController.dispose();
    _posologieController.dispose();
    super.dispose();
  }

  /// Quantité déjà réservée pour ce médicament par l'ordonnance en cours.
  int _dejaPrescrit(Medicament medicament) => widget.value
      .where((l) => l.medicament.id == medicament.id)
      .fold<int>(0, (acc, l) => acc + l.quantite);

  /// Ce qu'il reste réellement à prescrire, une fois l'ordonnance en cours
  /// déduite du stock.
  int _restant(Medicament medicament) =>
      medicament.stock - _dejaPrescrit(medicament);

  /// Rien à valider si aucun médicament n'est sélectionné : le formulaire
  /// hôte peut enregistrer sans erreur.
  String? validerLigneEnCours() {
    if (_selected == null) return null;
    return _add();
  }

  /// Renvoie le message d'erreur en cas d'échec, `null` si la ligne a bien
  /// été ajoutée.
  String? _add() {
    final medicament = _selected;
    final quantite = int.tryParse(_quantiteController.text.trim());
    if (medicament == null) {
      setState(() => _error = 'Choisissez un médicament');
      return _error;
    }
    if (quantite == null || quantite <= 0) {
      setState(() => _error = 'Quantité invalide');
      return _error;
    }
    final restant = _restant(medicament);
    if (quantite > restant) {
      setState(() {
        final dejaPrescrit = _dejaPrescrit(medicament);
        _error = dejaPrescrit == 0
            ? 'Stock insuffisant pour ${medicament.nom} : '
                  '${medicament.stock} en stock.'
            : 'Stock insuffisant pour ${medicament.nom} : '
                  '${medicament.stock} en stock, $dejaPrescrit déjà prescrit '
                  'sur cette consultation, il ne reste que $restant.';
      });
      return _error;
    }
    final posologie = _posologieController.text.trim();
    widget.onChanged([
      ...widget.value,
      PrescriptionLigne(
        medicament: medicament,
        quantite: quantite,
        posologie: posologie.isEmpty ? null : posologie,
      ),
    ]);
    setState(() {
      _selected = null;
      _quantiteController.text = '1';
      _posologieController.clear();
      _error = null;
    });
    return null;
  }

  void _remove(int index) {
    final next = [...widget.value]..removeAt(index);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Médicaments prescrits',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        const SizedBox(height: 8),
        if (widget.value.isNotEmpty) ...[
          for (var i = 0; i < widget.value.length; i++) ...[
            _PrescriptionTile(
              ligne: widget.value[i],
              onRemove: () => _remove(i),
            ),
            const SizedBox(height: 6),
          ],
          const SizedBox(height: 6),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: DropdownButtonFormField<Medicament>(
                initialValue: _selected,
                decoration: const InputDecoration(
                  labelText: 'Médicament',
                  isDense: true,
                ),
                isExpanded: true,
                items: [
                  for (final m in widget.medicaments)
                    DropdownMenuItem(
                      value: m,
                      child: Text(
                        _restant(m) <= 0
                            ? '${m.nom} (épuisé)'
                            : '${m.nom} (reste : ${_restant(m)})',
                        style: TextStyle(
                          color: _restant(m) <= 0
                              ? AppColors.inkMuted
                              : AppColors.ink,
                        ),
                      ),
                    ),
                ],
                onChanged: (value) => setState(() {
                  _selected = value;
                  _error = null;
                }),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 1,
              child: TextField(
                controller: _quantiteController,
                decoration: const InputDecoration(
                  labelText: 'Qté',
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _posologieController,
                decoration: const InputDecoration(
                  labelText: 'Posologie (facultatif)',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: widget.medicaments.isEmpty ? null : () => _add(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Ajouter'),
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 4),
          Text(
            _error!,
            style: const TextStyle(color: AppColors.danger, fontSize: 12),
          ),
        ],
        if (widget.medicaments.isEmpty) ...[
          const SizedBox(height: 4),
          const Text(
            'Aucun médicament au catalogue — voir le menu Médicaments.',
            style: TextStyle(color: AppColors.inkMuted, fontSize: 12),
          ),
        ],
      ],
    );
  }
}

class _PrescriptionTile extends StatelessWidget {
  const _PrescriptionTile({required this.ligne, required this.onRemove});

  final PrescriptionLigne ligne;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.blueMist,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${ligne.medicament.nom} × ${ligne.quantite}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  if (ligne.posologie != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      ligne.posologie!,
                      style: const TextStyle(
                        color: AppColors.inkMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              tooltip: 'Retirer',
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}
