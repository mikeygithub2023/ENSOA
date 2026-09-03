import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sig_ensoa/core/theme.dart';
import 'package:sig_ensoa/core/chargement.dart';
import '../../data/models/armement.dart';
import '../../data/repositories/armament_providers.dart';
import '../../shared/widgets/skeleton.dart';
import 'package:sig_ensoa/shared/widgets/icone_arme.dart';
import '../../shared/widgets/widgets.dart';
import 'menu_suppression.dart';

/// Contenu de l'onglet "Armes" — registre des armes, filtrable par état.
class ArmesTabContent extends ConsumerStatefulWidget {
  const ArmesTabContent({super.key});

  @override
  ConsumerState<ArmesTabContent> createState() => _ArmesTabContentState();
}

class _ArmesTabContentState extends ConsumerState<ArmesTabContent> {
  EtatArme? _filtre;

  Color _levelColor(Arme a) {
    if (a.inspectionEnRetard) return AppColors.warning;
    switch (a.etat) {
      case EtatArme.enDotation:
        return AppColors.militaryGreen;
      case EtatArme.enArmurerie:
        return AppColors.success;
      case EtatArme.enMaintenance:
        return AppColors.warning;
      case EtatArme.reforme:
        return AppColors.danger;
    }
  }

  @override
  Widget build(BuildContext context) {
    final charge = estCharge(ref, ['armes']);
    final armes = ref.watch(armesProvider);
    final filtres = _filtre == null
        ? armes
        : armes.where((a) => a.etat == _filtre).toList();

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
            for (final e in EtatArme.values)
              FilterChipPill(
                label: e.label,
                selected: _filtre == e,
                onTap: () => setState(() => _filtre = e),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (!charge) const SkeletonList(itemCount: 4),
        if (charge && filtres.isEmpty)
          const EmptyState(message: 'Aucune arme pour ce filtre'),
        if (charge)
          for (final a in filtres) ...[
            Card(
              // Clé d'identité : sans elle, Flutter réassocie les états par
              // position, et le sablier d'une ligne supprimée retomberait
              // sur celle qui prend sa place.
              key: ValueKey(a.id),
              child: ListTile(
                onTap: () =>
                    context.go('/logistique/armement/detail', extra: a),
                leading: CircleAvatar(
                  backgroundColor: _levelColor(a).withValues(alpha: 0.12),
                  child: ColorFiltered(
                    colorFilter: ColorFilter.mode(
                      _levelColor(a),
                      BlendMode.srcIn,
                    ),
                    child: const IconeArme(size: 28),
                  ),
                ),
                title: Text('${a.type} — ${a.modele}'),
                subtitle: Text(
                  'N° série ${a.numeroSerie}${a.inspectionEnRetard ? ' · inspection en retard' : ''}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    StatusChip(
                      label: a.etat.label,
                      level: a.inspectionEnRetard
                          ? AlertLevel.warning
                          : AlertLevel.info,
                    ),
                    MenuSuppressionArticle(
                      titre: 'Supprimer l\'arme',
                      designation:
                          '${a.type} ${a.modele} (n° ${a.numeroSerie})',
                      // Une arme entre les mains de quelqu'un ne quitte pas
                      // le registre : c'est précisément ce que l'armurerie
                      // doit pouvoir retrouver.
                      empechement: _estSortie(ref, a.id)
                          ? 'Cette arme fait l\'objet d\'un bon de sortie en cours. '
                                'Enregistrez son retour avant de la retirer du registre.'
                          : null,
                      onSupprimer: () =>
                          ref.read(armesProvider.notifier).supprimer(a.id),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

/// Une arme est-elle actuellement sortie ? Une dotation sans date de retour
/// effective est une arme encore dehors.
bool _estSortie(WidgetRef ref, String armeId) {
  return ref
      .read(dotationsProvider)
      .any((d) => d.armeId == armeId && d.enCours);
}
