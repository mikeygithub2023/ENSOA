import 'package:flutter/material.dart';

/// Dispose des cartes sur une rangée : elles se partagent la largeur
/// disponible à parts égales et s'alignent toutes sur la hauteur de la plus
/// haute.
///
/// Un `Wrap` laisserait chaque carte prendre sa hauteur propre : celle dont
/// le libellé passe sur deux lignes dépasserait les autres, et leur largeur
/// fixe laisserait un vide à droite. `IntrinsicHeight` + `stretch` règle les
/// deux d'un coup.
///
/// Les cartes ne doivent donc pas fixer leur propre largeur.
class LigneCartes extends StatelessWidget {
  const LigneCartes({super.key, required this.cartes, this.espacement = 12});

  final List<Widget> cartes;
  final double espacement;

  @override
  Widget build(BuildContext context) {
    if (cartes.isEmpty) return const SizedBox.shrink();

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < cartes.length; i++) ...[
            if (i > 0) SizedBox(width: espacement),
            Expanded(child: cartes[i]),
          ],
        ],
      ),
    );
  }
}
