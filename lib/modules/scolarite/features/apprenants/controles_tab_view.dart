import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sig_ensoa/core/erreurs.dart';
import 'package:sig_ensoa/core/theme.dart' hide AlertLevel, AlertLevelColor;
import '../../models/classe.dart';
import '../../models/controle.dart';
import '../../models/division.dart';
import '../../models/matiere.dart';
import 'package:sig_ensoa/modules/scolarite/compat.dart';
import '../../shared/widgets/common.dart';
import '../matieres/providers/matieres_providers.dart';
import 'providers/controles_providers.dart';
import 'register_controle_dialog.dart';
import 'sport_section.dart';

/// Matières assignées à la classe qui n'ont pas encore de module — le
/// coefficient du module est saisi à part (voir register_controle_dialog),
/// il n'est plus repris de cette affectation. [excludeControleId] permet,
/// en édition, de garder la matière déjà choisie par ce contrôle dans les
/// options (sinon elle disparaîtrait, "prise" par lui-même).
List<Matiere> computeAvailableModuleMatieres({
  required String classeId,
  required List<Controle> allControles,
  required List<Matiere> matieres,
  required List<MatiereModule> matiereModules,
  String? excludeControleId,
}) {
  final matieresById = {for (final m in matieres) m.id: m};
  final usedMatiereIds = allControles
      .where((c) => c.type == ControleType.module && c.id != excludeControleId)
      .map((c) => c.matiereId)
      .whereType<String>()
      .toSet();
  final options = <Matiere>[];
  for (final module in matiereModules) {
    if (module.classeId != classeId) continue;
    if (usedMatiereIds.contains(module.matiereId)) continue;
    final matiere = matieresById[module.matiereId];
    if (matiere == null) continue;
    options.add(matiere);
  }
  options.sort((a, b) => a.nom.toLowerCase().compareTo(b.nom.toLowerCase()));
  return options;
}

class ControlesTabView extends ConsumerWidget {
  const ControlesTabView({
    super.key,
    required this.division,
    required this.classe,
  });

  final Division division;
  final Classe? classe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classe = this.classe;
    if (classe == null) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: 'Modules / Contrôle continu / Examen'),
          SizedBox(height: 12),
          Expanded(
            child: EmptyState(
              message:
                  'Sélectionnez une classe ou un stage pour gérer les contrôles.',
              icon: Icons.grading_outlined,
            ),
          ),
        ],
      );
    }

    final controlesAsync = ref.watch(controlesByClasseProvider(classe.id));
    // "Modules" ne concerne que les classes (élèves) — pas les stages.
    final types = [
      if (classe.type == ClasseType.phase) ControleType.module,
      ControleType.continu,
      ControleType.examen,
    ];
    final matieres = ref.watch(matieresCatalogueProvider).value ?? const [];
    final matiereModules = ref.watch(matiereModulesProvider).value ?? const [];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Le Sport n'est pas un module qu'on choisit parmi les matières :
          // il existe d'office dans chaque phase (migration 056), et son
          // contenu n'est pas des sous-modules mais des séances.
          if (classe.type == ClasseType.phase)
            controlesAsync.when(
              data: (controles) {
                final moduleSport = controles
                    .where((c) => c.type == ControleType.sport)
                    .firstOrNull;
                if (moduleSport == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: SportSection(classe: classe, moduleSport: moduleSport),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
          for (final type in types) ...[
            controlesAsync.when(
              data: (controles) => _ControleSection(
                division: division,
                classe: classe,
                type: type,
                controles: controles.where((c) => c.type == type).toList(),
                moduleMatieres: type == ControleType.module
                    ? computeAvailableModuleMatieres(
                        classeId: classe.id,
                        allControles: controles,
                        matieres: matieres,
                        matiereModules: matiereModules,
                      )
                    : const [],
                aDesMatieresAffectees: matiereModules.any(
                  (m) => m.classeId == classe.id,
                ),
                computeEditModuleMatieres: type == ControleType.module
                    ? (excludeControleId) => computeAvailableModuleMatieres(
                        classeId: classe.id,
                        allControles: controles,
                        matieres: matieres,
                        matiereModules: matiereModules,
                        excludeControleId: excludeControleId,
                      )
                    : null,
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => EmptyState(
                message: 'Erreur de chargement : ${messageErreur(error)}',
                icon: Icons.error_outline,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }
}

class _ControleSection extends ConsumerWidget {
  const _ControleSection({
    required this.division,
    required this.classe,
    required this.type,
    required this.controles,
    required this.moduleMatieres,
    required this.aDesMatieresAffectees,
    required this.computeEditModuleMatieres,
  });

  final Division division;
  final Classe classe;
  final ControleType type;
  final List<Controle> controles;
  final List<Matiere> moduleMatieres;

  /// La phase a-t-elle au moins une matière affectée — à distinguer de
  /// « toutes ont déjà un module », qui appelle une autre correction.
  final bool aDesMatieresAffectees;

  final List<Matiere> Function(String excludeControleId)?
  computeEditModuleMatieres;

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Controle controle,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Supprimer le contrôle'),
        content: Text(
          'Voulez-vous vraiment supprimer « ${controle.libelle} » ? Les notes associées seront également supprimées.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(controlesRepositoryProvider).deleteControle(controle.id);
      ref.invalidate(controlesByClasseProvider(controle.classeId));
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Contrôle supprimé.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Erreur : ${messageErreur(e)}'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Le Commandant de Brigade ne gère que le sport. Modules, contrôles
    // continus et examens lui sont ouverts en lecture, mais la base refuse
    // qu'il en crée, en corrige ou en supprime : l'écran cesse donc de le
    // lui proposer. Le sport a sa propre section, où il garde la main.
    final peutGerer =
        ref.watch(currentProfileProvider).value?.role !=
        AppRole.commandantBrigade;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: SectionHeader(title: type.sectionLabel(classe.type)),
            ),
            // Le bouton reste actif même sans matière disponible : la
            // fenêtre explique alors ce qui manque. Désactivé, il laissait
            // l'utilisateur devant un bouton gris sans lui dire pourquoi.
            if (peutGerer)
              FilledButton.icon(
                onPressed: () => showRegisterControleDialog(
                  context,
                  division: division,
                  classe: classe,
                  type: type,
                  moduleMatieres: moduleMatieres,
                  aDesMatieresAffectees: aDesMatieresAffectees,
                ),
                icon: const Icon(Icons.add, size: 18),
                label: Text('Enregistrer un ${type.noun(classe.type)}'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (controles.isEmpty)
          EmptyState(
            message: 'Aucun ${type.noun(classe.type)} enregistré.',
            icon: Icons.grading_outlined,
          )
        else
          Column(
            children: [
              for (final controle in controles) ...[
                _ControleTile(
                  controle: controle,
                  peutGerer: peutGerer,
                  onVoirDetail: () => context.push(
                    '/scolarite/apprenants/controles/${controle.id}',
                  ),
                  onEdit: () => showEditControleDialog(
                    context,
                    division: division,
                    classe: classe,
                    existing: controle,
                    moduleMatieres:
                        computeEditModuleMatieres?.call(controle.id) ??
                        const [],
                  ),
                  onDelete: () => _confirmDelete(context, ref, controle),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
      ],
    );
  }
}

class _ControleTile extends StatelessWidget {
  const _ControleTile({
    required this.controle,
    required this.peutGerer,
    required this.onVoirDetail,
    required this.onEdit,
    required this.onDelete,
  });

  final Controle controle;

  /// Faux pour le Commandant de Brigade : il lit ces contrôles sans y
  /// toucher.
  final bool peutGerer;
  final VoidCallback onVoirDetail;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.blueMist,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                controle.libelle,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 16),
            StatusChip(
              label: 'Coefficient ${controle.coefficient}',
              level: AlertLevel.info,
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: onVoirDetail,
              child: const Text('Détail'),
            ),
            if (peutGerer) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: onEdit,
                tooltip: 'Modifier',
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: AppColors.danger,
                ),
                onPressed: onDelete,
                tooltip: 'Supprimer',
              ),
            ],
          ],
        ),
      ),
    );
  }
}
