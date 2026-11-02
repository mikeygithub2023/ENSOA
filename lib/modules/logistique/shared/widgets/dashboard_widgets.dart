import 'package:flutter/material.dart';

import 'package:sig_ensoa/core/theme.dart';
import 'package:sig_ensoa/core/format.dart';

/// Grande carte sombre de contraste (équivalent du calendrier "Training Days"
/// de la référence) — sert ici à mettre en avant les échéances/alertes.
class DarkFeatureCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;

  const DarkFeatureCard({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.contrastCard,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

/// Jauge circulaire (équivalent "Steps for Today").
class GaugeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final double progress; // 0..1
  final String centerValue;
  final String centerLabel;
  final Color color;

  const GaugeCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.centerValue,
    required this.centerLabel,
    this.color = AppColors.blue,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 92,
              height: 92,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 92,
                    height: 92,
                    child: CircularProgressIndicator(
                      value: progress.clamp(0, 1),
                      strokeWidth: 9,
                      strokeCap: StrokeCap.round,
                      backgroundColor: color.withValues(alpha: 0.12),
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        centerValue,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: AppColors.ink,
                        ),
                      ),
                      Text(
                        centerLabel,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// La disponibilité du parc, type par type, chacun sa jauge.
///
/// Un véhicule se demande par type — une ambulance, un bus — et c'est type
/// par type qu'on constate qu'il n'en reste plus d'une sorte. Une jauge
/// d'ensemble ouvre la rangée ; chaque type suit, avec la sienne, dont la
/// couleur dit d'un coup d'œil s'il en reste : vert à partir de la moitié,
/// orange en dessous, rouge à zéro.
class DisponibiliteParTypeCard extends StatelessWidget {
  const DisponibiliteParTypeCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.ensemble,
    required this.types,
  });

  final String title;
  final String subtitle;

  /// Disponibles et total sur tout le parc compté.
  final (int, int) ensemble;

  /// Pour chaque type : son libellé, ses disponibles, son total.
  final List<(String, int, int)> types;

  static Color _couleur(int disponibles, int total) {
    if (disponibles == 0) return AppColors.danger;
    if (disponibles * 2 < total) return AppColors.warning;
    return AppColors.success;
  }

  @override
  Widget build(BuildContext context) {
    final (dispo, total) = ensemble;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: AppColors.inkMuted),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 28,
              runSpacing: 20,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                _JaugeType(
                  libelle: 'ENSEMBLE',
                  disponibles: dispo,
                  total: total,
                  couleur: total == 0 ? AppColors.success : _couleur(dispo, total),
                  taille: 104,
                  enAvant: true,
                ),
                for (final (libelle, d, t) in types)
                  _JaugeType(
                    libelle: libelle,
                    disponibles: d,
                    total: t,
                    couleur: _couleur(d, t),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _JaugeType extends StatelessWidget {
  const _JaugeType({
    required this.libelle,
    required this.disponibles,
    required this.total,
    required this.couleur,
    this.taille = 80,
    this.enAvant = false,
  });

  final String libelle;
  final int disponibles;
  final int total;
  final Color couleur;
  final double taille;

  /// La jauge d'ensemble, plus grande et au libellé appuyé.
  final bool enAvant;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: taille + 28,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: taille,
            height: taille,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: taille,
                  height: taille,
                  child: CircularProgressIndicator(
                    value: total == 0 ? 0 : disponibles / total,
                    strokeWidth: enAvant ? 10 : 8,
                    strokeCap: StrokeCap.round,
                    backgroundColor: couleur.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation(couleur),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$disponibles/$total',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: enAvant ? 18 : 15,
                        color: AppColors.ink,
                      ),
                    ),
                    const Text(
                      'dispo.',
                      style: TextStyle(fontSize: 10, color: AppColors.inkMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            libelle,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: enAvant ? FontWeight.w800 : FontWeight.w600,
              color: enAvant ? AppColors.navy : AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

/// Barre de progression avec étiquette flottante (équivalent "Weight Loss Plan").
/// Ce que chaque soute porte réellement, en litres.
///
/// Cette carte affichait auparavant un « remplissage » : le stock rapporté au
/// seuil nominal, en pourcentage. Le seuil nominal n'est pourtant pas
/// renseigné pour toutes les soutes, et là où il vaut zéro la carte ne
/// montrait plus rien qu'un tiret et une réglette vide. On ne compare donc
/// plus les soutes à un objectif, mais entre elles : la barre la plus longue
/// est celle qui porte le plus, et le chiffre à côté dit combien.
class SoutesStockCard extends StatelessWidget {
  const SoutesStockCard({
    super.key,
    required this.title,
    required this.total,
    required this.soutes,
    this.unite = 'L',
  });

  final String title;
  final int total;

  /// Le libellé de chaque ligne et ce qu'elle contient, dans [unite].
  final List<(String, int)> soutes;

  /// L'unité du contenu — des litres pour une soute de carburant, des
  /// cartouches pour un casier de munitions. Le dessin est le même ; il
  /// n'y avait que ce mot à ne pas figer.
  final String unite;

  /// Ce que cette carte occupera pour [nombreDeSoutes] lignes.
  ///
  /// Sa hauteur dépend du nombre de soutes, et la rangée du tableau de bord a
  /// besoin de la connaître à l'avance pour aligner la jauge du parc dessus.
  /// On la calcule plutôt que de la demander à `IntrinsicHeight` : ce dernier
  /// interroge tout l'arbre sur ses dimensions naturelles, et une seule
  /// mesure impossible — un `LayoutBuilder`, par exemple — fait échouer la
  /// page entière. L'estimation est volontairement large : trop de place
  /// laisse un peu de blanc, trop peu déborde.
  static double hauteurPour(int nombreDeSoutes) {
    const enTete = 103.0; // marges, titre, sous-titre
    const parLigne = 46.0; // libellé, chiffre, barre, écart
    const marge = 24.0;
    final corps = nombreDeSoutes == 0 ? 20.0 : nombreDeSoutes * parLigne;
    final calculee = enTete + corps + marge;
    // Jamais plus courte que la jauge du parc, qui l'accompagne.
    return calculee < 140 ? 140 : calculee;
  }

  @override
  Widget build(BuildContext context) {
    final plusGrande = soutes.fold<int>(0, (m, s) => s.$2 > m ? s.$2 : m);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                Text(
                  '${formatMilliers(total)} $unite',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Carburant présent, soute par soute',
              style: TextStyle(fontSize: 12, color: AppColors.inkMuted),
            ),
            const SizedBox(height: 16),
            if (soutes.isEmpty)
              const Text(
                'Aucune soute enregistrée.',
                style: TextStyle(fontSize: 13, color: AppColors.inkMuted),
              )
            else
              for (final (libelle, litres) in soutes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              libelle,
                              style: const TextStyle(fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${formatMilliers(litres)} $unite',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                        child: LinearProgressIndicator(
                          value: plusGrande == 0 ? 0 : litres / plusGrande,
                          minHeight: 8,
                          backgroundColor: AppColors.blueMist,
                          valueColor: const AlwaysStoppedAnimation(
                            AppColors.navy,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class ProgressPillCard extends StatelessWidget {
  final String title;
  final String percentLabel;
  final double progress; // 0..1
  final String pillLabel;
  final String startLabel;
  final String endLabel;

  const ProgressPillCard({
    super.key,
    required this.title,
    required this.percentLabel,
    required this.progress,
    required this.pillLabel,
    required this.startLabel,
    required this.endLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                Text(
                  percentLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            LayoutBuilder(
              builder: (context, constraints) {
                final fraction = progress.clamp(0.0, 1.0);
                final pillX = (constraints.maxWidth - 70) * fraction;
                return SizedBox(
                  height: 40,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        top: 14,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 10,
                          decoration: BoxDecoration(
                            color: AppColors.blueMist,
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 14,
                        left: 0,
                        width: constraints.maxWidth * fraction,
                        child: Container(
                          height: 10,
                          decoration: BoxDecoration(
                            color: AppColors.navy,
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                          ),
                        ),
                      ),
                      Positioned(
                        top: -8,
                        left: pillX.clamp(0, constraints.maxWidth - 70),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.navy,
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                          ),
                          child: Text(
                            pillLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  startLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.inkMuted,
                  ),
                ),
                Text(
                  endLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.inkMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Carte d'aperçu carburant — stock total en grand, puis entrées/sorties du
/// jour comparées par des barres proportionnelles (remplace l'ancien
/// affichage en bulles superposées, peu lisible dès que les valeurs sont
/// petites ou nulles).
class FuelOverviewCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String stockLabel;
  final String stockValue;
  final int entrees;
  final int sorties;

  const FuelOverviewCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.stockLabel,
    required this.stockValue,
    required this.entrees,
    required this.sorties,
  });

  @override
  Widget build(BuildContext context) {
    final maxValeur = [entrees, sorties, 1].reduce((a, b) => a > b ? a : b);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: AppColors.inkMuted),
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.blueMist,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.local_gas_station_rounded,
                    color: AppColors.navy,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stockValue,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    Text(
                      stockLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            _barreComparaison(
              label: 'Entrées (dépotage)',
              valeur: entrees,
              maxValeur: maxValeur,
              couleur: AppColors.success,
              prefixe: '+',
            ),
            const SizedBox(height: 14),
            _barreComparaison(
              label: 'Sorties (distribution)',
              valeur: sorties,
              maxValeur: maxValeur,
              couleur: AppColors.ivoryOrange,
              prefixe: '-',
            ),
          ],
        ),
      ),
    );
  }

  Widget _barreComparaison({
    required String label,
    required int valeur,
    required int maxValeur,
    required Color couleur,
    required String prefixe,
  }) {
    final fraction = (valeur / maxValeur).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 13, color: AppColors.inkMuted),
            ),
            Text(
              '$prefixe${formatMilliers(valeur)} L',
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
            minHeight: 8,
            backgroundColor: couleur.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation(couleur),
          ),
        ),
      ],
    );
  }
}

/// Ligne d'item avec avatar/icône + indicateur de progression en points
/// (équivalent des lignes "My Habits").
class DotProgressRow extends StatelessWidget {
  final IconData? icon;
  final Widget? iconWidget;
  final Color iconColor;
  final String title;
  final String subtitle;
  final int completed;
  final int total;
  final VoidCallback? onTap;

  const DotProgressRow({
    super.key,
    this.icon,
    this.iconWidget,
    required this.title,
    required this.subtitle,
    required this.completed,
    required this.total,
    this.iconColor = AppColors.blue,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: iconColor.withValues(alpha: 0.12),
              child: iconWidget ?? Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '$completed/$total',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.inkMuted,
              ),
            ),
            const SizedBox(width: 8),
            Row(
              children: List.generate(total.clamp(0, 12), (i) {
                final filled = i < completed;
                return Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  decoration: BoxDecoration(
                    color: filled
                        ? iconColor
                        : iconColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
