import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:sig_ensoa/core/erreurs.dart';
import 'package:sig_ensoa/core/theme.dart' hide AlertLevel, AlertLevelColor;
import '../../models/classe.dart';
import '../../models/division.dart';
import '../../models/visite_medicale.dart';
import '../../shared/widgets/common.dart';
import '../matieres/providers/matieres_providers.dart';
import 'providers/visites_medicales_providers.dart';
import 'register_visite_medicale_dialog.dart';

final _dateFmt = DateFormat('dd/MM/yyyy');

/// Visites médicales de l'ENSOA — écran réservé au médecin. Une visite est
/// une campagne : elle est d'abord créée (titre, classe/stage convoquée,
/// date, type), puis on l'ouvre pour y enregistrer, un à un, les apprenants
/// qui l'ont passée et leur examen.
class VisitesMedicalesScreen extends ConsumerStatefulWidget {
  const VisitesMedicalesScreen({super.key});

  @override
  ConsumerState<VisitesMedicalesScreen> createState() =>
      _VisitesMedicalesScreenState();
}

class _VisitesMedicalesScreenState
    extends ConsumerState<VisitesMedicalesScreen> {
  String? _divisionFilter;
  String? _classeFilter;

  @override
  Widget build(BuildContext context) {
    final visitesAsync = ref.watch(visitesMedicalesProvider);
    final divisionsAsync = ref.watch(divisionsProvider);
    final classesAsync = ref.watch(classesListProvider);
    final effectifs = ref.watch(visitesEffectifsProvider).value ?? const {};

    final classes = classesAsync.value ?? const <Classe>[];
    final classesById = {for (final c in classes) c.id: c};
    final classesForDivision = _divisionFilter == null
        ? const <Classe>[]
        : classes.where((c) => c.divisionId == _divisionFilter).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Visites médicales',
          trailing: FilledButton.icon(
            onPressed: classes.isEmpty
                ? null
                : () => showRegisterVisiteMedicaleDialog(
                    context,
                    classes: classes,
                  ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Nouvelle visite'),
          ),
        ),
        const SizedBox(height: 16),
        divisionsAsync.when(
          data: (divisions) => _DivisionFilters(
            divisions: divisions,
            selected: _divisionFilter,
            onSelect: (id) => setState(() {
              _divisionFilter = id;
              _classeFilter = null;
            }),
          ),
          loading: () => const SizedBox(height: 40),
          error: (_, _) => const SizedBox.shrink(),
        ),
        if (_divisionFilter != null && classesForDivision.isNotEmpty) ...[
          const SizedBox(height: 12),
          _ClasseFilters(
            classes: classesForDivision,
            selected: _classeFilter,
            onSelect: (id) => setState(() => _classeFilter = id),
          ),
        ],
        const SizedBox(height: 16),
        Expanded(
          child: visitesAsync.when(
            data: (visites) {
              final filtrees = visites.where((v) {
                if (_divisionFilter != null &&
                    v.divisionId != _divisionFilter) {
                  return false;
                }
                return _classeFilter == null || v.classeId == _classeFilter;
              }).toList();
              if (filtrees.isEmpty) {
                return const EmptyState(
                  message: 'Aucune visite médicale enregistrée.',
                  icon: Icons.event_available_outlined,
                );
              }
              return ListView.separated(
                itemCount: filtrees.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final visite = filtrees[index];
                  return _VisiteTile(
                    visite: visite,
                    classe: classesById[visite.classeId],
                    effectif: effectifs[visite.id] ?? 0,
                    onOpen: () =>
                        context.push('/scolarite/visites-medicales/${visite.id}'),
                    onDelete: () => _confirmDelete(context, visite),
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

  Future<void> _confirmDelete(
    BuildContext context,
    VisiteMedicale visite,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Supprimer la visite médicale'),
        content: Text(
          'Voulez-vous vraiment supprimer « ${visite.titre} » ? Les examens des apprenants qui l\'ont passée seront également supprimés.',
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
      await ref
          .read(visitesMedicalesRepositoryProvider)
          .deleteVisite(visite.id);
      ref.invalidate(visitesMedicalesProvider);
      ref.invalidate(visitesEffectifsProvider);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Visite médicale supprimée.'),
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

class _DivisionFilters extends StatelessWidget {
  const _DivisionFilters({
    required this.divisions,
    required this.selected,
    required this.onSelect,
  });

  final List<Division> divisions;
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilterChipPill(
          label: 'Toutes divisions',
          selected: selected == null,
          onTap: () => onSelect(null),
        ),
        for (final division in divisions)
          FilterChipPill(
            label: division.nom,
            selected: selected == division.id,
            onTap: () => onSelect(division.id),
          ),
      ],
    );
  }
}

class _ClasseFilters extends StatelessWidget {
  const _ClasseFilters({
    required this.classes,
    required this.selected,
    required this.onSelect,
  });

  final List<Classe> classes;
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilterChipPill(
          label: 'Toutes phases / stages',
          selected: selected == null,
          onTap: () => onSelect(null),
        ),
        for (final classe in classes)
          FilterChipPill(
            label: '${classe.nom} (${classe.type.label})',
            selected: selected == classe.id,
            onTap: () => onSelect(classe.id),
          ),
      ],
    );
  }
}

class _VisiteTile extends StatelessWidget {
  const _VisiteTile({
    required this.visite,
    required this.classe,
    required this.effectif,
    required this.onOpen,
    required this.onDelete,
  });

  final VisiteMedicale visite;
  final Classe? classe;
  final int effectif;
  final VoidCallback onOpen;
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
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      visite.titre,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${visite.type.label} · '
                      '${classe != null ? '${classe!.nom} (${classe!.type.label}) · ' : ''}'
                      '${_dateFmt.format(visite.dateVisite)}',
                      style: const TextStyle(
                        color: AppColors.inkMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              StatusChip(
                label: effectif > 1
                    ? '$effectif apprenants'
                    : '$effectif apprenant',
                level: effectif == 0 ? AlertLevel.warning : AlertLevel.info,
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: AppColors.danger,
                ),
                tooltip: 'Supprimer',
                onPressed: onDelete,
              ),
              const Icon(Icons.chevron_right, color: AppColors.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}
