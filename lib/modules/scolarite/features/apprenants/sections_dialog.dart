import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sig_ensoa/core/erreurs.dart';
import 'package:sig_ensoa/core/formulaire.dart';
import 'package:sig_ensoa/core/theme.dart' hide AlertLevel, AlertLevelColor;
import '../../models/apprenant.dart';
import '../../models/promotion.dart';
import '../../models/section.dart';
import '../../shared/widgets/common.dart';
import '../matieres/providers/matieres_providers.dart';
import 'providers/apprenants_providers.dart';

/// La répartition d'une promotion en sections.
///
/// Deux cents élèves ne se commandent pas d'un bloc. On les répartit, et
/// cette répartition tient tout le cursus : la section s'attache à la
/// promotion, pas à la phase — l'élève la garde du FCB jusqu'à sa sortie.
///
/// L'écran tient les deux gestes au même endroit, parce qu'on les fait
/// ensemble : créer les sections à gauche, y verser les élèves à droite.
/// Le volet de gauche ouvre d'abord « Sans section » : c'est là qu'est tout
/// le monde le jour où l'on commence.
Future<void> showSectionsDialog(
  BuildContext context, {
  required Promotion promotion,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.all(24),
      child: _SectionsDialog(promotion: promotion),
    ),
  );
}

class _SectionsDialog extends ConsumerStatefulWidget {
  const _SectionsDialog({required this.promotion});

  final Promotion promotion;

  @override
  ConsumerState<_SectionsDialog> createState() => _SectionsDialogState();
}

class _SectionsDialogState extends ConsumerState<_SectionsDialog> {
  /// La section dont on regarde l'effectif. Nulle : ceux qui n'en ont pas
  /// encore — le point de départ.
  String? _sectionRegardee;

  final Set<String> _selection = {};
  bool _enCours = false;

  void _rafraichir() {
    ref.invalidate(sectionsListProvider);
    ref.invalidate(apprenantsListProvider);
    ref.invalidate(apprenantsByPromotionProvider(widget.promotion.id));
  }

  List<Apprenant> _effectifDe(List<Apprenant> tous, String? sectionId) {
    return tous.where((a) => a.sectionId == sectionId).toList()
      ..sort((a, b) => a.nomComplet.compareTo(b.nomComplet));
  }

  Future<void> _deplacer(String? vers, List<Section> sections) async {
    if (_selection.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final combien = _selection.length;
    setState(() => _enCours = true);
    try {
      await ref
          .read(sectionsRepositoryProvider)
          .affecter(apprenantIds: _selection.toList(), sectionId: vers);
      _selection.clear();
      _rafraichir();
      final ou = vers == null
          ? 'retiré(s) de leur section'
          : 'versé(s) dans ${sections.where((s) => s.id == vers).first.nom}';
      messenger.showSnackBar(
        SnackBar(
          content: Text('$combien élève(s) $ou.'),
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
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sections = ref.watch(
      sectionsParPromotionProvider(widget.promotion.id),
    );
    final apprenantsAsync = ref.watch(
      apprenantsByPromotionProvider(widget.promotion.id),
    );
    final tous = apprenantsAsync.value ?? const <Apprenant>[];
    final regardes = _effectifDe(tous, _sectionRegardee);

    // Une section supprimée pendant qu'on la regardait : on revient à ceux
    // qui n'en ont pas, plutôt que d'afficher une liste vide sans raison.
    if (_sectionRegardee != null &&
        !sections.any((s) => s.id == _sectionRegardee)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _sectionRegardee = null);
      });
    }

    return SizedBox(
      width: 940,
      height: 640,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sections',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      Text(
                        widget.promotion.intitule,
                        style: const TextStyle(
                          color: AppColors.inkMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: apprenantsAsync.when(
              data: (_) => Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 300,
                    child: _VoletSections(
                      promotion: widget.promotion,
                      sections: sections,
                      tous: tous,
                      regardee: _sectionRegardee,
                      onRegarder: (id) => setState(() {
                        _sectionRegardee = id;
                        _selection.clear();
                      }),
                      onChange: _rafraichir,
                    ),
                  ),
                  const VerticalDivider(width: 1, color: AppColors.border),
                  Expanded(
                    child: _VoletEffectif(
                      apprenants: regardes,
                      sections: sections,
                      sectionRegardee: _sectionRegardee,
                      selection: _selection,
                      enCours: _enCours,
                      onSelection: (id, retenu) => setState(() {
                        if (retenu) {
                          _selection.add(id);
                        } else {
                          _selection.remove(id);
                        }
                      }),
                      onToutSelectionner: (retenu) => setState(() {
                        final ids = regardes.map((a) => a.id);
                        if (retenu) {
                          _selection.addAll(ids);
                        } else {
                          _selection.removeAll(ids);
                        }
                      }),
                      onDeplacer: (vers) => _deplacer(vers, sections),
                    ),
                  ),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => EmptyState(
                message: 'Erreur de chargement : ${messageErreur(error)}',
                icon: Icons.error_outline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Le volet de gauche : les sections, leur effectif, et de quoi en créer.
class _VoletSections extends ConsumerWidget {
  const _VoletSections({
    required this.promotion,
    required this.sections,
    required this.tous,
    required this.regardee,
    required this.onRegarder,
    required this.onChange,
  });

  final Promotion promotion;
  final List<Section> sections;
  final List<Apprenant> tous;
  final String? regardee;
  final ValueChanged<String?> onRegarder;
  final VoidCallback onChange;

  int _combien(String? sectionId) =>
      tous.where((a) => a.sectionId == sectionId).length;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ListView(
              children: [
                _LigneSection(
                  titre: 'Sans section',
                  effectif: _combien(null),
                  retenue: regardee == null,
                  onTap: () => onRegarder(null),
                ),
                for (final section in sections)
                  _LigneSection(
                    titre: section.nom,
                    effectif: _combien(section.id),
                    retenue: regardee == section.id,
                    onTap: () => onRegarder(section.id),
                    onModifier: () => _formulaireSection(
                      context,
                      ref,
                      promotion: promotion,
                      section: section,
                      apres: onChange,
                    ),
                    onSupprimer: () => _confirmerSuppression(
                      context,
                      ref,
                      section: section,
                      effectif: _combien(section.id),
                      apres: onChange,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _formulaireSection(
                context,
                ref,
                promotion: promotion,
                apres: onChange,
                ordreSuggere: sections.length + 1,
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Nouvelle section'),
            ),
          ),
        ],
      ),
    );
  }
}

class _LigneSection extends StatelessWidget {
  const _LigneSection({
    required this.titre,
    required this.effectif,
    required this.retenue,
    required this.onTap,
    this.onModifier,
    this.onSupprimer,
  });

  final String titre;
  final int effectif;
  final bool retenue;
  final VoidCallback onTap;
  final VoidCallback? onModifier;
  final VoidCallback? onSupprimer;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: retenue ? AppColors.blueMist : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.control),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.control),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    titre,
                    style: TextStyle(
                      fontWeight: retenue ? FontWeight.w800 : FontWeight.w600,
                      color: retenue ? AppColors.blueDeep : AppColors.ink,
                      fontSize: 13,
                    ),
                  ),
                ),
                Text(
                  '$effectif',
                  style: const TextStyle(
                    color: AppColors.inkMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (onModifier != null)
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    tooltip: 'Renommer',
                    visualDensity: VisualDensity.compact,
                    onPressed: onModifier,
                  ),
                if (onSupprimer != null)
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 16,
                      color: AppColors.danger,
                    ),
                    tooltip: 'Supprimer',
                    visualDensity: VisualDensity.compact,
                    onPressed: onSupprimer,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Le volet de droite : l'effectif de la section regardée, et le geste qui
/// le déplace ailleurs.
class _VoletEffectif extends StatelessWidget {
  const _VoletEffectif({
    required this.apprenants,
    required this.sections,
    required this.sectionRegardee,
    required this.selection,
    required this.enCours,
    required this.onSelection,
    required this.onToutSelectionner,
    required this.onDeplacer,
  });

  final List<Apprenant> apprenants;
  final List<Section> sections;
  final String? sectionRegardee;
  final Set<String> selection;
  final bool enCours;
  final void Function(String id, bool retenu) onSelection;
  final ValueChanged<bool> onToutSelectionner;
  final ValueChanged<String?> onDeplacer;

  @override
  Widget build(BuildContext context) {
    final ids = apprenants.map((a) => a.id).toSet();
    final tousRetenus = ids.isNotEmpty && ids.every(selection.contains);
    // On ne propose pas de verser dans la section qu'on regarde déjà.
    final destinations = <(String?, String)>[
      if (sectionRegardee != null) (null, 'Retirer de leur section'),
      for (final s in sections)
        if (s.id != sectionRegardee) (s.id, s.nom),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(
                value: tousRetenus,
                onChanged: ids.isEmpty
                    ? null
                    : (value) => onToutSelectionner(value ?? false),
              ),
              Text(
                selection.isEmpty
                    ? '${apprenants.length} élève(s)'
                    : '${selection.length} retenu(s) sur ${apprenants.length}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.inkMuted,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              if (destinations.isNotEmpty)
                PopupMenuButton<String?>(
                  enabled: selection.isNotEmpty && !enCours,
                  tooltip: 'Verser la sélection dans…',
                  onSelected: onDeplacer,
                  itemBuilder: (context) => [
                    for (final (id, libelle) in destinations)
                      PopupMenuItem<String?>(value: id, child: Text(libelle)),
                  ],
                  // Un cadre, pas un bouton : un vrai bouton capterait le
                  // clic au lieu de le laisser ouvrir le menu.
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(AppRadii.control),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.move_down_outlined,
                          size: 18,
                          color: selection.isEmpty
                              ? AppColors.inkMuted
                              : AppColors.blueDeep,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Verser dans…',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: selection.isEmpty
                                ? AppColors.inkMuted
                                : AppColors.blueDeep,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: apprenants.isEmpty
                ? const EmptyState(
                    message: 'Aucun élève ici.',
                    icon: Icons.groups_outlined,
                  )
                : ListView.builder(
                    itemCount: apprenants.length,
                    itemBuilder: (context, index) {
                      final apprenant = apprenants[index];
                      final retenu = selection.contains(apprenant.id);
                      return CheckboxListTile(
                        dense: true,
                        value: retenu,
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: (value) =>
                            onSelection(apprenant.id, value ?? false),
                        title: Text(
                          apprenant.nomComplet,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        subtitle: Text(
                          apprenant.matricule?.isNotEmpty ?? false
                              ? apprenant.matricule!
                              : 'Sans matricule',
                          style: const TextStyle(fontSize: 12),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Création et renommage partagent le même formulaire : une section ne
/// porte qu'un nom et un rang.
Future<void> _formulaireSection(
  BuildContext context,
  WidgetRef ref, {
  required Promotion promotion,
  required VoidCallback apres,
  Section? section,
  int ordreSuggere = 0,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final formKey = GlobalKey<FormState>();
  final nomCtrl = TextEditingController(text: section?.nom);
  final ordreCtrl = TextEditingController(
    text: (section?.ordre ?? ordreSuggere).toString(),
  );
  final modification = section != null;

  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      scrollable: true,
      title: Text(modification ? 'Renommer la section' : 'Nouvelle section'),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: nomCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Nom (ex. 1ère section)',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: ordreCtrl,
              decoration: const InputDecoration(
                labelText: 'Rang d\'affichage',
                helperText:
                    'La 10ème section se range après la 9ème, '
                    'pas après la 1ère.',
              ),
              keyboardType: TextInputType.number,
              validator: (v) => int.tryParse(v?.trim() ?? '') == null
                  ? 'Nombre attendu'
                  : null,
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
            if (!validerFormulaire(context, formKey)) return;
            final depot = ref.read(sectionsRepositoryProvider);
            final nom = nomCtrl.text.trim();
            final ordre = int.parse(ordreCtrl.text.trim());
            try {
              if (modification) {
                await depot.update(id: section.id, nom: nom, ordre: ordre);
              } else {
                await depot.create(
                  promotionId: promotion.id,
                  nom: nom,
                  ordre: ordre,
                );
              }
              apres();
              if (context.mounted) Navigator.of(context).pop();
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    modification ? 'Section renommée.' : 'Section créée.',
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
          },
          child: Text(modification ? 'Enregistrer' : 'Créer'),
        ),
      ],
    ),
  );
}

Future<void> _confirmerSuppression(
  BuildContext context,
  WidgetRef ref, {
  required Section section,
  required int effectif,
  required VoidCallback apres,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final confirme = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      scrollable: true,
      title: Text('Supprimer ${section.nom}'),
      // Supprimer une section ne supprime pas ses élèves : la colonne est
      // en « set null ». Le dire évite qu'on n'ose pas.
      content: Text(
        effectif == 0
            ? '${section.nom} sera supprimée. Elle est vide.'
            : '${section.nom} sera supprimée. Ses $effectif élève(s) ne '
                  'sont pas supprimés : ils reviennent « sans section », et '
                  'vous pourrez les répartir à nouveau.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Supprimer'),
        ),
      ],
    ),
  );
  if (confirme != true) return;

  try {
    await ref.read(sectionsRepositoryProvider).delete(section.id);
    apres();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Section supprimée.'),
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
