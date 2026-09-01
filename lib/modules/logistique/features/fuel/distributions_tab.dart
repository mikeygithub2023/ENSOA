import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:sig_ensoa/core/theme.dart';
import 'package:sig_ensoa/core/chargement.dart';
import 'package:sig_ensoa/core/format.dart';
import '../../data/repositories/fuel_providers.dart';
import '../../data/repositories/misc_providers.dart';
import '../../shared/widgets/skeleton.dart';
import '../../shared/widgets/widgets.dart';
import 'distribution_pdf.dart';

/// Contenu de l'onglet "Distributions" — journal des remises de carburant,
/// filtrable par soute et par plage de dates.
class DistributionsTabContent extends ConsumerStatefulWidget {
  const DistributionsTabContent({super.key});

  @override
  ConsumerState<DistributionsTabContent> createState() =>
      _DistributionsTabContentState();
}

class _DistributionsTabContentState
    extends ConsumerState<DistributionsTabContent> {
  String? _souteFiltre; // libellé de soute, ou null = toutes
  DateTimeRange? _periode;
  bool _impressionEnCours = false;

  Future<void> _imprimer(List<DistributionVue> lignes) async {
    setState(() => _impressionEnCours = true);
    try {
      // Le référentiel des comptes se charge tout seul, mais de façon
      // différée : au tout premier passage, il est encore vide quand on le
      // lit. L'imprimé sortait alors sans aucun nom de soutier — une colonne
      // entière de tirets. On l'attend plutôt que d'imprimer un document
      // faux.
      if (ref.read(usersProvider).isEmpty) {
        await ref.read(usersProvider.notifier).refresh();
      }
      final users = ref.read(usersProvider);
      final dfTitre = DateFormat('dd/MM/yyyy');
      String sousTitre;
      if (_periode != null) {
        sousTitre =
            'DISTRIBUTION DE CARBURANT DU ${dfTitre.format(_periode!.start)} AU ${dfTitre.format(_periode!.end)}';
      } else if (lignes.isNotEmpty) {
        final dates = lignes.map((v) => v.distribution.date).toList()..sort();
        sousTitre =
            'DISTRIBUTION DE CARBURANT DU ${dfTitre.format(dates.first)} AU ${dfTitre.format(dates.last)}';
      } else {
        sousTitre = 'DISTRIBUTION DE CARBURANT DE ${DateTime.now().year}';
      }
      await imprimerEtatDistributions(
        souteLibelle: _souteFiltre,
        sousTitre: sousTitre,
        lignes: lignes,
        resoudreSoutier: (id) => findUser(users, id),
      );
    } finally {
      if (mounted) setState(() => _impressionEnCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final charge = estCharge(ref, ['distributions', 'soutes', 'soute_stocks']);
    final soutes = ref.watch(soutesProvider);
    // Suivi ici pour qu'il commence à se charger avec l'écran : c'est lui qui
    // nomme le soutier sur l'imprimé.
    ref.watch(usersProvider);
    final distributions = ref.watch(distributionsAvecLibellesProvider);
    final df = DateFormat('dd/MM/yyyy HH:mm');

    if (!charge) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(4, 4, 4, 100),
        child: SkeletonList(itemCount: 4),
      );
    }

    final filtrees = distributions.where((v) {
      if (_souteFiltre != null && v.souteLibelle != _souteFiltre) return false;
      if (_periode != null) {
        final d = v.distribution.date;
        final debut = DateTime(
          _periode!.start.year,
          _periode!.start.month,
          _periode!.start.day,
        );
        final fin = DateTime(
          _periode!.end.year,
          _periode!.end.month,
          _periode!.end.day,
          23,
          59,
          59,
        );
        if (d.isBefore(debut) || d.isAfter(fin)) return false;
      }
      return true;
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 100),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilterChipPill(
              label: 'Toutes les soutes',
              selected: _souteFiltre == null,
              onTap: () => setState(() => _souteFiltre = null),
            ),
            for (final s in soutes)
              FilterChipPill(
                label: s.libelle,
                selected: _souteFiltre == s.libelle,
                onTap: () => setState(() => _souteFiltre = s.libelle),
              ),
            const SizedBox(width: 4),
            ActionChip(
              avatar: const Icon(Icons.event_outlined, size: 16),
              label: Text(
                _periode == null
                    ? 'Toute période'
                    : '${DateFormat('dd/MM/yy').format(_periode!.start)} → ${DateFormat('dd/MM/yy').format(_periode!.end)}',
              ),
              onPressed: () async {
                final r = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2023),
                  lastDate: DateTime.now().add(const Duration(days: 1)),
                  initialDateRange: _periode,
                );
                if (r != null) setState(() => _periode = r);
              },
            ),
            if (_periode != null)
              IconButton(
                tooltip: 'Effacer la période',
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => setState(() => _periode = null),
              ),
            const SizedBox(width: 4),
            // Le bouton ne se ferme que faute de matière : rien à imprimer,
            // ou une impression déjà en route. Il restait grisé tant qu'une
            // soute n'était pas choisie — sans le dire ailleurs que dans une
            // bulle d'aide, et l'état d'ensemble se refusait tout seul.
            Tooltip(
              message: filtrees.isEmpty
                  ? 'Aucune distribution à imprimer pour ce filtre'
                  : _souteFiltre == null
                  ? 'Imprimer l\'état de toutes les soutes'
                  : 'Imprimer l\'état de la soute $_souteFiltre',
              child: OutlinedButton.icon(
                onPressed: (filtrees.isEmpty || _impressionEnCours)
                    ? null
                    : () => _imprimer(filtrees),
                icon: _impressionEnCours
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.print_outlined, size: 18),
                label: const Text('Imprimer'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SectionHeader(title: 'Distributions (${filtrees.length})'),
        if (filtrees.isEmpty)
          const EmptyState(message: 'Aucune distribution pour ce filtre'),
        for (final v in filtrees) ...[
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0x1FEF6C00),
                child: Icon(Icons.arrow_upward, color: AppColors.ivoryOrange),
              ),
              title: Text(v.distribution.destinataire),
              subtitle: Text(
                '${v.souteLibelle} — ${v.repartitionLibelle} · ${v.distribution.vehicule ?? ''} '
                '${v.distribution.vhlImmatriculation ?? ''} · ${df.format(v.distribution.date)}'
                '${v.distribution.motif != null ? ' · ${v.distribution.motif}' : ''}',
              ),
              isThreeLine: true,
              trailing: Text(
                '-${formatMilliers(v.distribution.quantitePercue)} L',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.ivoryOrange,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}
