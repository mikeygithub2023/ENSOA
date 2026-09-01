import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// L'écran de démarrage de l'application tablette, repris tel quel. Il sert
/// désormais aussi d'écran d'attente pendant le chargement du profil : plutôt
/// qu'un rond de progression nu sur fond vide, l'application reste elle-même.
class EcranDemarrage extends StatelessWidget {
  const EcranDemarrage({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.militaryGreen,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/armoiries_ci.png',
              height: 140,
              errorBuilder: (_, _, _) => const SizedBox(),
            ),
            const SizedBox(height: 24),
            Image.asset(
              'assets/images/logo_ensoa.png',
              height: 90,
              errorBuilder: (_, _, _) => const SizedBox(),
            ),
            const SizedBox(height: 24),
            Text(
              "ÉCOLE NATIONALE DES SOUS-OFFICIERS D'ACTIVE",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontWeight: FontWeight.w600,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Système de Gestion Intégrée de L'ENSOA",
              style: TextStyle(color: AppColors.gold, fontSize: 13),
            ),
            const SizedBox(height: 40),
            const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: Colors.white70,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 20),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
