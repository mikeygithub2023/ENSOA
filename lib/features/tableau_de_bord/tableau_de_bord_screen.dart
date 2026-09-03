import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/roles.dart';
import '../../modules/logistique/features/dashboard/dashboard_activites.dart';
import '../../modules/logistique/features/dashboard/dashboard_armurerie.dart';
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
/// Chacun ne voit que ce dont il relève : un commandant n'a que la
/// scolarité, un armurier que son armurerie, l'administrateur tout.
///
/// Et au sein du soutien technique, chaque poste a le sien. Le chef du
/// service tient les trois — carburant, parc, armement ; l'armurier n'a que
/// son armurerie ; l'Officier Adjoint, qui ne tient aucun service, a ses
/// activités. Leur servir à tous le tableau du chef revenait à noyer les
/// deux chiffres qui les concernaient au milieu de vingt qui ne les
/// regardaient pas.
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
            if (deuxDomaines) _TitreDomaine(_domaine(profil.roleLogistique)),
            _tableauDuPoste(profil.roleLogistique),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// Le tableau que ce poste doit lire.
Widget _tableauDuPoste(RoleLogistique? role) => switch (role) {
  RoleLogistique.armurerie => const DashboardArmurerie(sansCadre: true),
  RoleLogistique.officierAdjoint => const DashboardActivites(sansCadre: true),
  _ => const logistique.DashboardScreen(sansCadre: true),
};

/// Le titre de domaine ne s'affiche que pour celui qui relève des deux ;
/// autant qu'il nomme ce qu'on lit vraiment.
String _domaine(RoleLogistique? role) => switch (role) {
  RoleLogistique.armurerie => 'Armurerie',
  RoleLogistique.officierAdjoint => 'Activités',
  _ => 'Soutien technique',
};

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
