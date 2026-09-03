import 'package:flutter/material.dart';

/// Icône « fusil d'assaut » — Material Icons n'en propose délibérément
/// aucune, et l'armement doit bien se représenter quelque part.
///
/// Le dessin fourni occupe une toile carrée dont l'arme ne remplit qu'une
/// bande centrale : posé tel quel dans un carré de 20 px, il ne restait qu'un
/// trait de 7 px de haut, illisible. On recadre donc sur la bande utile, et
/// l'icône occupe toute la largeur qu'on lui donne.
class IconeArme extends StatelessWidget {
  const IconeArme({super.key, this.size = 22});

  /// La largeur de l'icône. La hauteur en découle : celle de l'arme seule.
  final double size;

  /// Part de la toile réellement occupée par le dessin, mesurée sur l'image.
  static const _bandeUtile = 0.4;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * _bandeUtile,
      child: ClipRect(
        child: Align(
          alignment: Alignment.center,
          heightFactor: _bandeUtile,
          child: Image.asset(
            'assets/images/fusil_assaut.png',
            width: size,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

/// La même icône, à la couleur demandée.
///
/// Le dessin est une image, non une police : il ne suit pas `color` comme le
/// ferait une `Icon`. Le filtre le remplace donc à plat, ce qui convient à
/// une silhouette pleine.
class IconeArmeTeintee extends StatelessWidget {
  const IconeArmeTeintee({super.key, required this.couleur, this.size = 22});

  final Color couleur;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ColorFiltered(
      colorFilter: ColorFilter.mode(couleur, BlendMode.srcIn),
      child: IconeArme(size: size),
    );
  }
}
