import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:sig_ensoa/core/theme.dart' hide AlertLevel, AlertLevelColor;
import '../../models/assistant_ia.dart';

/// Palette des parts, dans l'ordre où elles se présentent. Sept teintes
/// suffisent : au-delà, un camembert cesse d'être lisible, et la question
/// appelait sans doute des barres.
const _palette = [
  AppColors.blueDeep,
  AppColors.warning,
  AppColors.success,
  AppColors.blue,
  AppColors.danger,
  AppColors.navy,
  AppColors.inkMuted,
];

/// Répartition en camembert, avec sa légende chiffrée en pourcentages.
///
/// Les barres, elles, se rendent avec [GrapheBarres] : ce projet en a déjà
/// un, inutile d'en avoir deux qui ne se ressembleraient pas.
class CamembertIa extends StatelessWidget {
  const CamembertIa({super.key, required this.titre, required this.series});

  final String titre;
  final List<SerieIa> series;

  @override
  Widget build(BuildContext context) {
    final total = series.fold<double>(0, (somme, s) => somme + s.valeur);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (titre.isNotEmpty) ...[
            Text(
              titre,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              SizedBox(
                width: 130,
                height: 130,
                child: CustomPaint(
                  painter: _CamembertPainter(series: series, total: total),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < series.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: _palette[i % _palette.length],
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                series[i].label,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.ink,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              _valeur(series[i].valeur),
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 44,
                              child: Text(
                                total == 0
                                    ? '—'
                                    : '${(series[i].valeur / total * 100).toStringAsFixed(0)} %',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.inkMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Les effectifs s'écrivent en entiers ; seules les moyennes gardent une
  /// décimale.
  static String _valeur(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
}

class _CamembertPainter extends CustomPainter {
  const _CamembertPainter({required this.series, required this.total});

  final List<SerieIa> series;
  final double total;

  @override
  void paint(Canvas canvas, Size size) {
    if (total <= 0) return;
    final rect = Offset.zero & size;
    // Départ à midi plutôt qu'à trois heures : c'est de là qu'on lit un
    // camembert.
    var depart = -math.pi / 2;
    for (var i = 0; i < series.length; i++) {
      final angle = (series[i].valeur / total) * 2 * math.pi;
      canvas.drawArc(
        rect,
        depart,
        angle,
        true,
        Paint()..color = _palette[i % _palette.length],
      );
      depart += angle;
    }
    // Le disque central fait l'anneau : plus lisible qu'un camembert plein
    // quand deux parts sont voisines.
    canvas.drawCircle(
      size.center(Offset.zero),
      size.width / 2 * 0.55,
      Paint()..color = AppColors.cardBg,
    );
  }

  @override
  bool shouldRepaint(covariant _CamembertPainter oldDelegate) =>
      oldDelegate.series != series || oldDelegate.total != total;
}
