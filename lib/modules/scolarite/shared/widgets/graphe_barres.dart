import 'package:flutter/material.dart';

import 'package:sig_ensoa/core/theme.dart' hide AlertLevel, AlertLevelColor;

/// Une barre du graphe : un libellé, une valeur, et de quoi la commenter.
class BarreDonnee {
  const BarreDonnee({
    required this.label,
    required this.valeur,
    this.detail,
    this.couleur,
  });

  final String label;
  final num valeur;

  /// Complément affiché à droite de la valeur (ex. « 12 apprenants »).
  final String? detail;

  /// Couleur propre à cette barre — sinon celle du graphe.
  final Color? couleur;
}

/// Graphe en barres horizontales : le libellé à gauche, la barre au prorata
/// de la plus grande valeur, la valeur et son commentaire à droite.
///
/// Horizontal plutôt que vertical : les libellés (noms de médicaments,
/// intitulés de modules, pathologies) sont longs et resteraient illisibles
/// sous des colonnes.
class GrapheBarres extends StatelessWidget {
  const GrapheBarres({
    super.key,
    required this.titre,
    required this.barres,
    this.sousTitre,
    this.couleur = AppColors.blueDeep,
    this.largeurLabel = 220,
    this.messageVide = 'Aucune donnée sur cette période.',
  });

  final String titre;
  final String? sousTitre;
  final List<BarreDonnee> barres;
  final Color couleur;
  final double largeurLabel;
  final String messageVide;

  @override
  Widget build(BuildContext context) {
    final maximum = barres.fold<num>(0, (m, b) => b.valeur > m ? b.valeur : m);

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
          Text(
            titre,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          if (sousTitre != null) ...[
            const SizedBox(height: 2),
            Text(
              sousTitre!,
              style: const TextStyle(color: AppColors.inkMuted, fontSize: 12),
            ),
          ],
          const SizedBox(height: 16),
          if (barres.isEmpty)
            Text(
              messageVide,
              style: const TextStyle(color: AppColors.inkMuted, fontSize: 13),
            )
          else
            for (final barre in barres) ...[
              _Ligne(
                barre: barre,
                maximum: maximum,
                couleur: barre.couleur ?? couleur,
                largeurLabel: largeurLabel,
              ),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _Ligne extends StatelessWidget {
  const _Ligne({
    required this.barre,
    required this.maximum,
    required this.couleur,
    required this.largeurLabel,
  });

  final BarreDonnee barre;
  final num maximum;
  final Color couleur;
  final double largeurLabel;

  @override
  Widget build(BuildContext context) {
    final part = maximum == 0 ? 0.0 : barre.valeur / maximum;

    return Row(
      children: [
        SizedBox(
          width: largeurLabel,
          child: Text(
            barre.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: AppColors.ink),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            child: Container(
              height: 18,
              color: couleur.withValues(alpha: 0.10),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                // Une barre nulle resterait invisible : on lui laisse un
                // filet pour qu'elle se distingue d'une ligne absente.
                widthFactor: part == 0 ? 0.004 : part.toDouble(),
                child: Container(color: couleur),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 150,
          child: Text(
            barre.detail == null
                ? _formatValeur(barre.valeur)
                : '${_formatValeur(barre.valeur)}  (${barre.detail})',
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
        ),
      ],
    );
  }
}

String _formatValeur(num valeur) {
  return valeur == valeur.roundToDouble()
      ? valeur.toStringAsFixed(0)
      : valeur.toStringAsFixed(2);
}
