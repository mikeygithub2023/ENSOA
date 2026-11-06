import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sig_ensoa/core/roles.dart';
import 'package:sig_ensoa/features/auth/providers/auth_providers.dart';
import 'package:sig_ensoa/models/profil.dart';
import 'package:sig_ensoa/shared/widgets/rubrique_a_onglets.dart';
import 'consultations/consultations_screen.dart';
import 'depenses/depenses_screen.dart';
import 'medicaments/medicaments_screen.dart';
import 'visites/visites_medicales_screen.dart';

/// Les quatre onglets de la rubrique, chacun derrière la permission qui ouvrait
/// son ancienne entrée de menu : le regroupement n'ouvre rien de plus.
List<(String, Widget Function())> ongletsSante(Profil profil) => [
  if (profil.peut(Permission.gererConsultations))
    ('Consultations', () => const ConsultationsScreen()),
  if (profil.peut(Permission.gererVisitesMedicales))
    ('Visites médicales', () => const VisitesMedicalesScreen()),
  if (profil.peut(Permission.gererPharmacie))
    ('Pharmacie', () => const MedicamentsScreen()),
  if (profil.peut(Permission.gererDepensesSante))
    ('Dépenses santé', () => const DepensesScreen()),
];

/// Consultations, visites médicales, pharmacie et dépenses sous une seule
/// rubrique, réservée comme « Scolarité » à qui administre la plateforme (voir
/// `nav_items.dart`). Le médecin garde ses entrées de menu.
class SanteScreen extends ConsumerWidget {
  const SanteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profil = ref.watch(profilCourantProvider).value;
    if (profil == null) return const SizedBox.shrink();

    return RubriqueAOnglets(titre: 'Santé', onglets: ongletsSante(profil));
  }
}
