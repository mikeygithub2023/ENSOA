import 'package:flutter/material.dart';

import 'package:sig_ensoa/core/theme.dart';

/// Bloc de base du skeleton screen — un rectangle avec un dégradé animé qui
/// balaie de gauche à droite, pour signaler visuellement "en cours de
/// chargement" sans dépendre d'un package externe.
class SkeletonBox extends StatefulWidget {
  final double? width;
  final double height;
  final BorderRadius borderRadius;

  const SkeletonBox({
    super.key,
    this.width,
    this.height = 14,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            gradient: LinearGradient(
              begin: Alignment(-1 + 3 * t, 0),
              end: Alignment(1 + 3 * t, 0),
              colors: const [
                AppColors.blueMist,
                Color(0xFFF3F6FC),
                AppColors.blueMist,
              ],
              stops: const [0.35, 0.5, 0.65],
            ),
          ),
        );
      },
    );
  }
}

/// Skeleton d'une carte de type "GridView" (soutes, véhicules...) — un
/// rectangle de carte avec quelques lignes de texte factices à l'intérieur.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                SkeletonBox(width: 120, height: 16),
                SkeletonBox(width: 50, height: 16),
              ],
            ),
            const SizedBox(height: 14),
            const SkeletonBox(
              height: 8,
              borderRadius: BorderRadius.all(Radius.circular(6)),
            ),
            const SizedBox(height: 18),
            const SkeletonBox(width: 90, height: 11),
            const SizedBox(height: 8),
            const SkeletonBox(width: 140, height: 11),
            const Spacer(),
            const SkeletonBox(width: 100, height: 11),
          ],
        ),
      ),
    );
  }
}

/// Grille de [SkeletonCard], pour remplacer un GridView.builder pendant le
/// premier chargement.
class SkeletonGrid extends StatelessWidget {
  final int itemCount;
  final double maxCrossAxisExtent;
  final double mainAxisExtent;

  const SkeletonGrid({
    super.key,
    this.itemCount = 4,
    this.maxCrossAxisExtent = 340,
    this.mainAxisExtent = 190,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: maxCrossAxisExtent,
        mainAxisExtent: mainAxisExtent,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemBuilder: (context, i) => const SkeletonCard(),
    );
  }
}

/// Skeleton d'une ligne de type "ListTile" (journal des mouvements,
/// dépotages, distributions...).
class SkeletonTile extends StatelessWidget {
  const SkeletonTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            const SkeletonBox(
              width: 40,
              height: 40,
              borderRadius: BorderRadius.all(Radius.circular(20)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  SkeletonBox(width: 160, height: 14),
                  SizedBox(height: 8),
                  SkeletonBox(width: 100, height: 11),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const SkeletonBox(width: 60, height: 14),
          ],
        ),
      ),
    );
  }
}

/// Liste de [SkeletonTile], avec un espacement identique aux listes réelles.
class SkeletonList extends StatelessWidget {
  final int itemCount;
  const SkeletonList({super.key, this.itemCount = 4});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < itemCount; i++) ...[
          const SkeletonTile(),
          if (i < itemCount - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

/// Skeleton bespoke du tableau de bord — reproduit approximativement la mise
/// en page réelle (carte carburant + carte sombre, jauge + barre, lignes de
/// suivi) pour éviter un "saut" visuel une fois les données arrivées.
class SkeletonDashboard extends StatelessWidget {
  const SkeletonDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth > 820;
            final carteCarburant = Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SkeletonBox(width: 180, height: 16),
                    const SizedBox(height: 8),
                    const SkeletonBox(width: 140, height: 11),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const SkeletonBox(
                          width: 46,
                          height: 46,
                          borderRadius: BorderRadius.all(Radius.circular(14)),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            SkeletonBox(width: 100, height: 22),
                            SizedBox(height: 6),
                            SkeletonBox(width: 130, height: 11),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const SkeletonBox(
                      height: 8,
                      borderRadius: BorderRadius.all(Radius.circular(6)),
                    ),
                    const SizedBox(height: 14),
                    const SkeletonBox(
                      height: 8,
                      borderRadius: BorderRadius.all(Radius.circular(6)),
                    ),
                  ],
                ),
              ),
            );
            final carteAlertes = Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppColors.contrastCard,
                borderRadius: BorderRadius.circular(AppRadii.card),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SkeletonBox(width: 160, height: 16),
                  const SizedBox(height: 20),
                  for (int i = 0; i < 3; i++) ...[
                    const SkeletonBox(height: 12),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            );
            if (!wide) {
              return Column(
                children: [
                  carteCarburant,
                  const SizedBox(height: 16),
                  carteAlertes,
                ],
              );
            }
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 6, child: carteCarburant),
                  const SizedBox(width: 16),
                  Expanded(flex: 5, child: carteAlertes),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth > 820;
            final carte = Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    SkeletonBox(width: 150, height: 16),
                    SizedBox(height: 28),
                    SkeletonBox(height: 40),
                  ],
                ),
              ),
            );
            if (!wide) {
              return Column(
                children: [carte, const SizedBox(height: 16), carte],
              );
            }
            return Row(
              children: [
                Expanded(child: carte),
                const SizedBox(width: 16),
                Expanded(child: carte),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                for (int i = 0; i < 4; i++) ...[
                  Row(
                    children: [
                      const SkeletonBox(
                        width: 40,
                        height: 40,
                        borderRadius: BorderRadius.all(Radius.circular(20)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            SkeletonBox(width: 130, height: 13),
                            SizedBox(height: 6),
                            SkeletonBox(width: 180, height: 11),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (i < 3)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(height: 1),
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
