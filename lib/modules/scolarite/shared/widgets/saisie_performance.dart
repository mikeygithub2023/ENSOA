import 'package:flutter/material.dart';

import 'package:sig_ensoa/core/theme.dart' hide AlertLevel, AlertLevelColor;
import '../../models/sous_module.dart';

/// Saisie d'une performance sportive, dans la forme où on la lit sur le
/// terrain.
///
/// Un chronomètre se lit en minutes et en secondes : demander « 750 »
/// oblige à faire le calcul de tête, et une erreur d'un facteur 60 ne se
/// voit pas à la relecture. On saisit donc deux champs, et c'est le widget
/// qui convertit — la base, elle, continue de ne connaître que des
/// secondes.
///
/// Les autres unités (mètres, répétitions, points) n'ont pas ce problème :
/// un seul champ suffit.
class SaisiePerformance extends StatefulWidget {
  const SaisiePerformance({
    super.key,
    required this.unite,
    required this.initial,
    required this.onChanged,
    this.autofocus = false,
    this.label,
  });

  final UniteEpreuve unite;

  /// La valeur de départ, toujours dans l'unité de la base (des secondes
  /// pour une épreuve chronométrée).
  final num? initial;

  /// Appelé à chaque frappe avec la valeur convertie, ou `null` tant que la
  /// saisie n'est pas exploitable.
  final ValueChanged<num?> onChanged;

  final bool autofocus;

  /// Intitulé du champ unique (unités non chronométrées). Sans effet sur la
  /// saisie en minutes/secondes, qui porte ses propres libellés.
  final String? label;

  @override
  State<SaisiePerformance> createState() => _SaisiePerformanceState();
}

class _SaisiePerformanceState extends State<SaisiePerformance> {
  late final TextEditingController _minutesCtrl;
  late final TextEditingController _secondesCtrl;
  late final TextEditingController _valeurCtrl;

  bool get _chrono => widget.unite == UniteEpreuve.secondes;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    final total = initial?.round();
    _minutesCtrl = TextEditingController(
      text: total == null ? '' : (total ~/ 60).toString(),
    );
    _secondesCtrl = TextEditingController(
      text: total == null ? '' : (total % 60).toString(),
    );
    _valeurCtrl = TextEditingController(
      text: initial == null ? '' : _formatValeur(initial),
    );
    _minutesCtrl.addListener(_notifier);
    _secondesCtrl.addListener(_notifier);
    _valeurCtrl.addListener(_notifier);
  }

  @override
  void dispose() {
    _minutesCtrl.dispose();
    _secondesCtrl.dispose();
    _valeurCtrl.dispose();
    super.dispose();
  }

  static String _formatValeur(num value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toString();

  void _notifier() {
    setState(() {});
    widget.onChanged(_valeur);
  }

  /// La performance en unité de base, ou `null` si la saisie ne tient pas
  /// debout. Un champ vide vaut zéro dès lors que l'autre est rempli :
  /// « 12 minutes » tout court est une durée valable, « 45 secondes »
  /// aussi.
  num? get _valeur {
    if (!_chrono) {
      final texte = _valeurCtrl.text.trim().replaceAll(',', '.');
      if (texte.isEmpty) return null;
      final valeur = num.tryParse(texte);
      return valeur == null || valeur < 0 ? null : valeur;
    }

    final minutesTexte = _minutesCtrl.text.trim();
    final secondesTexte = _secondesCtrl.text.trim();
    if (minutesTexte.isEmpty && secondesTexte.isEmpty) return null;

    final minutes = minutesTexte.isEmpty ? 0 : int.tryParse(minutesTexte);
    final secondes = secondesTexte.isEmpty ? 0 : int.tryParse(secondesTexte);
    if (minutes == null || secondes == null) return null;
    if (minutes < 0 || secondes < 0) return null;
    // Au-delà de 59, ce sont des minutes : on refuse plutôt que de
    // convertir en silence, pour que la saisie reste ce qu'on a lu au
    // chronomètre.
    if (secondes > 59) return null;
    return minutes * 60 + secondes;
  }

  @override
  Widget build(BuildContext context) {
    if (!_chrono) {
      return TextField(
        controller: _valeurCtrl,
        autofocus: widget.autofocus,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText:
              widget.label ?? 'Performance (${widget.unite.abreviation})',
        ),
      );
    }

    final secondesTexte = _secondesCtrl.text.trim();
    final secondesHorsBornes =
        secondesTexte.isNotEmpty &&
        (int.tryParse(secondesTexte) == null ||
            int.parse(secondesTexte) > 59 ||
            int.parse(secondesTexte) < 0);
    final valeur = _valeur;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _minutesCtrl,
                autofocus: widget.autofocus,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Minutes',
                  suffixText: 'min',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _secondesCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Secondes',
                  suffixText: 's',
                  errorText: secondesHorsBornes ? 'De 0 à 59' : null,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          valeur == null
              ? 'Minutes et secondes du chronomètre.'
              : 'Soit ${widget.unite.formater(valeur)}.',
          style: const TextStyle(color: AppColors.inkMuted, fontSize: 12),
        ),
      ],
    );
  }
}
