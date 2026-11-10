import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sig_ensoa/core/roles.dart';
import 'package:sig_ensoa/features/auth/providers/auth_providers.dart';
import 'package:sig_ensoa/models/profil.dart';
import 'package:sig_ensoa/shared/widgets/rubrique_a_onglets.dart';
import 'apprenants/apprenants_list_screen.dart';
import 'apprenants/bureaux.dart';
import 'bulletins/bulletins_screen.dart';
import 'cours/cours_screen.dart';
import 'matieres/matieres_screen.dart';

/// Les quatre onglets de la rubrique, chacun derrière la permission qui ouvrait
/// son ancienne entrée de menu : le regroupement n'ouvre rien de plus.
List<(String, Widget Function())> ongletsInstruction(Profil profil) => [
  if (profil.peut(Permission.consulterApprenants))
    (
      'Élèves & Stagiaires',
      () => const ApprenantsListScreen(bureau: Bureau.instruction),
    ),
  if (profil.peut(Permission.gererCours) || profil.peut(Permission.suivreCours))
    ('Cours', () => const CoursScreen()),
  if (profil.peut(Permission.gererMatieres))
    ('Matières', () => const MatieresScreen()),
  if (profil.peut(Permission.editerBulletins))
    ('Bulletins', () => const BulletinsScreen()),
];

/// Le bureau Instruction : l'effectif et sa notation — élèves & stagiaires,
/// cours, matières, bulletins — sous une seule rubrique.
///
/// C'est le pendant de « Soutien technique » : réservé à qui administre la
/// plateforme (voir `nav_items.dart`), qui passe d'un onglet à l'autre sans
/// quitter l'écran. Les autres postes gardent leurs entrées de menu.
///
/// Ce qui ne relève pas de la notation — prise d'armes, consultations,
/// permissions, absences, statistiques d'effectif — se tient désormais sous
/// « Ressources humaines », et non plus ici.
class InstructionScreen extends ConsumerWidget {
  const InstructionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profil = ref.watch(profilCourantProvider).value;
    if (profil == null) return const SizedBox.shrink();

    return RubriqueAOnglets(
      titre: 'Instruction',
      onglets: ongletsInstruction(profil),
    );
  }
}
