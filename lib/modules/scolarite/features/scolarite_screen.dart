import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sig_ensoa/core/roles.dart';
import 'package:sig_ensoa/core/theme.dart';
import 'package:sig_ensoa/features/auth/providers/auth_providers.dart';
import 'package:sig_ensoa/models/profil.dart';
import 'package:sig_ensoa/shared/widgets/barre_onglets_pilule.dart';
import 'apprenants/apprenants_list_screen.dart';
import 'bulletins/bulletins_screen.dart';
import 'cours/cours_screen.dart';
import 'matieres/matieres_screen.dart';

/// Les quatre onglets de la rubrique, chacun derrière la permission qui ouvrait
/// son ancienne entrée de menu : le regroupement n'ouvre rien de plus.
List<(String, Widget Function())> ongletsScolarite(Profil profil) => [
  if (profil.peut(Permission.consulterApprenants))
    ('Élèves & Stagiaires', () => const ApprenantsListScreen()),
  if (profil.peut(Permission.gererCours) || profil.peut(Permission.suivreCours))
    ('Cours', () => const CoursScreen()),
  if (profil.peut(Permission.gererMatieres))
    ('Matières', () => const MatieresScreen()),
  if (profil.peut(Permission.editerBulletins))
    ('Bulletins', () => const BulletinsScreen()),
];

/// Élèves & stagiaires, cours, matières et bulletins sous une seule rubrique.
///
/// C'est le pendant de « Soutien technique » : réservé à qui administre la
/// plateforme (voir `nav_items.dart`), qui passe d'un onglet à l'autre sans
/// quitter l'écran. Les autres postes gardent leurs entrées de menu.
class ScolariteScreen extends ConsumerWidget {
  const ScolariteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profil = ref.watch(profilCourantProvider).value;
    if (profil == null) return const SizedBox.shrink();

    final onglets = ongletsScolarite(profil);

    return DefaultTabController(
      // Le contrôleur ne sait pas changer de longueur : un autre jeu d'onglets
      // en exige un neuf.
      key: ValueKey(onglets.length),
      length: onglets.length,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Scolarité',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 16),
          BarreOngletsPilule(libelles: [for (final (l, _) in onglets) l]),
          const SizedBox(height: 16),
          Expanded(
            child: TabBarView(
              // Matières a ses propres onglets, et les listes leur défilement :
              // le glissement horizontal se battrait avec eux.
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
