import 'package:flutter/material.dart';

import 'package:sig_ensoa/core/theme.dart' hide AlertLevel, AlertLevelColor;

/// Carte indicateur (KPI) — style "StatCard" du template ERP Flutter : icône
/// dans une puce teintée, valeur en gras 22px, libellé discret en dessous.
class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.titre,
    required this.valeur,
    required this.sousTitre,
    required this.icone,
    this.couleur = AppColors.blueDeep,
  });

  final String titre;
  final String valeur;
  final String sousTitre;
  final IconData icone;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: couleur.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icone, color: couleur, size: 22),
            ),
            const SizedBox(height: 16),
            Text(
              valeur,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              titre,
              style: const TextStyle(color: AppColors.inkMuted, fontSize: 13),
            ),
            const SizedBox(height: 2),
            Text(
              sousTitre,
              style: TextStyle(
                color: couleur,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
