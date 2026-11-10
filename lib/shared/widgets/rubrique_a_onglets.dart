import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'barre_onglets_pilule.dart';

/// Une rubrique du menu qui en réunit plusieurs : son titre, son bandeau
/// d'onglets, et l'écran de chacun, repris tel quel.
class RubriqueAOnglets extends StatelessWidget {
  const RubriqueAOnglets({
    super.key,
    required this.titre,
    required this.onglets,
    this.ongletInitial = 0,
  });

  final String titre;

  /// Le libellé de chaque onglet et ce qui construit son écran.
  final List<(String, Widget Function())> onglets;

  final int ongletInitial;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      // Le contrôleur ne sait pas changer de longueur : un autre jeu d'onglets
      // en exige un neuf.
      key: ValueKey(onglets.length),
      length: onglets.length,
      initialIndex: ongletInitial,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titre,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 16),
          // Un bandeau à un seul onglet n'aurait rien à proposer.
          if (onglets.length > 1) ...[
            BarreOngletsPilule(libelles: [for (final (l, _) in onglets) l]),
            const SizedBox(height: 16),
          ],
          Expanded(
            child: TabBarView(
              // Certains écrans ont leurs propres onglets, et les listes leur
              // défilement : le glissement horizontal se battrait avec eux.
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final (_, ecran) in onglets) _GardeEnVie(child: ecran()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Garde un onglet monté quand on le quitte : la division et la promotion qu'on
/// y a choisies vivent dans son état, et les perdre à chaque changement
/// d'onglet obligerait à les resaisir.
class _GardeEnVie extends StatefulWidget {
  const _GardeEnVie({required this.child});

  final Widget child;

  @override
  State<_GardeEnVie> createState() => _GardeEnVieState();
}

class _GardeEnVieState extends State<_GardeEnVie>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
