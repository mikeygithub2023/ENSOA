import 'package:flutter/material.dart';

import 'package:sig_ensoa/core/theme.dart';
import '../../shared/widgets/dashboard_widgets.dart';

/// Une ligne d'alerte : ce qu'il faut lire, et où cela mène.
class Alerte {
  const Alerte(this.label, this.onTap);

  final String label;
  final VoidCallback onTap;
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
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.blueBright,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              a.label,
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
