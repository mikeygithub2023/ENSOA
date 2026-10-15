import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sig_ensoa/core/theme.dart';
import 'package:sig_ensoa/core/chargement.dart';
import 'package:sig_ensoa/core/roles.dart';
import 'package:sig_ensoa/modules/logistique/compat.dart';
import '../../data/models/armement.dart';
import '../../data/repositories/armament_providers.dart';
import '../../shared/widgets/skeleton.dart';
import 'package:sig_ensoa/shared/widgets/icone_arme.dart';
import '../../shared/widgets/widgets.dart';
import 'import_armes_dialog.dart';
import 'menu_suppression.dart';

/// Sous-rubrique « Registre » de l'Armement — les armes une à une,
/// filtrables par état, et l'import d'un registre existant.
class ArmesTabContent extends ConsumerStatefulWidget {
  const ArmesTabContent({super.key});

  @override
  ConsumerState<ArmesTabContent> createState() => _ArmesTabContentState();
}

class _ArmesTabContentState extends ConsumerState<ArmesTabContent> {
  EtatArme? _filtre;
  final _rechercheCtrl = TextEditingController();
  String _recherche = '';

  @override
  void dispose() {
    _rechercheCtrl.dispose();
    super.dispose();
  }

  Color _levelColor(Arme a) {
    if (a.etat == EtatArme.defectueux) return AppColors.danger;
    if (a.inspectionEnRetard) return AppColors.warning;
    return AppColors.success;
  }

  @override
  Widget build(BuildContext context) {
    final charge = estCharge(ref, ['armes']);
    final armes = ref.watch(armesProvider);

    // Le registre ne s'écrit pas par tout le monde : la base ne l'ouvre
    // qu'à l'armurerie, au chef du soutien technique et à
    // l'administrateur. Un bouton qui se ferait refuser par le serveur ne
    // vaut pas mieux qu'une absence de bouton.
    final role = ref.watch(sessionProvider)?.user.role;
    final peutEcrire =
        role == RoleLogistique.armurerie ||
        role == RoleLogistique.chefSoutienTechnique ||
        role == RoleLogistique.administrateur;

    final recherche = _recherche.trim().toLowerCase();
    final filtres = armes.where((a) {
      if (_filtre != null && a.etat != _filtre) return false;
      if (recherche.isEmpty) return true;
      return [
        a.numeroSerie,
        a.type,
        a.modele,
        a.positionActuelle ?? '',
      ].join(' ').toLowerCase().contains(recherche);
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 100),
      children: [
        if (peutEcrire) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => afficherImportArmes(context),
              icon: const Icon(Icons.upload_file_outlined, size: 18),
              label: const Text('Importer depuis Excel'),
            ),
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _rechercheCtrl,
          decoration: InputDecoration(
            hintText:
                'Rechercher une arme (désignation, marquage, n° série, '
                'position)...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _recherche.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() {
                      _rechercheCtrl.clear();
                      _recherche = '';
                    }),
                  ),
          ),
          onChanged: (v) => setState(() => _recherche = v),
        ),
        const SizedBox(height: 12),
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
                title: Text(a.designationComplete),
                subtitle: Text(
                  'N° série ${a.numeroSerie}'
                  '${(a.positionActuelle ?? '').trim().isEmpty ? '' : ' · ${a.positionActuelle}'}'
                  '${a.inspectionEnRetard ? ' · inspection en retard' : ''}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    StatusChip(
                      label: a.etat.label,
                      level: a.etat == EtatArme.defectueux
                          ? AlertLevel.critical
                          : (a.inspectionEnRetard
                                ? AlertLevel.warning
                                : AlertLevel.info),
                    ),
                    MenuSuppressionArticle(
                      titre: 'Supprimer l\'arme',
                      designation:
                          '${a.designationComplete} (n° ${a.numeroSerie})',
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
