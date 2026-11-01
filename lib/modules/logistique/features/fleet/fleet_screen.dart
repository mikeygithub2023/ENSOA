import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sig_ensoa/core/theme.dart';
import 'package:sig_ensoa/core/chargement.dart';
import 'package:sig_ensoa/core/roles.dart';
import 'package:sig_ensoa/modules/logistique/compat.dart';
import '../../data/models/vehicule.dart';
import '../../data/repositories/fleet_providers.dart';
import '../../shared/widgets/skeleton.dart';
import '../../shared/widgets/widgets.dart';
import 'import_vehicules_dialog.dart';
import 'vehicle_form_dialog.dart';

class FleetScreen extends ConsumerStatefulWidget {
  const FleetScreen({super.key, this.sansCadre = false});

  /// Rendu nu, sans titre ni cadre propre : l'espace Garage à onglets porte le
  /// titre, et la liste des véhicules n'y est qu'un onglet parmi d'autres. Le
  /// bouton « Nouveau véhicule » reste, posé sur l'onglet.
  final bool sansCadre;

  @override
  ConsumerState<FleetScreen> createState() => _FleetScreenState();
}

class _FleetScreenState extends ConsumerState<FleetScreen> {
  EtatVehicule? _filtre;

  /// Hors mode sélection, un appui ouvre la fiche. Les deux gestes ne
  /// peuvent pas cohabiter sur la même carte : on bascule.
  bool _selection = false;

  /// Par identifiant plutôt que par position : le filtre change, la liste
  /// se rafraîchit, et une sélection tenue par index désignerait alors
  /// d'autres véhicules que ceux qu'on avait cochés.
  final Set<String> _coches = {};
  bool _suppression = false;

  void _quitterSelection() {
    setState(() {
      _selection = false;
      _coches.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final charge = estCharge(ref, ['vehicules']);
    final vehicules = ref.watch(vehiculesProvider);
    final filtres = _filtre == null
        ? vehicules
        : vehicules.where((v) => v.etat == _filtre).toList();

    // Le parc ne se modifie pas par tout le monde : la base n'ouvre
    // l'écriture qu'au garage, au chef du soutien technique et à
    // l'administrateur. Un bouton qui se ferait refuser par le serveur ne
    // vaut pas mieux qu'une absence de bouton.
    final role = ref.watch(sessionProvider)?.user.role;
    final peutSupprimer =
        role == RoleLogistique.garage ||
        role == RoleLogistique.chefSoutienTechnique ||
        role == RoleLogistique.administrateur;

    // Une sélection peut survivre à un changement de filtre : on ne garde
    // que ce qui reste affiché, sinon « Supprimer (7) » retirerait des
    // véhicules que l'écran ne montre plus.
    final visibles = {for (final v in filtres) v.id};
    final cochesVisibles = _coches.where(visibles.contains).toSet();

    final fab = _selection
        ? null
        : FloatingActionButton.extended(
            onPressed: () => showDialog(
              context: context,
              builder: (_) => const VehicleFormDialog(),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Nouveau véhicule'),
          );

    final corps = <Widget>[
        if (_selection)
          _BarreSelection(
            coches: cochesVisibles.length,
            total: filtres.length,
            suppressionEnCours: _suppression,
            onToutCocher: () => setState(() => _coches.addAll(visibles)),
            onToutDecocher: () =>
                setState(() => _coches.removeAll(visibles.toList())),
            onSupprimer: () => _supprimerSelection(filtres, cochesVisibles),
            onQuitter: _suppression ? null : _quitterSelection,
          )
        else
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => afficherImportVehicules(context),
                icon: const Icon(Icons.upload_file_outlined, size: 18),
                label: const Text('Importer depuis Excel'),
              ),
              if (peutSupprimer && vehicules.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () => setState(() => _selection = true),
                  icon: const Icon(Icons.checklist_rounded, size: 18),
                  label: const Text('Sélectionner'),
                ),
            ],
          ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          children: [
            FilterChipPill(
              label: 'Tous',
              selected: _filtre == null,
              onTap: () => setState(() => _filtre = null),
            ),
            for (final e in EtatVehicule.values)
              FilterChipPill(
                label: e.label,
                selected: _filtre == e,
                onTap: () => setState(() => _filtre = e),
              ),
          ],
        ),
        const SizedBox(height: 20),
        if (!charge)
          const SkeletonGrid(
            itemCount: 6,
            maxCrossAxisExtent: 340,
            mainAxisExtent: 160,
          ),
        if (charge && filtres.isEmpty)
          const EmptyState(message: 'Aucun véhicule pour ce filtre'),
        if (charge)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filtres.length,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 340,
              mainAxisExtent: 160,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemBuilder: (context, i) {
              final v = filtres[i];
              final coche = _coches.contains(v.id);
              return Card(
                color: coche
                    ? AppColors.ivoryOrange.withValues(alpha: 0.10)
                    : null,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _selection
                      ? () => setState(() {
                          if (!_coches.remove(v.id)) _coches.add(v.id);
                        })
                      : () => context.go('/logistique/parc/detail', extra: v),
                  // Un appui long entre en sélection depuis n'importe quelle
                  // carte, et la coche au passage : c'est le geste qu'on
                  // tente d'instinct sur une tablette.
                  onLongPress: _selection
                      ? null
                      : () => setState(() {
                          _selection = true;
                          _coches.add(v.id);
                        }),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (_selection)
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: Checkbox(
                                    value: coche,
                                    visualDensity: VisualDensity.compact,
                                    onChanged: (_) => setState(() {
                                      if (!_coches.remove(v.id)) {
                                        _coches.add(v.id);
                                      }
                                    }),
                                  ),
                                ),
                              ),
                            Expanded(
                              child: Text(
                                '${v.marque} ${v.modele}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            StatusChip(
                              label: v.etat.label,
                              level: _levelFor(v.etat),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          v.immatriculation,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            const Icon(Icons.speed, size: 16),
                            const SizedBox(width: 4),
                            Text('${v.kilometrage} km'),
                            const SizedBox(width: 16),
                            if (v.positionActuelle != null) ...[
                              const Icon(Icons.groups_outlined, size: 16),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  v.positionActuelle!,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
    ];

    if (widget.sansCadre) {
      // L'onglet porte son propre défilement et pose le FAB par-dessus, comme
      // le fait ScreenScaffold — mais sans titre, celui de l'espace Garage
      // suffisant.
      return Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: corps,
            ),
          ),
          if (fab != null)
            Positioned(right: 4, bottom: 12, child: fab),
        ],
      );
    }

    return ScreenScaffold(
      title: 'Parc automobile',
      floatingActionButton: fab,
      children: corps,
    );
  }

  /// Retire du parc les véhicules cochés, après confirmation.
  ///
  /// Le compte annoncé est celui que la base a réellement retiré, non celui
  /// qu'on lui a soumis : une sélection peut contenir un véhicule qu'on n'a
  /// pas le droit de toucher, et annoncer « 12 retirés » quand il y en a eu
  /// 9 ferait douter des trois qui restent à l'écran.
  Future<void> _supprimerSelection(
    List<Vehicule> affiches,
    Set<String> coches,
  ) async {
    if (coches.isEmpty) return;
    final choisis = affiches.where((v) => coches.contains(v.id)).toList();

    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(
          choisis.length == 1
              ? 'Supprimer le véhicule'
              : 'Supprimer ${choisis.length} véhicules',
        ),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              choisis.length == 1
                  ? 'Ce véhicule sera retiré du parc actif. Son historique '
                        '(réparations, vidanges, mouvements) reste conservé.'
                  : 'Ces véhicules seront retirés du parc actif. Leur '
                        'historique (réparations, vidanges, mouvements) reste '
                        'conservé.',
            ),
            const SizedBox(height: 12),
            // On les nomme : une suppression en lot se confirme sur ce
            // qu'elle emporte, pas sur un nombre.
            for (final v in choisis.take(12))
              Text(
                '• ${v.immatriculation} — ${v.marque} ${v.modele}',
                style: const TextStyle(fontSize: 13),
              ),
            if (choisis.length > 12)
              Text(
                '… et ${choisis.length - 12} autre(s).',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.inkMuted,
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirme != true || !mounted) return;

    setState(() => _suppression = true);
    try {
      final retires = await ref
          .read(vehiculesProvider.notifier)
          .supprimerPlusieurs(choisis.map((v) => v.id).toList());
      if (!mounted) return;
      setState(() {
        _suppression = false;
        _selection = false;
        _coches.clear();
      });
      showSuccessSnackBar(
        context,
        retires <= 1
            ? '$retires véhicule retiré du parc.'
            : '$retires véhicules retirés du parc.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _suppression = false);
      showErrorSnackBar(context, e, action: 'Suppression impossible');
    }
  }

  AlertLevel _levelFor(EtatVehicule e) {
    switch (e) {
      case EtatVehicule.disponible:
        return AlertLevel.info;
      case EtatVehicule.enMission:
        return AlertLevel.info;
      case EtatVehicule.enReparation:
        return AlertLevel.warning;
      case EtatVehicule.horsService:
        return AlertLevel.critical;
    }
  }
}

/// La barre du mode sélection : ce qui est coché, de quoi tout prendre ou
/// tout lâcher, et l'action.
///
/// Elle remplace la rangée de boutons plutôt que de s'ajouter en dessous :
/// en mode sélection, « Importer depuis Excel » n'a plus de sens, et deux
/// rangées d'actions sur une tablette poussent la grille hors de l'écran.
class _BarreSelection extends StatelessWidget {
  const _BarreSelection({
    required this.coches,
    required this.total,
    required this.suppressionEnCours,
    required this.onToutCocher,
    required this.onToutDecocher,
    required this.onSupprimer,
    required this.onQuitter,
  });

  final int coches;
  final int total;
  final bool suppressionEnCours;
  final VoidCallback onToutCocher;
  final VoidCallback onToutDecocher;
  final VoidCallback onSupprimer;
  final VoidCallback? onQuitter;

  @override
  Widget build(BuildContext context) {
    final tout = coches == total && total > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.blueMist,
        borderRadius: BorderRadius.circular(AppRadii.control),
        border: Border.all(color: AppColors.border),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          IconButton(
            tooltip: 'Quitter la sélection',
            onPressed: onQuitter,
            icon: const Icon(Icons.close),
          ),
          Text(
            coches == 0
                ? 'Aucun véhicule coché'
                : '$coches véhicule(s) coché(s) sur $total',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          TextButton.icon(
            onPressed: suppressionEnCours
                ? null
                : (tout ? onToutDecocher : onToutCocher),
            icon: Icon(
              tout
                  ? Icons.check_box_outline_blank_rounded
                  : Icons.select_all_rounded,
              size: 18,
            ),
            label: Text(tout ? 'Tout décocher' : 'Tout sélectionner'),
          ),
          FilledButton.icon(
            onPressed: (coches == 0 || suppressionEnCours) ? null : onSupprimer,
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            icon: suppressionEnCours
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.delete_outline, size: 18),
            label: Text(
              suppressionEnCours ? 'Suppression...' : 'Supprimer ($coches)',
            ),
          ),
        ],
      ),
    );
  }
}
