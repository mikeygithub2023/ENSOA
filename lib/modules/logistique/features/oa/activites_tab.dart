import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:sig_ensoa/core/theme.dart';
import 'package:sig_ensoa/core/chargement.dart';
import '../../data/models/oa.dart';
import '../../data/repositories/oa_providers.dart';
import '../../shared/widgets/skeleton.dart';
import '../../shared/widgets/widgets.dart';

class ActivitesTabContent extends ConsumerStatefulWidget {
  const ActivitesTabContent({super.key});

  @override
  ConsumerState<ActivitesTabContent> createState() =>
      _ActivitesTabContentState();
}

class _ActivitesTabContentState extends ConsumerState<ActivitesTabContent> {
  StatutActivite? _filtre;

  AlertLevel _levelPour(StatutActivite s) {
    switch (s) {
      case StatutActivite.planifiee:
        return AlertLevel.info;
      case StatutActivite.enCours:
        return AlertLevel.warning;
      case StatutActivite.terminee:
        return AlertLevel.info;
      case StatutActivite.annulee:
        return AlertLevel.critical;
    }
  }

  @override
  Widget build(BuildContext context) {
    final charge = estCharge(ref, ['activites', 'taches']);
    final activites = ref.watch(activitesProvider);
    final taches = ref.watch(tachesProvider);
    final df = DateFormat('dd/MM/yyyy HH:mm');
    final filtrees = _filtre == null
        ? activites
        : activites.where((a) => a.statut == _filtre).toList();

    if (!charge) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(4, 4, 4, 100),
        child: SkeletonList(itemCount: 4),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 100),
      children: [
        Wrap(
          spacing: 8,
          children: [
            FilterChipPill(
              label: 'Toutes',
              selected: _filtre == null,
              onTap: () => setState(() => _filtre = null),
            ),
            for (final s in StatutActivite.values)
              FilterChipPill(
                label: s.label,
                selected: _filtre == s,
                onTap: () => setState(() => _filtre = s),
              ),
          ],
        ),
        const SizedBox(height: 16),
        SectionHeader(title: 'Activités (${filtrees.length})'),
        if (filtrees.isEmpty)
          const EmptyState(message: 'Aucune activité pour ce filtre'),
        for (final a in filtrees) ...[
          Builder(
            builder: (context) {
              final tachesActivite = taches
                  .where((t) => t.activiteId == a.id)
                  .toList();
              final validees = tachesActivite
                  .where((t) => t.statut == StatutTache.validee)
                  .length;
              return Card(
                child: ListTile(
                  onTap: () =>
                      context.go('/logistique/activites/detail', extra: a),
                  leading: CircleAvatar(
                    backgroundColor: AppColors.blueMist,
                    child: Icon(
                      Icons.event_note_outlined,
                      color: AppColors.navy,
                    ),
                  ),
                  title: Text(a.titre),
                  subtitle: Text(
                    '${df.format(a.dateActivite)}${a.lieu != null ? ' · ${a.lieu}' : ''}'
                    '${tachesActivite.isNotEmpty ? ' · $validees/${tachesActivite.length} tâches validées' : ' · Aucune tâche assignée'}',
                  ),
                  trailing: StatusChip(
                    label: a.statut.label,
                    level: _levelPour(a.statut),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}
