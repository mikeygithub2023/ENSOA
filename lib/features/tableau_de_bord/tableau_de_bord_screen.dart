import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../modules/logistique/features/dashboard/dashboard_screen.dart'
    as logistique;
import '../../modules/scolarite/features/dashboard/dashboard_screen.dart'
    as scolarite;
import '../auth/providers/auth_providers.dart';

/// Le tableau de bord de l'école — un seul, les deux domaines sur la même
/// page.
///
/// Chacun des deux gérait son propre défilement, ce qui interdisait de les
/// empiler. Ils savent désormais se rendre « sans cadre » : la page ci-dessous
/// porte le défilement unique, et l'on descend de la scolarité au soutien
/// technique d'un seul mouvement.
///
/// Chacun ne voit que ce dont il relève : un instructeur n'a que la scolarité,
/// un armurier que le soutien technique, l'administrateur les deux.
class TableauDeBordScreen extends ConsumerWidget {
  const TableauDeBordScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profil = ref.watch(profilCourantProvider).value;
    if (profil == null) return const SizedBox.shrink();

    final deuxDomaines =
        profil.releveDeLaScolarite && profil.releveDuSoutienTechnique;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (profil.releveDeLaScolarite) ...[
            // Les titres de domaine ne s'affichent que pour celui qui relève
            // des deux : pour les autres, ils n'apprendraient rien.
            if (deuxDomaines) const _TitreDomaine('Scolarité'),
            const scolarite.DashboardScreen(sansCadre: true),
          ],
          if (deuxDomaines) const SizedBox(height: 32),
          if (profil.releveDuSoutienTechnique) ...[
            if (deuxDomaines) const _TitreDomaine('Soutien technique'),
            const logistique.DashboardScreen(sansCadre: true),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _TitreDomaine extends StatelessWidget {
  const _TitreDomaine(this.texte);

  final String texte;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Text(
            texte.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: AppColors.inkMuted,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Divider(color: AppColors.border, height: 1)),
        ],
      ),
    );
  }
}
