import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sig_ensoa/core/erreurs.dart';
import 'package:sig_ensoa/core/theme.dart' hide AlertLevel, AlertLevelColor;
import '../../models/apprenant.dart';
import '../../models/classe.dart';
import '../../models/division.dart';
import '../../models/matiere.dart';
import '../../models/promotion.dart';
import 'package:sig_ensoa/modules/scolarite/compat.dart';
import '../../shared/widgets/common.dart';
import '../apprenants/providers/apprenants_providers.dart';
import 'activites_sportives_tab.dart';
import 'promotions_tab.dart';
import 'providers/matieres_providers.dart';

class MatieresScreen extends StatelessWidget {
  const MatieresScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TabBar(
            isScrollable: true,
            labelColor: AppColors.navy,
            unselectedLabelColor: AppColors.inkMuted,
            indicatorColor: AppColors.navy,
            tabs: [
              Tab(text: 'Catalogue'),
              Tab(text: 'Activités sportives'),
              Tab(text: 'Promotions'),
              Tab(text: 'Phases / Stages'),
              Tab(text: 'Affectations par phase'),
            ],
          ),
          const SizedBox(height: 16),
          const Expanded(
            child: TabBarView(
              children: [
                _CatalogueTab(),
                ActivitesSportivesTab(),
                PromotionsTab(),
                _ClassesTab(),
                _AffectationsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _divisionNom(List<Division> divisions, String? id) {
  for (final d in divisions) {
    if (d.id == id) return d.nom;
  }
  return '—';
}

class _CatalogueTab extends ConsumerWidget {
  const _CatalogueTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matieresAsync = ref.watch(matieresCatalogueProvider);
    final profile = ref.watch(currentProfileProvider).value;
    final isAdmin = profile?.role == AppRole.admin;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Catalogue des matières',
          trailing: isAdmin
              ? FilledButton.icon(
                  onPressed: () => _showAddMatiereDialog(context, ref),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Ajouter'),
                )
              : null,
        ),
        const SizedBox(height: 16),
        Expanded(
          child: matieresAsync.when(
            data: (matieres) {
              if (matieres.isEmpty) {
                return const EmptyState(
                  message: 'Aucune matière au catalogue.',
                  icon: Icons.menu_book_outlined,
                );
              }
              return ListView.separated(
                itemCount: matieres.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final matiere = matieres[index];
                  return Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.menu_book_outlined,
                        color: AppColors.blueDeep,
                      ),
                      title: Text(
                        matiere.nom,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(matiere.code),
                      trailing: isAdmin
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 20,
                                  ),
                                  tooltip: 'Modifier',
                                  onPressed: () => _showEditMatiereDialog(
                                    context,
                                    ref,
                                    matiere,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 20,
                                    color: AppColors.danger,
                                  ),
                                  tooltip: 'Supprimer',
                                  onPressed: () => _confirmDeleteMatiere(
                                    context,
                                    ref,
                                    matiere,
                                  ),
                                ),
                              ],
                            )
                          : null,
                    ),
                  );
                },
              );
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

  Future<void> _showAddMatiereDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final codeController = TextEditingController();
    final nomController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Nouvelle matière'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: codeController,
                decoration: const InputDecoration(labelText: 'Code'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: nomController,
                decoration: const InputDecoration(labelText: 'Nom'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
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
              if (!(formKey.currentState?.validate() ?? false)) return;
              await ref
                  .read(matieresRepositoryProvider)
                  .createMatiere(
                    code: codeController.text.trim(),
                    nom: nomController.text.trim(),
                  );
              ref.invalidate(matieresCatalogueProvider);
              if (context.mounted) Navigator.of(context).pop();
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Matière créée avec succès.'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            child: const Text('Créer'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditMatiereDialog(
    BuildContext context,
    WidgetRef ref,
    Matiere matiere,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final codeController = TextEditingController(text: matiere.code);
    final nomController = TextEditingController(text: matiere.nom);
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Modifier la matière'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: codeController,
                decoration: const InputDecoration(labelText: 'Code'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: nomController,
                decoration: const InputDecoration(labelText: 'Nom'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
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
              if (!(formKey.currentState?.validate() ?? false)) return;
              await ref
                  .read(matieresRepositoryProvider)
                  .updateMatiere(
                    id: matiere.id,
                    code: codeController.text.trim(),
                    nom: nomController.text.trim(),
                  );
              ref.invalidate(matieresCatalogueProvider);
              if (context.mounted) Navigator.of(context).pop();
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Matière modifiée avec succès.'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteMatiere(
    BuildContext context,
    WidgetRef ref,
    Matiere matiere,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Supprimer la matière'),
        content: Text(
          'Voulez-vous vraiment supprimer « ${matiere.nom} » ? '
          'Ses affectations aux classes seront également supprimées. Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Supprimer',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(matieresRepositoryProvider).deleteMatiere(matiere.id);
      ref.invalidate(matieresCatalogueProvider);
      ref.invalidate(matiereModulesProvider);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Matière supprimée avec succès.'),
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
}

/// Référentiel des classes (élèves) et stages (stagiaires) par division —
/// alimente le menu déroulant « Classe » dans l'onglet Affectations.
class _ClassesTab extends ConsumerWidget {
  const _ClassesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classesAsync = ref.watch(classesListProvider);
    final divisionsAsync = ref.watch(divisionsProvider);
    final profile = ref.watch(currentProfileProvider).value;
    final canWrite =
        profile != null &&
        (profile.role == AppRole.admin || profile.role == AppRole.chefDivision);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Phases / Stages',
          trailing: canWrite
              ? FilledButton.icon(
                  onPressed: () => _showAddClasseDialog(
                    context,
                    ref,
                    profile,
                    divisionsAsync.value ?? const [],
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Ajouter'),
                )
              : null,
        ),
        const SizedBox(height: 16),
        Expanded(
          child: classesAsync.when(
            data: (classes) {
              if (classes.isEmpty) {
                return const EmptyState(
                  message: 'Aucune classe enregistrée.',
                  icon: Icons.class_outlined,
                );
              }
              final divisions = divisionsAsync.value ?? const <Division>[];
              final promotionsById = {
                for (final p
                    in ref.watch(promotionsListProvider).value ??
                        const <Promotion>[])
                  p.id: p,
              };
              final items = <Widget>[];
              for (final division in divisions) {
                // Les phases se rangent par promotion, les stages ensuite :
                // trier sur le seul nom entrelacerait des phases de
                // promotions différentes. Le « ~ » place les stages en fin
                // de liste, après toute promotion.
                final classesOfDivision =
                    classes.where((c) => c.divisionId == division.id).toList()
                      ..sort((a, b) {
                        final cleA =
                            promotionsById[a.promotionId]?.intitule ?? '~';
                        final cleB =
                            promotionsById[b.promotionId]?.intitule ?? '~';
                        final parPromotion = cleA.compareTo(cleB);
                        return parPromotion != 0
                            ? parPromotion
                            : a.nom.toLowerCase().compareTo(
                                b.nom.toLowerCase(),
                              );
                      });
                if (classesOfDivision.isEmpty) continue;
                if (items.isNotEmpty) items.add(const SizedBox(height: 20));
                items.add(
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      division.nom,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
                for (final classe in classesOfDivision) {
                  items.add(
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        child: ListTile(
                          leading: const Icon(
                            Icons.class_outlined,
                            color: AppColors.blueDeep,
                          ),
                          // Une phase se lit avec sa promotion : deux
                          // promotions d'une même division peuvent porter
                          // des phases du même nom, et rien ne les
                          // distinguerait dans cette liste. Un stage n'a
                          // pas de promotion, son nom suffit.
                          title: Row(
                            children: [
                              if (promotionsById[classe.promotionId] !=
                                  null) ...[
                                Text(
                                  promotionsById[classe.promotionId]!.intitule,
                                  style: const TextStyle(
                                    color: AppColors.inkMuted,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                const Text(
                                  '  ·  ',
                                  style: TextStyle(color: AppColors.inkMuted),
                                ),
                              ],
                              Text(
                                classe.nom,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              StatusChip(
                                label: classe.estCloturee
                                    ? 'Clôturée'
                                    : classe.type.label,
                                level: classe.estCloturee
                                    ? AlertLevel.success
                                    : classe.type == ClasseType.phase
                                    ? AlertLevel.info
                                    : AlertLevel.warning,
                              ),
                              // Clôturer fige la phase et fait monter ses
                              // élèves : réservé à l'administrateur, et
                              // seulement pour une phase.
                              if (canWrite &&
                                  classe.type == ClasseType.phase) ...[
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: Icon(
                                    classe.estCloturee
                                        ? Icons.lock_open_outlined
                                        : Icons.lock_outline,
                                    size: 20,
                                  ),
                                  tooltip: classe.estCloturee
                                      ? 'Rouvrir la phase'
                                      : 'Clôturer la phase',
                                  onPressed: () {
                                    if (classe.estCloturee) {
                                      _confirmerReouverturePhase(
                                        context,
                                        ref,
                                        classe,
                                      );
                                      return;
                                    }
                                    final effectif =
                                        (ref
                                                    .read(
                                                      apprenantsListProvider,
                                                    )
                                                    .value ??
                                                const [])
                                            .where(
                                              (a) =>
                                                  a.classeId == classe.id &&
                                                  a.statut ==
                                                      ApprenantStatut.actif,
                                            )
                                            .length;
                                    _confirmerCloturePhase(
                                      context,
                                      ref,
                                      classe,
                                      effectif,
                                    );
                                  },
                                ),
                              ],
                              if (canWrite) ...[
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 20,
                                  ),
                                  tooltip: 'Modifier',
                                  onPressed: () => _showEditClasseDialog(
                                    context,
                                    ref,
                                    classe,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 20,
                                    color: AppColors.danger,
                                  ),
                                  tooltip: 'Supprimer',
                                  onPressed: () => _confirmDeleteClasse(
                                    context,
                                    ref,
                                    classe,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }
              }
              return ListView(children: items);
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

  Future<void> _showAddClasseDialog(
    BuildContext context,
    WidgetRef ref,
    Profile? profile,
    List<Division> divisions,
  ) async {
    if (profile == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final nomController = TextEditingController();
    final coefficientController = TextEditingController(text: '1');
    final formKey = GlobalKey<FormState>();
    final isAdmin = profile.role == AppRole.admin;
    String? divisionId = isAdmin
        ? (divisions.isNotEmpty ? divisions.first.id : null)
        : profile.divisionId;
    ClasseType type = ClasseType.phase;
    String? promotionId;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          scrollable: true,
          title: const Text('Nouvelle phase / stage'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<ClasseType>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: [
                    for (final t in ClasseType.values)
                      DropdownMenuItem(value: t, child: Text(t.label)),
                  ],
                  onChanged: (value) => setState(() => type = value!),
                ),
                const SizedBox(height: 12),
                if (isAdmin)
                  DropdownButtonFormField<String>(
                    initialValue: divisionId,
                    decoration: const InputDecoration(labelText: 'Division'),
                    items: [
                      for (final d in divisions)
                        DropdownMenuItem(value: d.id, child: Text(d.nom)),
                    ],
                    onChanged: (value) => setState(() => divisionId = value),
                    validator: (value) => value == null ? 'Champ requis' : null,
                  )
                else
                  InputDecorator(
                    decoration: const InputDecoration(labelText: 'Division'),
                    child: Text(_divisionNom(divisions, divisionId)),
                  ),
                // Une phase appartient à une promotion ; un stage relève
                // directement de sa division. La liste ne s'affiche donc
                // que dans le premier cas.
                if (type == ClasseType.phase) ...[
                  const SizedBox(height: 12),
                  Consumer(
                    builder: (context, ref, _) {
                      final promotions = divisionId == null
                          ? const <Promotion>[]
                          : ref.watch(
                              promotionsParDivisionProvider(divisionId!),
                            );
                      if (promotions.isEmpty) {
                        return const InputDecorator(
                          decoration: InputDecoration(labelText: 'Promotion'),
                          child: Text(
                            'Aucune promotion dans cette division — créez-en '
                            'une dans l\'onglet Promotions.',
                            style: TextStyle(
                              color: AppColors.inkMuted,
                              fontSize: 12.5,
                            ),
                          ),
                        );
                      }
                      return DropdownButtonFormField<String>(
                        initialValue: promotions.any((p) => p.id == promotionId)
                            ? promotionId
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Promotion',
                        ),
                        items: [
                          for (final p in promotions)
                            DropdownMenuItem(
                              value: p.id,
                              child: Text(p.intitule),
                            ),
                        ],
                        onChanged: (value) =>
                            setState(() => promotionId = value),
                        validator: (value) =>
                            value == null ? 'Champ requis' : null,
                      );
                    },
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: nomController,
                  decoration: const InputDecoration(
                    labelText: 'Nom (ex. FCB, CA1, BA1)',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
                ),
                // Le poids de la phase dans la moyenne générale de sa
                // promotion. Un stage ne se compose pas de phases : la
                // question ne s'y pose pas.
                if (type == ClasseType.phase) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: coefficientController,
                    decoration: const InputDecoration(
                      labelText: 'Coefficient de la phase',
                      helperText:
                          'Son poids dans la moyenne générale de la promotion.',
                      helperMaxLines: 2,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: _validerCoefficient,
                  ),
                ],
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
                if (!(formKey.currentState?.validate() ?? false) ||
                    divisionId == null) {
                  return;
                }
                try {
                  await ref
                      .read(classesRepositoryProvider)
                      .create(
                        divisionId: divisionId!,
                        type: type,
                        nom: nomController.text.trim(),
                        promotionId: promotionId,
                        coefficient: _lireCoefficient(coefficientController),
                      );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Erreur : ${messageErreur(e)}'),
                      backgroundColor: AppColors.danger,
                    ),
                  );
                  return;
                }
                ref.invalidate(classesListProvider);
                if (context.mounted) Navigator.of(context).pop();
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Phase / stage créé(e) avec succès.'),
                    backgroundColor: AppColors.success,
                  ),
                );
              },
              child: const Text('Créer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditClasseDialog(
    BuildContext context,
    WidgetRef ref,
    Classe classe,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final nomController = TextEditingController(text: classe.nom);
    final coefficientPhaseController = TextEditingController(
      text: _formaterCoefficient(classe.coefficient),
    );
    final formKey = GlobalKey<FormState>();
    ClasseType type = classe.type;
    // La promotion doit voyager avec le formulaire : sans elle, enregistrer
    // une phase la détachait de sa promotion, ce que la base refuse
    // (contrainte `classes_rattachement`) — et l'échec passait inaperçu.
    String? promotionId = classe.promotionId;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          scrollable: true,
          title: const Text('Modifier la classe / le stage'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<ClasseType>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: [
                    for (final t in ClasseType.values)
                      DropdownMenuItem(value: t, child: Text(t.label)),
                  ],
                  onChanged: (value) => setState(() => type = value!),
                ),
                // Une phase se range sous une promotion, un stage non : le
                // champ n'apparaît que dans le premier cas.
                if (type == ClasseType.phase) ...[
                  const SizedBox(height: 12),
                  Consumer(
                    builder: (context, ref, _) {
                      final promotions = ref.watch(
                        promotionsParDivisionProvider(classe.divisionId),
                      );
                      if (promotions.isEmpty) {
                        return const InputDecorator(
                          decoration: InputDecoration(labelText: 'Promotion'),
                          child: Text(
                            'Aucune promotion dans cette division — créez-en '
                            'une dans l\'onglet Promotions.',
                            style: TextStyle(
                              color: AppColors.inkMuted,
                              fontSize: 12.5,
                            ),
                          ),
                        );
                      }
                      return DropdownButtonFormField<String>(
                        initialValue: promotions.any((p) => p.id == promotionId)
                            ? promotionId
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Promotion',
                        ),
                        items: [
                          for (final p in promotions)
                            DropdownMenuItem(
                              value: p.id,
                              child: Text(p.intitule),
                            ),
                        ],
                        onChanged: (value) =>
                            setState(() => promotionId = value),
                        validator: (value) =>
                            value == null ? 'Champ requis' : null,
                      );
                    },
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: nomController,
                  decoration: const InputDecoration(labelText: 'Nom'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
                ),
                if (type == ClasseType.phase) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: coefficientPhaseController,
                    decoration: const InputDecoration(
                      labelText: 'Coefficient de la phase',
                      helperText:
                          'Son poids dans la moyenne générale de la promotion.',
                      helperMaxLines: 2,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: _validerCoefficient,
                  ),
                ],
                if (type != classe.type) ...[
                  const SizedBox(height: 12),
                  Text(
                    type == ClasseType.stage
                        ? 'En devenant un stage, cette phase quitte sa '
                              'promotion et perd son module Sport, séances '
                              'comprises.'
                        : 'En devenant une phase, ce stage reçoit un module '
                              'Sport.',
                    style: const TextStyle(
                      color: AppColors.inkMuted,
                      fontSize: 12.5,
                    ),
                  ),
                ],
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
                if (!(formKey.currentState?.validate() ?? false)) return;
                try {
                  await ref
                      .read(classesRepositoryProvider)
                      .update(
                        id: classe.id,
                        type: type,
                        nom: nomController.text.trim(),
                        promotionId: promotionId,
                        coefficient: _lireCoefficient(
                          coefficientPhaseController,
                        ),
                      );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Erreur : ${messageErreur(e)}'),
                      backgroundColor: AppColors.danger,
                    ),
                  );
                  return;
                }
                ref.invalidate(classesListProvider);
                if (context.mounted) Navigator.of(context).pop();
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Phase / stage modifié(e) avec succès.'),
                    backgroundColor: AppColors.success,
                  ),
                );
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteClasse(
    BuildContext context,
    WidgetRef ref,
    Classe classe,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Supprimer la classe'),
        content: Text(
          'Voulez-vous vraiment supprimer « ${classe.nom} » ? '
          'Ses affectations de matières seront également supprimées. Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Supprimer',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(classesRepositoryProvider).delete(classe.id);
      ref.invalidate(classesListProvider);
      ref.invalidate(matiereModulesProvider);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Classe supprimée avec succès.'),
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
}

class _AffectationsTab extends ConsumerWidget {
  const _AffectationsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modulesAsync = ref.watch(matiereModulesProvider);
    final matieresAsync = ref.watch(matieresCatalogueProvider);
    final classesAsync = ref.watch(classesListProvider);
    final divisionsAsync = ref.watch(divisionsProvider);
    final profile = ref.watch(currentProfileProvider).value;
    final canWrite =
        profile != null &&
        (profile.role == AppRole.admin || profile.role == AppRole.chefDivision);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Matières affectées aux classes',
          trailing: canWrite
              ? FilledButton.icon(
                  onPressed: () => _showAssociateDialog(
                    context,
                    ref,
                    matieres: matieresAsync.value ?? const [],
                    classes: classesAsync.value ?? const [],
                    divisions: divisionsAsync.value ?? const [],
                    profile: profile,
                  ),
                  icon: const Icon(Icons.add_link, size: 18),
                  label: const Text('Affecter'),
                )
              : null,
        ),
        const SizedBox(height: 16),
        Expanded(
          child: modulesAsync.when(
            data: (modules) {
              if (modules.isEmpty) {
                return const EmptyState(
                  message: 'Aucune matière affectée.',
                  icon: Icons.link_off,
                );
              }
              final matieresById = {
                for (final m in matieresAsync.value ?? <Matiere>[]) m.id: m,
              };
              final classesById = {
                for (final c in classesAsync.value ?? <Classe>[]) c.id: c,
              };
              final divisionsById = {
                for (final d in divisionsAsync.value ?? <Division>[]) d.id: d,
              };

              final modulesByClasse = <String, List<MatiereModule>>{};
              for (final module in modules) {
                modulesByClasse
                    .putIfAbsent(module.classeId, () => [])
                    .add(module);
              }
              final classeIds = modulesByClasse.keys.toList()
                ..sort(
                  (a, b) => (classesById[a]?.nom ?? '').toLowerCase().compareTo(
                    (classesById[b]?.nom ?? '').toLowerCase(),
                  ),
                );

              final items = <Widget>[];
              for (final classeId in classeIds) {
                final classe = classesById[classeId];
                final division = classe != null
                    ? divisionsById[classe.divisionId]
                    : null;
                final classeModules = modulesByClasse[classeId]!
                  ..sort(
                    (a, b) => (matieresById[a.matiereId]?.nom ?? '')
                        .toLowerCase()
                        .compareTo(
                          (matieresById[b.matiereId]?.nom ?? '').toLowerCase(),
                        ),
                  );
                if (items.isNotEmpty) items.add(const SizedBox(height: 20));
                items.add(
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '${classe?.nom ?? '—'}'
                      '${division != null ? ' · ${division.nom}' : ''}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
                for (final module in classeModules) {
                  final matiere = matieresById[module.matiereId];
                  items.add(
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        child: ListTile(
                          leading: const Icon(
                            Icons.link,
                            color: AppColors.blueDeep,
                          ),
                          title: Text(
                            matiere?.nom ?? '—',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              StatusChip(
                                label:
                                    'Coef. ${module.coefficient.toStringAsFixed(2)}',
                              ),
                              if (canWrite) ...[
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 20,
                                  ),
                                  tooltip: 'Modifier le coefficient',
                                  onPressed: () => _showEditCoefficientDialog(
                                    context,
                                    ref,
                                    module,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: AppColors.danger,
                                  ),
                                  onPressed: () async {
                                    await ref
                                        .read(matieresRepositoryProvider)
                                        .deleteModule(module.id);
                                    ref.invalidate(matiereModulesProvider);
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }
              }
              return ListView(children: items);
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

  Future<void> _showEditCoefficientDialog(
    BuildContext context,
    WidgetRef ref,
    MatiereModule module,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final coefficientController = TextEditingController(
      text: module.coefficient.toString(),
    );
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Modifier le coefficient'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: coefficientController,
            decoration: const InputDecoration(labelText: 'Coefficient'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            validator: (v) {
              final value = double.tryParse(v?.trim() ?? '');
              if (value == null || value <= 0) return 'Nombre positif requis';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () async {
              if (!(formKey.currentState?.validate() ?? false)) return;
              await ref
                  .read(matieresRepositoryProvider)
                  .updateModuleCoefficient(
                    id: module.id,
                    coefficient: double.parse(
                      coefficientController.text.trim(),
                    ),
                  );
              ref.invalidate(matiereModulesProvider);
              if (context.mounted) Navigator.of(context).pop();
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Coefficient modifié avec succès.'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAssociateDialog(
    BuildContext context,
    WidgetRef ref, {
    required List<Matiere> matieres,
    required List<Classe> classes,
    required List<Division> divisions,
    required Profile profile,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final coefficientController = TextEditingController(text: '1');
    final formKey = GlobalKey<FormState>();
    String? matiereId = matieres.isNotEmpty ? matieres.first.id : null;
    final isAdmin = profile.role == AppRole.admin;
    String? divisionId = isAdmin
        ? (divisions.isNotEmpty ? divisions.first.id : null)
        : profile.divisionId;
    String? classeId;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final classesForDivision = classes
              .where((c) => c.divisionId == divisionId)
              .toList();
          classeId ??= classesForDivision.isNotEmpty
              ? classesForDivision.first.id
              : null;

          return AlertDialog(
            scrollable: true,
            title: const Text('Affecter une matière'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: matiereId,
                    decoration: const InputDecoration(labelText: 'Matière'),
                    items: [
                      for (final m in matieres)
                        DropdownMenuItem(value: m.id, child: Text(m.nom)),
                    ],
                    onChanged: (value) => setState(() => matiereId = value),
                    validator: (value) => value == null ? 'Champ requis' : null,
                  ),
                  const SizedBox(height: 12),
                  if (isAdmin)
                    DropdownButtonFormField<String>(
                      initialValue: divisionId,
                      decoration: const InputDecoration(labelText: 'Division'),
                      items: [
                        for (final d in divisions)
                          DropdownMenuItem(value: d.id, child: Text(d.nom)),
                      ],
                      onChanged: (value) => setState(() {
                        divisionId = value;
                        classeId = null;
                      }),
                      validator: (value) =>
                          value == null ? 'Champ requis' : null,
                    )
                  else
                    InputDecorator(
                      decoration: const InputDecoration(labelText: 'Division'),
                      child: Text(_divisionNom(divisions, divisionId)),
                    ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: classeId,
                    decoration: const InputDecoration(labelText: 'Classe'),
                    items: [
                      for (final c in classesForDivision)
                        DropdownMenuItem(value: c.id, child: Text(c.nom)),
                    ],
                    onChanged: (value) => setState(() => classeId = value),
                    validator: (value) => value == null
                        ? 'Aucune classe pour cette division'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: coefficientController,
                    decoration: const InputDecoration(labelText: 'Coefficient'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (v) {
                      final value = double.tryParse(v?.trim() ?? '');
                      if (value == null || value <= 0) {
                        return 'Nombre positif requis';
                      }
                      return null;
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
                  if (!(formKey.currentState?.validate() ?? false) ||
                      divisionId == null ||
                      classeId == null) {
                    return;
                  }
                  await ref
                      .read(matieresRepositoryProvider)
                      .createModule(
                        matiereId: matiereId!,
                        divisionId: divisionId!,
                        classeId: classeId!,
                        coefficient: double.parse(
                          coefficientController.text.trim(),
                        ),
                      );
                  ref.invalidate(matiereModulesProvider);
                  if (context.mounted) Navigator.of(context).pop();
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Matière affectée avec succès.'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                },
                child: const Text('Affecter'),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Clôture d'une phase — ou sa réouverture si elle l'a été par erreur.
///
/// Clôturer fige la phase : plus aucune saisie. C'est aussi ce qui autorise
/// la promotion à recevoir sa phase suivante — et c'est en la créant que
/// les élèves y entrent. L'écran annonce les deux avant d'agir.
Future<void> _confirmerCloturePhase(
  BuildContext context,
  WidgetRef ref,
  Classe phase,
  int effectif,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final confirme = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      scrollable: true,
      title: Text('Clôturer ${phase.nom}'),
      content: Text(
        '${phase.nom} sera clôturée : plus aucune note, aucun cours ni '
        'aucune séance ne pourra y être saisi.\n\n'
        'La promotion pourra alors recevoir sa phase suivante — c\'est en '
        'la créant que ses $effectif élève(s) actif(s) y entreront. Les '
        'élèves radiés, suspendus ou diplômés ne montent pas.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Clôturer'),
        ),
      ],
    ),
  );
  if (confirme != true) return;

  try {
    await ref.read(classesRepositoryProvider).cloturerPhase(phase.id);
    ref.invalidate(classesListProvider);
    ref.invalidate(apprenantsListProvider);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          '${phase.nom} est clôturée. Créez la phase suivante pour y faire '
          'entrer les élèves.',
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
}

Future<void> _confirmerReouverturePhase(
  BuildContext context,
  WidgetRef ref,
  Classe phase,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final confirme = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      scrollable: true,
      title: Text('Rouvrir ${phase.nom}'),
      content: Text(
        '${phase.nom} redeviendra modifiable. Les élèves déjà passés à la '
        'phase suivante n\'y reviennent pas : leur affectation a pu être '
        'reprise depuis, la défaire d\'office serait pire que le mal.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Rouvrir'),
        ),
      ],
    ),
  );
  if (confirme != true) return;

  try {
    await ref.read(classesRepositoryProvider).rouvrirPhase(phase.id);
    ref.invalidate(classesListProvider);
    messenger.showSnackBar(
      SnackBar(
        content: Text('${phase.nom} est rouverte.'),
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

/// Le coefficient d'une phase : un nombre strictement positif, saisi avec une
/// virgule ou un point selon l'habitude de chacun.
String? _validerCoefficient(String? valeur) {
  final nombre = num.tryParse((valeur ?? '').trim().replaceAll(',', '.'));
  if (nombre == null) return 'Saisissez un nombre';
  if (nombre <= 0) return 'Le coefficient doit être supérieur à zéro';
  return null;
}

num _lireCoefficient(TextEditingController controleur) =>
    num.tryParse(controleur.text.trim().replaceAll(',', '.')) ?? 1;

/// « 2 » plutôt que « 2.0 » : un coefficient entier s'écrit sans décimale.
String _formaterCoefficient(num valeur) =>
    valeur == valeur.roundToDouble() ? valeur.round().toString() : '$valeur';
