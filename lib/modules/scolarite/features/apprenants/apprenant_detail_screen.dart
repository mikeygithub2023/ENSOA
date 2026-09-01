import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sig_ensoa/core/erreurs.dart';

import '../../models/classe.dart';
import '../../models/division.dart';
import '../../shared/widgets/common.dart';
import '../matieres/providers/matieres_providers.dart';
import 'apprenant_detail_view.dart';
import 'providers/apprenants_providers.dart';

class ApprenantDetailScreen extends ConsumerWidget {
  const ApprenantDetailScreen({super.key, required this.apprenantId});

  final String apprenantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apprenantAsync = ref.watch(apprenantByIdProvider(apprenantId));
    final divisionsAsync = ref.watch(divisionsProvider);
    final classesAsync = ref.watch(classesListProvider);

    return apprenantAsync.when(
      data: (apprenant) {
        if (apprenant == null) {
          return const EmptyState(
            message: 'Apprenant introuvable.',
            icon: Icons.person_off_outlined,
          );
        }
        final divisions = {
          for (final d in divisionsAsync.value ?? <Division>[]) d.id: d,
        };
        final classes = {
          for (final c in classesAsync.value ?? <Classe>[]) c.id: c,
        };
        final division = divisions[apprenant.divisionId];
        final classe = classes[apprenant.classeId];
        if (division == null || classe == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return ApprenantDetailView(
          apprenant: apprenant,
          division: division,
          classe: classe,
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => EmptyState(
        message: 'Erreur de chargement : ${messageErreur(error)}',
        icon: Icons.error_outline,
      ),
    );
  }
}
