import 'package:flutter/material.dart';

import 'package:sig_ensoa/core/theme.dart';
import '../../shared/widgets/dashboard_widgets.dart';

/// Une ligne d'alerte : ce qu'il faut lire, où cela mène, et de quoi il
/// s'agit.
///
/// Toutes portaient la même pastille bleue. Sur cinq lignes empilées, rien
/// ne distinguait un retour d'arme d'une soute vide avant d'avoir lu la
/// phrase : l'œil devait tout relire pour trouver ce qui pressait.
/// [icone] est facultative — sans elle, la pastille reprend sa place.
class Alerte {
  const Alerte(this.label, this.onTap, {this.icone, this.iconeWidget});

  final String label;
  final VoidCallback onTap;
  final IconData? icone;

  /// Pour ce que Material ne dessine pas — une arme, par exemple.
  final Widget? iconeWidget;
}

/// La carte sombre des alertes prioritaires.
///
/// Chaque poste a les siennes — le chef du soutien technique celles des trois
/// services, l'armurier celles de son armurerie, l'officier adjoint celles de
/// ses activités —, mais toutes se lisent de la même façon. La carte est donc
/// commune : trois copies de ce dessin auraient divergé à la première
/// retouche.
class AlertesCard extends StatelessWidget {
  const AlertesCard({
    super.key,
    required this.alertes,
    this.titre = 'Alertes prioritaires',
  });

  final List<Alerte> alertes;
  final String titre;

  @override
  Widget build(BuildContext context) {
    return DarkFeatureCard(
      title: titre,
      child: alertes.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Aucune alerte en cours — situation nominale.',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            )
          : Column(
              children: [
                for (final a in alertes.take(5))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: a.onTap,
                      child: Row(
                        children: [
                          SizedBox(
                            width: 18,
                            child: Center(
                              child:
                                  a.iconeWidget ??
                                  (a.icone != null
                                      ? Icon(
                                          a.icone,
                                          size: 16,
                                          color: AppColors.blueBright,
                                        )
                                      : Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: AppColors.blueBright,
                                            shape: BoxShape.circle,
                                          ),
                                        )),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            // Une alerte tient sur une ligne : le détail — un
                            // devis de réparation peut faire trente lignes — se
                            // lit au clic, sur l'écran du domaine. Sans cette
                            // limite, une seule alerte bavarde gonflait la carte
                            // et, les deux cartes partageant leur hauteur,
                            // laissait la jauge voisine flotter dans le vide.
                            child: Text(
                              a.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.white38,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
