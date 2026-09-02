import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:sig_ensoa/core/erreurs.dart';
import 'package:sig_ensoa/core/theme.dart' hide AlertLevel, AlertLevelColor;
import '../../models/apprenant.dart';
import '../../models/classe.dart';
import '../../models/division.dart';
import '../../models/permission.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/pdf_preview_dialog.dart';
import '../matieres/providers/matieres_providers.dart';
import 'pdf_fonts.dart';
import 'permissions_pdf.dart';
import 'portee_promotion.dart';
import 'providers/apprenants_providers.dart';
import 'providers/permissions_providers.dart';
import 'register_permission_dialog.dart';

class PermissionsTabView extends ConsumerStatefulWidget {
  const PermissionsTabView({
    super.key,
    required this.division,
    required this.classe,
    this.classesRetenues,
  });

  final Division division;
  final Classe? classe;

  /// Phases d'une promotion sélectionnée sans phase précise, nul sinon.
  final Set<String>? classesRetenues;

  @override
  ConsumerState<PermissionsTabView> createState() => _PermissionsTabViewState();
}

class _PermissionsTabViewState extends ConsumerState<PermissionsTabView> {
  final Set<String> _selectedIds = {};
  bool _printing = false;

  Division get _division => widget.division;
  Classe? get _classe => widget.classe;

  Future<void> _print({
    required List<Permission> permissions,
    required Map<String, Apprenant> apprenantsById,
    required Map<String, Classe> classesById,
  }) async {
    if (permissions.isEmpty || _printing) return;
    setState(() => _printing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final armoiries = (await rootBundle.load(
        'assets/images/armoiries_ci.png',
      )).buffer.asUint8List();
      final items = <PermissionPrintData>[];
      for (final permission in permissions) {
        final apprenant = apprenantsById[permission.apprenantId];
        final classe = _classe ?? classesById[permission.classeId];
        if (apprenant == null || classe == null) continue;
        items.add(
          PermissionPrintData(
            permission: permission,
            apprenant: apprenant,
            classe: classe,
            division: _division,
          ),
        );
      }
      if (items.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Aucune permission imprimable (données manquantes).'),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }
      final doc = buildPermissionsPdf(
        items,
        armoiries: armoiries,
        theme: await chargerThemePdf(),
      );
      final bytes = await doc.save();
      if (!mounted) return;
      await showPdfPreviewDialog(context, bytes);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Erreur : ${messageErreur(e)}'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final classe = _classe;
    final portee = classe == null ? widget.classesRetenues : null;
    final apprenantsAsync =
        (classe != null
                ? ref.watch(apprenantsByClasseProvider(classe.id))
                : ref.watch(apprenantsByDivisionProvider(_division.id)))
            .dansLesClasses(portee, (a) => a.classeId);
    final permissionsAsync =
        (classe != null
                ? ref.watch(permissionsByClasseProvider(classe.id))
                : ref.watch(permissionsByDivisionProvider(_division.id)))
            .dansLesClasses(portee, (p) => p.classeId);
    final classesAsync = ref.watch(classesListProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: SectionHeader(title: 'Permissions')),
            permissionsAsync.maybeWhen(
              data: (permissions) => OutlinedButton.icon(
                onPressed: permissions.isEmpty || _printing
                    ? null
                    : () => _print(
                        permissions: permissions,
                        apprenantsById: {
                          for (final a
                              in apprenantsAsync.value ?? const <Apprenant>[])
                            a.id: a,
                        },
                        classesById: {
                          for (final c
                              in classesAsync.value ?? const <Classe>[])
                            c.id: c,
                        },
                      ),
                icon: const Icon(Icons.print_outlined, size: 18),
                label: const Text('Imprimer la liste'),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
            const SizedBox(width: 8),
            permissionsAsync.maybeWhen(
              data: (permissions) {
                final selected = permissions
                    .where((p) => _selectedIds.contains(p.id))
                    .toList();
                return OutlinedButton.icon(
                  onPressed: selected.isEmpty || _printing
                      ? null
                      : () => _print(
                          permissions: selected,
                          apprenantsById: {
                            for (final a
                                in apprenantsAsync.value ?? const <Apprenant>[])
                              a.id: a,
                          },
                          classesById: {
                            for (final c
                                in classesAsync.value ?? const <Classe>[])
                              c.id: c,
                          },
                        ),
                  icon: const Icon(Icons.checklist_outlined, size: 18),
                  label: Text(
                    _selectedIds.isEmpty
                        ? 'Imprimer la sélection'
                        : 'Imprimer la sélection (${_selectedIds.length})',
                  ),
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),
            if (classe != null) ...[
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: apprenantsAsync.maybeWhen(
                  data: (apprenants) => apprenants.isEmpty
                      ? null
                      : () => showRegisterPermissionDialog(
                          context,
                          division: _division,
                          classe: classe,
                          apprenants: apprenants,
                        ),
                  orElse: () => null,
                ),
                icon: const Icon(Icons.assignment_add, size: 18),
                label: const Text('Enregistrer une permission'),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: apprenantsAsync.when(
            data: (apprenants) {
              final apprenantsById = {for (final a in apprenants) a.id: a};
              final classesById = {
                for (final c in classesAsync.value ?? const <Classe>[]) c.id: c,
              };
              return permissionsAsync.when(
                data: (permissions) {
                  if (permissions.isEmpty) {
                    return EmptyState(
                      message: classe != null
                          ? 'Aucune permission enregistrée pour cette phase ou ce stage.'
                          : 'Aucune permission enregistrée pour cette division.',
                      icon: Icons.assignment_turned_in_outlined,
                    );
                  }
                  return ListView.separated(
                    itemCount: permissions.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final permission = permissions[index];
                      return _PermissionTile(
                        permission: permission,
                        apprenant: apprenantsById[permission.apprenantId],
                        classeNom: classe == null
                            ? classesById[permission.classeId]?.nom
                            : null,
                        selected: _selectedIds.contains(permission.id),
                        onSelectedChanged: (value) => setState(() {
                          if (value ?? false) {
                            _selectedIds.add(permission.id);
                          } else {
                            _selectedIds.remove(permission.id);
                          }
                        }),
                        // Sous « toutes phases », la classe vient du
                        // référentiel plutôt que de la portée affichée. Si
                        // ni l'une ni l'autre ne la donne, le bouton reste
                        // fermé : mieux vaut cela qu'un écran qui se ferme
                        // sur une erreur.
                        onModifier: () {
                          final laClasse =
                              classesById[permission.classeId] ?? classe;
                          if (laClasse == null) return;
                          showRegisterPermissionDialog(
                            context,
                            division: widget.division,
                            classe: laClasse,
                            apprenants: apprenantsAsync.value ?? const [],
                            existante: permission,
                          );
                        },
                        onDelete: () =>
                            _confirmDelete(context, ref, permission),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => EmptyState(
                  message: 'Erreur de chargement : ${messageErreur(error)}',
                  icon: Icons.error_outline,
                ),
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

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Permission permission,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Supprimer la permission'),
        content: const Text(
          'Voulez-vous vraiment supprimer cette permission ?',
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
      await ref
          .read(permissionsRepositoryProvider)
          .deletePermission(permission.id);
      ref.invalidate(permissionsByClasseProvider(permission.classeId));
      ref.invalidate(permissionsByDivisionProvider(permission.divisionId));
      ref.invalidate(permissionsByApprenantProvider(permission.apprenantId));
      setState(() => _selectedIds.remove(permission.id));
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Permission supprimée.'),
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

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.permission,
    required this.apprenant,
    required this.onModifier,
    required this.onDelete,
    required this.selected,
    required this.onSelectedChanged,
    this.classeNom,
  });

  final Permission permission;
  final Apprenant? apprenant;
  final String? classeNom;
  final bool selected;
  final ValueChanged<bool?> onSelectedChanged;
  final VoidCallback onModifier;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');
    final statut = permission.statut;
    final level = switch (statut) {
      PermissionStatut.aVenir => AlertLevel.info,
      PermissionStatut.enCours => AlertLevel.success,
      PermissionStatut.terminee => AlertLevel.warning,
    };

    return Material(
      color: AppColors.blueMist,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Checkbox(value: selected, onChanged: onSelectedChanged),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${apprenant?.nomComplet ?? 'Apprenant inconnu'}'
                    '${classeNom != null ? ' · $classeNom' : ''}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${fmt.format(permission.dateDepart)} → ${fmt.format(permission.dateRetour)}'
                    '${permission.localite != null ? ' · ${permission.localite}' : ''}'
                    '${permission.motif != null ? ' · ${permission.motif}' : ''}',
                    style: const TextStyle(
                      color: AppColors.inkMuted,
                      fontSize: 13,
                    ),
                  ),
                  if (permission.personneContact != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Personne à prévenir : ${permission.personneContact}',
                      style: const TextStyle(
                        color: AppColors.inkMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 16),
            StatusChip(label: statut.label, level: level),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: onModifier,
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
        ),
      ),
    );
  }
}
