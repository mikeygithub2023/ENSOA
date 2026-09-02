import 'package:sig_ensoa/core/formulaire.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sig_ensoa/core/erreurs.dart';
import 'package:sig_ensoa/core/theme.dart' hide AlertLevel, AlertLevelColor;
import '../../models/division.dart';
import 'package:sig_ensoa/modules/scolarite/compat.dart';
import '../../models/promotion.dart';
import '../../shared/widgets/common.dart';
import '../apprenants/providers/apprenants_providers.dart';
import 'providers/matieres_providers.dart';

/// Les promotions, groupées par division.
///
/// Seules la Formation Initiale et la Formation des Spécialistes en ont :
/// la Formation Continue ne contient que des stages, qui relèvent
/// directement de leur division. L'écran ne propose donc pas d'en créer là.
class PromotionsTab extends ConsumerWidget {
  const PromotionsTab({super.key});

  /// Les divisions organisées en promotions, reconnues à leur code.
  static const _codesAPromotions = {
    'formation_initiale',
    'formation_specialistes',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final promotionsAsync = ref.watch(promotionsListProvider);
    final divisionsAsync = ref.watch(divisionsProvider);
    final profile = ref.watch(currentProfileProvider).value;
    final peutEcrire =
        profile != null &&
        (profile.role == AppRole.admin || profile.role == AppRole.chefDivision);

    final divisions = (divisionsAsync.value ?? const <Division>[])
        .where((d) => _codesAPromotions.contains(d.code))
        .where(
          (d) => profile?.role == AppRole.admin || d.id == profile?.divisionId,
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Promotions',
          trailing: peutEcrire && divisions.isNotEmpty
              ? FilledButton.icon(
                  onPressed: () => _formulaire(context, ref, divisions),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Ajouter'),
                )
              : null,
        ),
        const SizedBox(height: 16),
        Expanded(
          child: promotionsAsync.when(
            data: (promotions) {
              if (divisions.isEmpty) {
                return const EmptyState(
                  message:
                      'Aucune division organisée en promotions n\'est de votre '
                      'ressort.',
                  icon: Icons.groups_2_outlined,
                );
              }

              final blocs = <Widget>[];
              for (final division in divisions) {
                final siennes = promotions
                    .where((p) => p.divisionId == division.id)
                    .toList();
                if (blocs.isNotEmpty) blocs.add(const SizedBox(height: 20));
                blocs.add(_TitreDivision(nom: division.nom));
                if (siennes.isEmpty) {
                  blocs.add(
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Aucune promotion. Créez-en une avant d\'y ajouter des '
                        'phases.',
                        style: TextStyle(
                          color: AppColors.inkMuted,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }
                for (final promotion in siennes) {
                  blocs.add(
                    _CartePromotion(
                      promotion: promotion,
                      peutEcrire: peutEcrire,
                      divisions: divisions,
                    ),
                  );
                }
              }
              return ListView(children: blocs);
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => EmptyState(
              message: 'Erreur de chargement : ${messageErreur(error)}',
              icon: Icons.error_outline,
            ),
          ),
        ),
      ],
    );
  }
}

class _TitreDivision extends StatelessWidget {
  const _TitreDivision({required this.nom});

  final String nom;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        nom,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          color: AppColors.ink,
          fontSize: 14,
        ),
      ),
    );
  }
}

class _CartePromotion extends ConsumerWidget {
  const _CartePromotion({
    required this.promotion,
    required this.peutEcrire,
    required this.divisions,
  });

  final Promotion promotion;
  final bool peutEcrire;
  final List<Division> divisions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Le nombre de phases dit d'un coup d'œil si la promotion est armée.
    final phases = (ref.watch(classesListProvider).value ?? const [])
        .where((c) => c.promotionId == promotion.id)
        .toList();
    // Depuis la migration 059, supprimer une promotion emporte réellement
    // ses élèves : l'avertissement doit les compter, pas seulement les
    // mentionner.
    final phasesIds = {for (final p in phases) p.id};
    final nombreApprenants =
        (ref.watch(apprenantsListProvider).value ?? const [])
            .where((a) => phasesIds.contains(a.classeId))
            .length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: ListTile(
          leading: const Icon(
            Icons.groups_2_outlined,
            color: AppColors.blueDeep,
          ),
          title: Text(
            promotion.intitule,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            phases.isEmpty
                ? 'Aucune phase'
                : phases.map((p) => p.nom).join(' · '),
          ),
          trailing: peutEcrire
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      tooltip: 'Modifier',
                      onPressed: () => _formulaire(
                        context,
                        ref,
                        divisions,
                        promotion: promotion,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: AppColors.danger,
                      ),
                      tooltip: 'Supprimer',
                      onPressed: () => _confirmerSuppression(
                        context,
                        ref,
                        promotion,
                        phases.length,
                        nombreApprenants,
                      ),
                    ),
                  ],
                )
              : null,
        ),
      ),
    );
  }
}

/// Création et modification partagent le même formulaire : une promotion ne
/// porte qu'un nom et une année.
Future<void> _formulaire(
  BuildContext context,
  WidgetRef ref,
  List<Division> divisions, {
  Promotion? promotion,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final formKey = GlobalKey<FormState>();
  final nomController = TextEditingController(text: promotion?.nom);
  final anneeController = TextEditingController(
    text: promotion?.annee?.toString(),
  );
  final modification = promotion != null;
  String? divisionId = promotion?.divisionId ?? divisions.first.id;

  await showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        scrollable: true,
        title: Text(
          modification ? 'Modifier la promotion' : 'Nouvelle promotion',
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // La division ne se change pas après coup : les phases y sont
              // déjà rattachées, et les déplacer n'aurait pas de sens.
              if (modification)
                InputDecorator(
                  decoration: const InputDecoration(labelText: 'Division'),
                  child: Text(
                    divisions
                        .firstWhere(
                          (d) => d.id == divisionId,
                          orElse: () => divisions.first,
                        )
                        .nom,
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  initialValue: divisionId,
                  decoration: const InputDecoration(labelText: 'Division'),
                  items: [
                    for (final d in divisions)
                      DropdownMenuItem(value: d.id, child: Text(d.nom)),
                  ],
                  onChanged: (value) => setState(() => divisionId = value),
                  validator: (v) => v == null ? 'Champ requis' : null,
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: nomController,
                decoration: const InputDecoration(
                  labelText: 'Nom (ex. 42ᵉ promotion)',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: anneeController,
                decoration: const InputDecoration(
                  labelText: 'Année d\'incorporation (facultatif)',
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  final texte = v?.trim() ?? '';
                  if (texte.isEmpty) return null;
                  final annee = int.tryParse(texte);
                  return annee == null || annee < 1960 || annee > 2100
                      ? 'Année invalide'
                      : null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () async {
              if (!validerFormulaire(context, formKey)) return;
              final annee = int.tryParse(anneeController.text.trim());
              final depot = ref.read(promotionsRepositoryProvider);
              try {
                if (modification) {
                  await depot.update(
                    id: promotion.id,
                    nom: nomController.text.trim(),
                    annee: annee,
                  );
                } else {
                  await depot.create(
                    divisionId: divisionId!,
                    nom: nomController.text.trim(),
                    annee: annee,
                  );
                }
                ref.invalidate(promotionsListProvider);
                if (context.mounted) Navigator.of(context).pop();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      modification
                          ? 'Promotion modifiée avec succès.'
                          : 'Promotion créée avec succès.',
                    ),
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
            },
            child: Text(modification ? 'Enregistrer' : 'Créer'),
          ),
        ],
      ),
    ),
  );
}

Future<void> _confirmerSuppression(
  BuildContext context,
  WidgetRef ref,
  Promotion promotion,
  int nombreDePhases,
  int nombreApprenants,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final confirme = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      scrollable: true,
      title: const Text('Supprimer la promotion'),
      // Une promotion emporte ses phases, et une phase emporte son
      // programme : l'avertissement doit être chiffré, pas vague.
      content: Text(
        nombreDePhases == 0
            ? '${promotion.intitule} sera supprimée. Elle ne contient aucune '
                  'phase.'
            : '${promotion.intitule} sera supprimée, et avec elle ses '
                  '$nombreDePhases phase(s)'
                  '${nombreApprenants == 0 ? "" : " et leurs $nombreApprenants "
                            "apprenant(s)"} — matières, modules, évaluations, '
                  'notes, cours, absences, permissions et consultations '
                  'compris. Cette action est irréversible.'
                  '${nombreApprenants == 0 ? "" : "\n\nLes comptes Espace "
                            "élève correspondants ne sont pas fermés pour autant : "
                            "faites-le depuis Administration › Espaces élèves."}',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          style: nombreDePhases == 0
              ? null
              : FilledButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Supprimer'),
        ),
      ],
    ),
  );
  if (confirme != true) return;

  try {
    await ref.read(promotionsRepositoryProvider).delete(promotion.id);
    ref.invalidate(promotionsListProvider);
    ref.invalidate(classesListProvider);
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Promotion supprimée.'),
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
