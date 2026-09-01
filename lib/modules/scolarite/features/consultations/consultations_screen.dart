import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/classe.dart';
import '../../models/division.dart';
import '../../shared/widgets/common.dart';
import '../apprenants/consultations_medicales_tab_view.dart';
import '../matieres/providers/matieres_providers.dart';

/// Point d'entrée direct du médecin vers les consultations médicales
/// (urgence et routine), sans passer par l'effectif Élèves & Stagiaires —
/// le médecin choisit juste une division (puis, en option, une classe/stage
/// précis(e)) pour voir/créer/traiter les consultations.
class ConsultationsScreen extends ConsumerStatefulWidget {
  const ConsultationsScreen({super.key});

  @override
  ConsumerState<ConsultationsScreen> createState() =>
      _ConsultationsScreenState();
}

class _ConsultationsScreenState extends ConsumerState<ConsultationsScreen> {
  String? _divisionFilter;
  String? _classeFilter;

  @override
  Widget build(BuildContext context) {
    final divisionsAsync = ref.watch(divisionsProvider);
    final classesAsync = ref.watch(classesListProvider);

    final classesForDivision = _divisionFilter == null
        ? const <Classe>[]
        : (classesAsync.value ?? const <Classe>[])
              .where((c) => c.divisionId == _divisionFilter)
              .toList();

    final selectedDivision = _divisionFilter == null
        ? null
        : _findById(
            divisionsAsync.value ?? const <Division>[],
            _divisionFilter,
            (d) => d.id,
          );
    final selectedClasse = _classeFilter == null
        ? null
        : _findById(classesForDivision, _classeFilter, (c) => c.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Consultations médicales'),
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
          child: selectedDivision == null
              ? const EmptyState(
                  message:
                      'Sélectionnez une division pour voir ses consultations médicales.',
                  icon: Icons.medical_services_outlined,
                )
              : ConsultationsMedicalesTabView(
                  division: selectedDivision,
                  classe: selectedClasse,
                ),
        ),
      ],
    );
  }
}

T? _findById<T>(List<T> items, String? id, String Function(T) idOf) {
  for (final item in items) {
    if (idOf(item) == id) return item;
  }
  return null;
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
