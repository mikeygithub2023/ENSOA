import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sig_ensoa/core/roles.dart';
import 'package:sig_ensoa/features/auth/providers/auth_providers.dart';
import 'package:sig_ensoa/models/profil.dart';
import 'package:sig_ensoa/shared/widgets/rubrique_a_onglets.dart';
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

    return RubriqueAOnglets(
      titre: 'Scolarité',
      onglets: ongletsScolarite(profil),
    );
  }
}
