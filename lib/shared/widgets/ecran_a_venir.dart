import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Emplacement d'un écran encore à reprendre depuis l'une des deux
/// applications d'origine. Il tient la route et la place dans la navigation
/// le temps du portage, plutôt que de laisser un menu qui mène au vide.
class EcranAVenir extends StatelessWidget {
  const EcranAVenir({super.key, required this.titre, required this.origine});

  final String titre;

  /// D'où vient l'écran : « ENSOA GSES » ou « ERP ENSOA ». Sert de mémo de
  /// portage autant qu'à l'utilisateur.
  final String origine;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.construction_outlined,
              size: 44,
              color: AppColors.inkMuted,
            ),
            const SizedBox(height: 16),
            Text(
              titre,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Écran en cours de reprise depuis $origine.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}
