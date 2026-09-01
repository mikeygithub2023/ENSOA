import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:sig_ensoa/core/theme.dart';
import '../../data/models/ia.dart';

const _palette = [
  AppColors.blueDeep,
  AppColors.ivoryOrange,
  AppColors.success,
  AppColors.militaryGreen,
  AppColors.warning,
  AppColors.danger,
  AppColors.blue,
];

/// Rend un [AiGraphique] en barres horizontales ou en camembert, selon son
/// type — la réponse de l'IA choisit celui qui convient le mieux à la question.
class AiGraphiqueWidget extends StatelessWidget {
  final AiGraphique graphique;
  const AiGraphiqueWidget({super.key, required this.graphique});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              graphique.titre,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 16),
            if (graphique.type == AiGraphiqueType.camembert)
              _CamembertChart(series: graphique.series)
            else
              _BarresChart(series: graphique.series),
          ],
        ),
      ),
    );
  }
}

class _BarresChart extends StatelessWidget {
  final List<AiSerie> series;
  const _BarresChart({required this.series});

  @override
  Widget build(BuildContext context) {
    final maxValeur = series.fold<double>(1, (m, s) => math.max(m, s.valeur));
    return Column(
      children: [
        for (var i = 0; i < series.length; i++) ...[
          _barre(series[i], maxValeur, _palette[i % _palette.length]),
          if (i != series.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _barre(AiSerie s, double maxValeur, Color couleur) {
    final fraction = maxValeur == 0
        ? 0.0
        : (s.valeur / maxValeur).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                s.label,
                style: const TextStyle(fontSize: 13, color: AppColors.inkMuted),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              _formatValeur(s.valeur),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: couleur,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 10,
            backgroundColor: couleur.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation(couleur),
          ),
        ),
      ],
    );
  }
}

class _CamembertChart extends StatelessWidget {
  final List<AiSerie> series;
  const _CamembertChart({required this.series});

  @override
  Widget build(BuildContext context) {
    final total = series.fold<double>(0, (s, e) => s + e.valeur);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 120,
          height: 120,
          child: CustomPaint(
            painter: _CamembertPainter(series: series, total: total),
          ),
        ),
        const SizedBox(width: 20),
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
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          series[i].label,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.ink,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        total == 0
                            ? '—'
                            : '${(series[i].valeur / total * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CamembertPainter extends CustomPainter {
  final List<AiSerie> series;
  final double total;
  const _CamembertPainter({required this.series, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    if (total <= 0) return;
    final rect = Offset.zero & size;
    var depart = -math.pi / 2;
    for (var i = 0; i < series.length; i++) {
      final sweep = (series[i].valeur / total) * 2 * math.pi;
      final paint = Paint()
        ..color = _palette[i % _palette.length]
        ..style = PaintingStyle.fill;
      canvas.drawArc(rect, depart, sweep, true, paint);
      depart += sweep;
    }
    canvas.drawCircle(
      size.center(Offset.zero),
      size.width / 2 * 0.55,
      Paint()..color = AppColors.cardBg,
    );
  }

  @override
  bool shouldRepaint(covariant _CamembertPainter oldDelegate) =>
      oldDelegate.series != series;
}

String _formatValeur(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
