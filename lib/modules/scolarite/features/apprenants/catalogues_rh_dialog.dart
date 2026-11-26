// Les deux catalogues des ressources humaines : les pièces du dossier de
// pension, et les décorations.
//
// Ils sont livrés vides. Les pièces qu'exige la Direction des Ressources
// Humaines et les décorations que décerne le Chef d'État-Major ne sont
// pas de notre ressort : les deviner, c'est risquer qu'un dossier soit déclaré complet
// parce qu'il contient les pièces qu'on avait supposées. Cet écran est donc
// le premier à ouvrir — sans lui, les deux onglets n'ont rien à montrer, et
// ils le disent.
//
// Un même écran pour les deux listes, qui ne diffèrent que par une colonne :
// une pièce peut être obligatoire ou simplement attendue, une décoration
// n'a pas cette nuance.
//
// RIEN NE SE SUPPRIME DE FORCE. Une pièce ou une décoration que des
// dossiers mentionnent déjà, la base refuse de l'effacer — c'est voulu, et
// l'écran propose alors de la désactiver : elle quitte la saisie, les
// écritures faites gardent leur sens.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sig_ensoa/core/erreurs.dart';
import 'package:sig_ensoa/core/theme.dart' hide AlertLevel, AlertLevelColor;
import '../../shared/widgets/common.dart';
import 'providers/decorations_providers.dart';
import 'providers/pension_providers.dart';

/// Une ligne de catalogue, telle que l'écran la manipule — indifférente à
/// la table d'où elle vient.
class _Entree {
  const _Entree({
    required this.id,
    required this.libelle,
    required this.ordre,
    required this.active,
    required this.obligatoire,
    this.condition,
  });

  final String id;
  final String libelle;
  final int ordre;
  final bool active;

  /// À qui la pièce se demande, quand ce n'est pas à tous : « Si le
  /// militaire est marié ».
  final String? condition;

  /// Sans objet pour les décorations : l'écran ne l'affiche pas alors.
  final bool obligatoire;
}

/// Ce que l'écran sait faire d'un catalogue, quelle que soit la table.
class _Pilote {
  const _Pilote({
    required this.titre,
    required this.consigne,
    required this.nomSingulier,
    required this.avecObligatoire,
    required this.lire,
    required this.creer,
    required this.modifier,
    required this.supprimer,
    required this.rafraichir,
  });

  final String titre;
  final String consigne;
  final String nomSingulier;
  final bool avecObligatoire;

  final List<_Entree> Function(WidgetRef ref) lire;
  final Future<void> Function(
    WidgetRef ref, {
    required String libelle,
    required int ordre,
    required bool obligatoire,
  })
  creer;
  final Future<void> Function(
    WidgetRef ref,
    String id, {
    required String libelle,
    required int ordre,
    required bool obligatoire,
    required bool active,
  })
  modifier;
  final Future<void> Function(WidgetRef ref, String id) supprimer;
  final void Function(WidgetRef ref) rafraichir;
}

/// Ouvre la gestion des pièces du dossier de pension.
Future<void> showPiecesPensionDialog(BuildContext context) {
  return _ouvrir(
    context,
    _Pilote(
      titre: 'Pièces du dossier de pension',
      consigne:
          'La liste qu\'exige la Direction des Ressources Humaines, dans '
          'l\'ordre du dossier. Une pièce obligatoire fait la complétude ; '
          'les autres sont attendues sans être exigées.',
      nomSingulier: 'pièce',
      avecObligatoire: true,
      lire: (ref) => [
        for (final p in ref.watch(toutesLesPiecesPensionProvider).value ?? [])
          _Entree(
            id: p.id,
            libelle: p.libelle,
            ordre: p.ordre,
            active: p.active,
            obligatoire: p.obligatoire,
            condition: p.condition.libelle,
          ),
      ],
      creer: (ref, {required libelle, required ordre, required obligatoire}) =>
          ref
              .read(pensionRepositoryProvider)
              .creerPiece(
                libelle: libelle,
                ordre: ordre,
                obligatoire: obligatoire,
              ),
      modifier:
          (
            ref,
            id, {
            required libelle,
            required ordre,
            required obligatoire,
            required active,
          }) => ref
              .read(pensionRepositoryProvider)
              .modifierPiece(
                id,
                libelle: libelle,
                ordre: ordre,
                obligatoire: obligatoire,
                active: active,
              ),
      supprimer: (ref, id) =>
          ref.read(pensionRepositoryProvider).supprimerPiece(id),
      rafraichir: (ref) {
        ref.invalidate(toutesLesPiecesPensionProvider);
        ref.invalidate(piecesPensionProvider);
        ref.invalidate(lignesPensionProvider);
      },
    ),
  );
}

/// Ouvre la gestion du catalogue des décorations.
Future<void> showCatalogueDecorationsDialog(BuildContext context) {
  return _ouvrir(
    context,
    _Pilote(
      titre: 'Catalogue des décorations',
      consigne:
          'Les décorations que décerne le Chef d\'État-Major, dans leur '
          'ordre de préséance — qui n\'est ni alphabétique ni '
          'chronologique.',
      nomSingulier: 'décoration',
      avecObligatoire: false,
      lire: (ref) => [
        for (final d
            in ref.watch(toutLeCatalogueDecorationsProvider).value ?? [])
          _Entree(
            id: d.id,
            libelle: d.libelle,
            ordre: d.ordre,
            active: d.active,
            obligatoire: false,
          ),
      ],
      creer: (ref, {required libelle, required ordre, required obligatoire}) =>
          ref
              .read(decorationsRepositoryProvider)
              .creerDecoration(libelle: libelle, ordre: ordre),
      modifier:
          (
            ref,
            id, {
            required libelle,
            required ordre,
            required obligatoire,
            required active,
          }) => ref
              .read(decorationsRepositoryProvider)
              .modifierDecoration(
                id,
                libelle: libelle,
                ordre: ordre,
                active: active,
              ),
      supprimer: (ref, id) =>
          ref.read(decorationsRepositoryProvider).supprimerDecoration(id),
      rafraichir: (ref) {
        ref.invalidate(toutLeCatalogueDecorationsProvider);
        ref.invalidate(catalogueDecorationsProvider);
        ref.invalidate(decorationsRecuesProvider);
      },
    ),
  );
}

Future<void> _ouvrir(BuildContext context, _Pilote pilote) {
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.all(24),
      child: _CatalogueDialog(pilote: pilote),
    ),
  );
}

class _CatalogueDialog extends ConsumerStatefulWidget {
  const _CatalogueDialog({required this.pilote});

  final _Pilote pilote;

  @override
  ConsumerState<_CatalogueDialog> createState() => _CatalogueDialogState();
}

class _CatalogueDialogState extends ConsumerState<_CatalogueDialog> {
  final _libelleCtrl = TextEditingController();
  final _ordreCtrl = TextEditingController();
  bool _obligatoire = true;
  bool _occupe = false;
  String? _erreur;

  @override
  void dispose() {
    _libelleCtrl.dispose();
    _ordreCtrl.dispose();
    super.dispose();
  }

  Future<void> _faire(Future<void> Function() action) async {
    setState(() {
      _occupe = true;
      _erreur = null;
    });
    try {
      await action();
      widget.pilote.rafraichir(ref);
      if (!mounted) return;
      setState(() => _occupe = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _occupe = false;
        _erreur = messageErreur(e);
      });
    }
  }

  Future<void> _ajouter() async {
    final libelle = _libelleCtrl.text.trim();
    if (libelle.isEmpty) return;
    final ordre = int.tryParse(_ordreCtrl.text.trim()) ?? 0;
    await _faire(
      () => widget.pilote.creer(
        ref,
        libelle: libelle,
        ordre: ordre,
        obligatoire: _obligatoire,
      ),
    );
    if (!mounted || _erreur != null) return;
    _libelleCtrl.clear();
    _ordreCtrl.clear();
  }

  Future<void> _renommer(_Entree e) async {
    final ctrl = TextEditingController(text: e.libelle);
    final ordreCtrl = TextEditingController(text: e.ordre.toString());
    var obligatoire = e.obligatoire;
    final valide = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          scrollable: true,
          title: Text('Modifier la ${widget.pilote.nomSingulier}'),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: ctrl,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Intitulé'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ordreCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Ordre'),
              ),
              if (widget.pilote.avecObligatoire)
                CheckboxListTile(
                  value: obligatoire,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Obligatoire'),
                  onChanged: (v) => setLocal(() => obligatoire = v ?? false),
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
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
    final libelle = ctrl.text.trim();
    final ordre = int.tryParse(ordreCtrl.text.trim()) ?? e.ordre;
    ctrl.dispose();
    ordreCtrl.dispose();
    if (valide != true || libelle.isEmpty) return;
    await _faire(
      () => widget.pilote.modifier(
        ref,
        e.id,
        libelle: libelle,
        ordre: ordre,
        obligatoire: obligatoire,
        active: e.active,
      ),
    );
  }

  Future<void> _basculerActive(_Entree e) => _faire(
    () => widget.pilote.modifier(
      ref,
      e.id,
      libelle: e.libelle,
      ordre: e.ordre,
      obligatoire: e.obligatoire,
      active: !e.active,
    ),
  );

  Future<void> _supprimer(_Entree e) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text('Supprimer « ${e.libelle} »'),
        content: const Text(
          'La suppression est refusée si des dossiers la mentionnent déjà. '
          'Dans ce cas, désactivez-la : elle quitte la saisie et les '
          'écritures faites gardent leur sens.',
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
    if (confirme != true) return;
    await _faire(() => widget.pilote.supprimer(ref, e.id));
  }

  @override
  Widget build(BuildContext context) {
    final taille = MediaQuery.of(context).size;
    final largeur = taille.width - 48 < 700 ? taille.width - 48 : 700.0;
    final hauteur = taille.height - 48 < 680 ? taille.height - 48 : 680.0;
    final entrees = widget.pilote.lire(ref);

    return SizedBox(
      width: largeur,
      height: hauteur,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.pilote.titre,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: Text(
              widget.pilote.consigne,
              style: const TextStyle(color: AppColors.inkMuted, fontSize: 13),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _libelleCtrl,
                        decoration: InputDecoration(
                          labelText: 'Nouvelle ${widget.pilote.nomSingulier}',
                          isDense: true,
                        ),
                        onSubmitted: (_) => _occupe ? null : _ajouter(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 120,
                      child: TextField(
                        controller: _ordreCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Ordre',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: _occupe ? null : _ajouter,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Ajouter'),
                      ),
                    ),
                  ],
                ),
                if (widget.pilote.avecObligatoire)
                  CheckboxListTile(
                    value: _obligatoire,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text(
                      'Obligatoire — elle fait la complétude du dossier',
                      style: TextStyle(fontSize: 13),
                    ),
                    onChanged: _occupe
                        ? null
                        : (v) => setState(() => _obligatoire = v ?? false),
                  ),
                if (_erreur != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _erreur!,
                      style: const TextStyle(color: AppColors.danger),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: entrees.isEmpty
                ? EmptyState(
                    message:
                        'Catalogue vide. Ajoutez la première '
                        '${widget.pilote.nomSingulier} ci-dessus.',
                    icon: Icons.playlist_add,
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: entrees.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final e = entrees[i];
                      return ListTile(
                        dense: true,
                        leading: Text(
                          e.ordre.toString(),
                          style: const TextStyle(
                            color: AppColors.inkMuted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        title: Text(
                          e.libelle,
                          style: TextStyle(
                            color: e.active
                                ? AppColors.ink
                                : AppColors.inkMuted,
                            decoration: e.active
                                ? null
                                : TextDecoration.lineThrough,
                          ),
                        ),
                        subtitle: Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            if (widget.pilote.avecObligatoire)
                              StatusChip(
                                label: e.obligatoire
                                    ? 'Obligatoire'
                                    : 'Facultative',
                                level: e.obligatoire
                                    ? AlertLevel.warning
                                    : AlertLevel.info,
                              ),
                            if (e.condition != null)
                              StatusChip(
                                label: e.condition!,
                                level: AlertLevel.info,
                              ),
                            if (!e.active)
                              const StatusChip(
                                label: 'Désactivée',
                                level: AlertLevel.critical,
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              tooltip: 'Modifier',
                              onPressed: _occupe ? null : () => _renommer(e),
                            ),
                            IconButton(
                              icon: Icon(
                                e.active
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 18,
                              ),
                              tooltip: e.active ? 'Désactiver' : 'Réactiver',
                              onPressed: _occupe
                                  ? null
                                  : () => _basculerActive(e),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                size: 18,
                                color: AppColors.danger,
                              ),
                              tooltip: 'Supprimer',
                              onPressed: _occupe ? null : () => _supprimer(e),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                if (_occupe)
                  const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Fermer'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
