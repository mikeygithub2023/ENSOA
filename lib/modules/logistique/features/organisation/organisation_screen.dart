import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sig_ensoa/core/chargement.dart';
import 'package:sig_ensoa/core/theme.dart';

import '../../data/models/organisation.dart';
import '../../data/models/personnel.dart';
import '../../data/repositories/organisation_providers.dart';
import '../../shared/widgets/skeleton.dart';
import '../../shared/widgets/widgets.dart';

/// Le référentiel de l'organisation : le personnel militaire, les services et
/// leurs cellules.
///
/// Le personnel n'est pas la liste des comptes. Un militaire qui perçoit du
/// carburant n'a pas forcément de compte dans l'application, et un compte
/// n'est pas forcément rattaché à une fiche. Les deux listes se ressemblent,
/// elles ne se recouvrent pas.
class OrganisationScreen extends ConsumerWidget {
  const OrganisationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TabBar(
            isScrollable: true,
            labelColor: AppColors.navy,
            unselectedLabelColor: AppColors.inkMuted,
            indicatorColor: AppColors.navy,
            tabs: [
              Tab(text: 'Personnel'),
              Tab(text: 'Services'),
              Tab(text: 'Cellules'),
            ],
          ),
          const SizedBox(height: 16),
          const Expanded(
            child: TabBarView(
              children: [_PersonnelTab(), _ServicesTab(), _CellulesTab()],
            ),
          ),
        ],
      ),
    );
  }
}

// --- Personnel ---------------------------------------------------------------

class _PersonnelTab extends ConsumerWidget {
  const _PersonnelTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final charge = estCharge(ref, ['personnel']);
    final personnel = ref.watch(personnelProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Personnel militaire (${charge ? personnel.length : '…'})',
          action: FilledButton.icon(
            onPressed: () => _ouvrirFiche(context, ref),
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
            label: const Text('Ajouter'),
          ),
        ),
        Expanded(
          child: !charge
              ? const SkeletonList(itemCount: 4)
              : personnel.isEmpty
              ? const EmptyState(
                  message:
                      'Aucun militaire enregistré. Ce sont eux qui figureront '
                      'comme bénéficiaires des distributions de carburant.',
                  icon: Icons.groups_outlined,
                )
              : ListView.separated(
                  itemCount: personnel.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final p = personnel[i];
                    final actif = p.statutActuel.toLowerCase() == 'actif';
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              (actif ? AppColors.success : AppColors.inkMuted)
                                  .withValues(alpha: 0.12),
                          child: Icon(
                            Icons.person_outline,
                            color: actif
                                ? AppColors.success
                                : AppColors.inkMuted,
                          ),
                        ),
                        title: Text(
                          [
                            ?p.grade,
                            p.nomComplet,
                          ].join(' ').trim(),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${p.matricule}'
                          '${p.contact != null && p.contact!.isNotEmpty ? ' · ${p.contact}' : ''}'
                          '${actif ? '' : ' · ${p.statutActuel}'}',
                        ),
                        trailing: Wrap(
                          spacing: 4,
                          children: [
                            IconButton(
                              tooltip: 'Modifier',
                              onPressed: () =>
                                  _ouvrirFiche(context, ref, existant: p),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              tooltip: 'Supprimer',
                              onPressed: () => _supprimer(context, ref, p),
                              icon: const Icon(
                                Icons.delete_outline,
                                color: AppColors.danger,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _supprimer(
    BuildContext context,
    WidgetRef ref,
    Personnel p,
  ) async {
    final messager = ScaffoldMessenger.of(context);
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Supprimer la fiche'),
        content: Text(
          'La fiche de ${p.nomComplet} sera supprimée. '
          "S'il a quitté l'école, changez plutôt son statut : une distribution "
          'déjà enregistrée le désigne, et la base refusera de l\'effacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirme != true) return;
    try {
      await ref.read(personnelProvider.notifier).supprimer(p.id);
    } catch (e) {
      messager.showSnackBar(
        SnackBar(content: Text('Suppression impossible : $e')),
      );
    }
  }

  Future<void> _ouvrirFiche(
    BuildContext context,
    WidgetRef ref, {
    Personnel? existant,
  }) async {
    final formKey = GlobalKey<FormState>();
    final nom = TextEditingController(text: existant?.nom ?? '');
    final prenom = TextEditingController(text: existant?.prenom ?? '');
    final matricule = TextEditingController(text: existant?.matricule ?? '');
    final grade = TextEditingController(text: existant?.grade ?? '');
    final contact = TextEditingController(text: existant?.contact ?? '');
    var statut = existant?.statutActuel ?? 'Actif';
    final messager = ScaffoldMessenger.of(context);

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          scrollable: true,
          title: Text(existant == null ? 'Nouveau militaire' : 'Modifier'),
          content: SizedBox(
            width: 440,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: grade,
                            decoration: const InputDecoration(
                              labelText: 'Grade (facultatif)',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: prenom,
                            decoration: const InputDecoration(
                              labelText: 'Prénom',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: nom,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(labelText: 'Nom'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Champ requis'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: matricule,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Matricule',
                        helperText: 'Unique : la base refuse les doublons.',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Champ requis'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: contact,
                      decoration: const InputDecoration(
                        labelText: 'Contact (facultatif)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: statut,
                      decoration: const InputDecoration(labelText: 'Statut'),
                      items: const [
                        DropdownMenuItem(value: 'Actif', child: Text('Actif')),
                        DropdownMenuItem(value: 'Muté', child: Text('Muté')),
                        DropdownMenuItem(
                          value: 'Retraité',
                          child: Text('Retraité'),
                        ),
                        DropdownMenuItem(
                          value: 'Indisponible',
                          child: Text('Indisponible'),
                        ),
                      ],
                      onChanged: (v) => setState(() => statut = v ?? 'Actif'),
                    ),
                  ],
                ),
              ),
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
                final notifier = ref.read(personnelProvider.notifier);
                try {
                  if (existant == null) {
                    await notifier.creer(
                      nom: nom.text.trim(),
                      prenom: prenom.text.trim(),
                      matricule: matricule.text.trim(),
                      grade: grade.text.trim().isEmpty
                          ? null
                          : grade.text.trim(),
                      contact: contact.text.trim().isEmpty
                          ? null
                          : contact.text.trim(),
                      statutActuel: statut,
                    );
                  } else {
                    await notifier.modifier(
                      id: existant.id,
                      nom: nom.text.trim(),
                      prenom: prenom.text.trim(),
                      matricule: matricule.text.trim(),
                      grade: grade.text.trim().isEmpty
                          ? null
                          : grade.text.trim(),
                      contact: contact.text.trim().isEmpty
                          ? null
                          : contact.text.trim(),
                      statutActuel: statut,
                    );
                  }
                } catch (e) {
                  messager.showSnackBar(
                    SnackBar(content: Text('Enregistrement impossible : $e')),
                  );
                  return;
                }
                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Services ----------------------------------------------------------------

class _ServicesTab extends ConsumerWidget {
  const _ServicesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final charge = estCharge(ref, ['services']);
    final services = ref.watch(servicesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Services (${charge ? services.length : '…'})',
          action: FilledButton.icon(
            onPressed: () => _saisir(context, ref),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Ajouter'),
          ),
        ),
        Expanded(
          child: !charge
              ? const SkeletonList(itemCount: 2)
              : services.isEmpty
              ? const EmptyState(message: 'Aucun service enregistré')
              : ListView.separated(
                  itemCount: services.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final s = services[i];
                    return Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.account_tree_outlined,
                          color: AppColors.blueDeep,
                        ),
                        title: Text(s.libelle),
                        trailing: Wrap(
                          spacing: 4,
                          children: [
                            IconButton(
                              tooltip: 'Renommer',
                              onPressed: () =>
                                  _saisir(context, ref, existant: s),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              tooltip: 'Supprimer',
                              onPressed: () async {
                                final messager = ScaffoldMessenger.of(context);
                                try {
                                  await ref
                                      .read(servicesProvider.notifier)
                                      .supprimer(s.id);
                                } catch (e) {
                                  messager.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Suppression impossible : $e',
                                      ),
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(
                                Icons.delete_outline,
                                color: AppColors.danger,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _saisir(
    BuildContext context,
    WidgetRef ref, {
    Service? existant,
  }) async {
    final controleur = TextEditingController(text: existant?.libelle ?? '');
    final messager = ScaffoldMessenger.of(context);

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(existant == null ? 'Nouveau service' : 'Renommer'),
        content: TextField(
          controller: controleur,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Libellé'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () async {
              final libelle = controleur.text.trim();
              if (libelle.isEmpty) return;
              final notifier = ref.read(servicesProvider.notifier);
              try {
                if (existant == null) {
                  await notifier.creer(libelle);
                } else {
                  await notifier.renommer(existant.id, libelle);
                }
              } catch (e) {
                messager.showSnackBar(
                  SnackBar(content: Text('Enregistrement impossible : $e')),
                );
                return;
              }
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }
}

// --- Cellules ----------------------------------------------------------------

class _CellulesTab extends ConsumerWidget {
  const _CellulesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final charge = estCharge(ref, ['cellules', 'services']);
    final cellules = ref.watch(cellulesProvider);
    final services = ref.watch(servicesProvider);
    final nomDuService = {for (final s in services) s.id: s.libelle};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Cellules (${charge ? cellules.length : '…'})',
          action: FilledButton.icon(
            onPressed: services.isEmpty
                ? null
                : () => _saisir(context, ref, services),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Ajouter'),
          ),
        ),
        Expanded(
          child: !charge
              ? const SkeletonList(itemCount: 3)
              : cellules.isEmpty
              ? const EmptyState(
                  message:
                      'Aucune cellule enregistrée. Créez d\'abord un service, '
                      'puis ses cellules.',
                )
              : ListView.separated(
                  itemCount: cellules.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final c = cellules[i];
                    return Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.workspaces_outline,
                          color: AppColors.blueDeep,
                        ),
                        title: Text(c.libelle),
                        subtitle: Text(
                          nomDuService[c.serviceId] ?? 'Service inconnu',
                        ),
                        trailing: Wrap(
                          spacing: 4,
                          children: [
                            IconButton(
                              tooltip: 'Modifier',
                              onPressed: () =>
                                  _saisir(context, ref, services, existant: c),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              tooltip: 'Supprimer',
                              onPressed: () async {
                                final messager = ScaffoldMessenger.of(context);
                                try {
                                  await ref
                                      .read(cellulesProvider.notifier)
                                      .supprimer(c.id);
                                } catch (e) {
                                  messager.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Suppression impossible : $e',
                                      ),
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(
                                Icons.delete_outline,
                                color: AppColors.danger,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _saisir(
    BuildContext context,
    WidgetRef ref,
    List<Service> services, {
    Cellule? existant,
  }) async {
    final controleur = TextEditingController(text: existant?.libelle ?? '');
    var serviceId = existant?.serviceId ?? services.first.id;
    final messager = ScaffoldMessenger.of(context);

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          scrollable: true,
          title: Text(existant == null ? 'Nouvelle cellule' : 'Modifier'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: services.any((s) => s.id == serviceId)
                      ? serviceId
                      : services.first.id,
                  decoration: const InputDecoration(labelText: 'Service'),
                  items: [
                    for (final s in services)
                      DropdownMenuItem(value: s.id, child: Text(s.libelle)),
                  ],
                  onChanged: (v) =>
                      setState(() => serviceId = v ?? serviceId),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controleur,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Libellé'),
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
                final libelle = controleur.text.trim();
                if (libelle.isEmpty) return;
                final notifier = ref.read(cellulesProvider.notifier);
                try {
                  if (existant == null) {
                    await notifier.creer(
                      libelle: libelle,
                      serviceId: serviceId,
                    );
                  } else {
                    await notifier.modifier(
                      id: existant.id,
                      libelle: libelle,
                      serviceId: serviceId,
                    );
                  }
                } catch (e) {
                  messager.showSnackBar(
                    SnackBar(content: Text('Enregistrement impossible : $e')),
                  );
                  return;
                }
                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}
