// Vérifier le dossier de pension d'un militaire, pièce par pièce.
//
// TROIS ÉTATS, PAS DEUX. Une case cochée ou décochée ne suffit pas : entre
// « la pièce est au dossier » et « la pièce manque », il y a « personne n'a
// encore regardé ». Confondre les deux derniers, c'est accuser un bureau
// d'un manquement là où il n'y a qu'un travail non commencé — et, à
// l'inverse, faire croire qu'un dossier a été passé en revue quand il
// dort. La case est donc à trois états.
//
// RIEN N'EST ÉCRIT AVANT D'AVOIR ÉTÉ VALIDÉ, et seules les lignes changées
// partent. L'école travaille sur une liaison qui n'est pas toujours là :
// une vingtaine d'allers-retours pour cocher une liste serait une liste
// qu'on ne coche pas.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:sig_ensoa/core/erreurs.dart';
import 'package:sig_ensoa/core/theme.dart' hide AlertLevel, AlertLevelColor;
import 'package:sig_ensoa/modules/scolarite/compat.dart';
import '../../models/apprenant.dart';
import '../../models/pension.dart';
import '../../shared/widgets/common.dart';
import 'catalogues_rh_dialog.dart';
import 'data/pension_repository.dart';
import 'pension_bilan.dart';
import 'providers/pension_providers.dart';

Future<void> showVerifierDossierPensionDialog(
  BuildContext context, {
  required Apprenant apprenant,
  required bool peutEcrire,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.all(24),
      child: _VerifierDialog(apprenant: apprenant, peutEcrire: peutEcrire),
    ),
  );
}

/// Ce qu'on a décidé pour une pièce, à l'écran, avant d'enregistrer.
class _Avis {
  const _Avis({this.presente, this.observation, this.verifieLe});

  /// Nul : personne ne s'est encore prononcé.
  final bool? presente;
  final String? observation;
  final DateTime? verifieLe;

  _Avis copier({
    bool? presente,
    bool effacerPresente = false,
    String? observation,
    DateTime? verifieLe,
  }) => _Avis(
    presente: effacerPresente ? null : (presente ?? this.presente),
    observation: observation ?? this.observation,
    verifieLe: verifieLe ?? this.verifieLe,
  );
}

class _VerifierDialog extends ConsumerStatefulWidget {
  const _VerifierDialog({required this.apprenant, required this.peutEcrire});

  final Apprenant apprenant;
  final bool peutEcrire;

  @override
  ConsumerState<_VerifierDialog> createState() => _VerifierDialogState();
}

class _VerifierDialogState extends ConsumerState<_VerifierDialog> {
  /// L'état à l'écran, par pièce. Rempli au premier chargement depuis les
  /// lignes en base, puis modifié localement.
  final Map<String, _Avis> _avis = {};
  Map<String, _Avis> _initial = {};
  bool _charge = false;

  bool _envoi = false;
  String? _erreur;

  void _amorcer(List<PiecePension> pieces, List<LignePension> lignes) {
    if (_charge) return;
    final parPiece = {for (final l in lignes) l.pieceId: l};
    for (final p in pieces) {
      final l = parPiece[p.id];
      _avis[p.id] = _Avis(
        presente: l?.presente,
        observation: l?.observation,
        verifieLe: l?.verifieLe,
      );
    }
    _initial = Map.of(_avis);
    _charge = true;
  }

  bool _aChange(String pieceId) {
    final avant = _initial[pieceId];
    final apres = _avis[pieceId];
    return avant?.presente != apres?.presente ||
        (avant?.observation ?? '') != (apres?.observation ?? '') ||
        avant?.verifieLe != apres?.verifieLe;
  }

  int get _nbChangements => _avis.keys.where(_aChange).length;

  Future<void> _enregistrer(List<PiecePension> pieces) async {
    setState(() {
      _envoi = true;
      _erreur = null;
    });
    final depot = ref.read(pensionRepositoryProvider);
    final moi = ref.read(currentProfileProvider).value?.id;
    try {
      for (final p in pieces) {
        if (!_aChange(p.id)) continue;
        final avis = _avis[p.id]!;
        final presente = avis.presente;
        if (presente == null) {
          // Retour à « non vérifiée » : la ligne s'efface. Garder une
          // ligne qui ne dit rien ferait passer l'absence d'avis pour un
          // avis.
          await depot.effacer(apprenantId: widget.apprenant.id, pieceId: p.id);
          continue;
        }
        await depot.enregistrer(
          LignePensionDraft(
            apprenantId: widget.apprenant.id,
            pieceId: p.id,
            presente: presente,
            // Sans date saisie, c'est aujourd'hui : on vient de regarder.
            verifieLe: avis.verifieLe ?? DateTime.now(),
            verifiePar: moi,
            observation: (avis.observation ?? '').trim().isEmpty
                ? null
                : avis.observation!.trim(),
          ),
        );
      }
      ref.invalidate(lignesPensionProvider);
      ref.invalidate(lignesPensionByApprenantProvider(widget.apprenant.id));
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Dossier de pension mis à jour.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _envoi = false;
        _erreur = 'Enregistrement refusé : ${messageErreur(e)}';
      });
    }
  }

  Future<void> _observation(PiecePension piece) async {
    final avis = _avis[piece.id] ?? const _Avis();
    final ctrl = TextEditingController(text: avis.observation ?? '');
    var date = avis.verifieLe;
    final valide = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          scrollable: true,
          title: Text(piece.libelle),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: ctrl,
                autofocus: true,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Observation',
                  hintText: 'Copie légalisée, à renouveler, réclamée le…',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      date == null
                          ? 'Vérifiée le : aujourd\'hui'
                          : 'Vérifiée le ${DateFormat('dd/MM/yyyy').format(date!)}',
                      style: const TextStyle(color: AppColors.inkMuted),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final choix = await showDatePicker(
                        context: context,
                        initialDate: date ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (choix != null) setLocal(() => date = choix);
                    },
                    child: const Text('Changer la date'),
                  ),
                ],
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
              child: const Text('Garder'),
            ),
          ],
        ),
      ),
    );
    final texte = ctrl.text;
    ctrl.dispose();
    if (valide != true) return;
    setState(() {
      _avis[piece.id] = (_avis[piece.id] ?? const _Avis()).copier(
        observation: texte,
        verifieLe: date,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final piecesAsync = ref.watch(piecesPensionProvider);
    final lignesAsync = ref.watch(
      lignesPensionByApprenantProvider(widget.apprenant.id),
    );
    final estAdmin =
        ref.watch(currentProfileProvider).value?.role == AppRole.admin;

    final taille = MediaQuery.of(context).size;
    final largeur = taille.width - 48 < 760 ? taille.width - 48 : 760.0;
    final hauteur = taille.height - 48 < 700 ? taille.height - 48 : 700.0;

    final pieces = piecesAsync.value ?? const <PiecePension>[];
    final lignes = lignesAsync.value ?? const <LignePension>[];
    if (piecesAsync.hasValue && lignesAsync.hasValue) {
      _amorcer(pieces, lignes);
    }

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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Dossier de pension',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _identite(widget.apprenant),
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
                  onPressed: _envoi ? null : () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: piecesAsync.when(
              data: (pieces) {
                if (pieces.isEmpty) {
                  return _CatalogueVide(estAdmin: estAdmin);
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: pieces.length + 1,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    if (i == 0) return const _Legende();
                    final piece = pieces[i - 1];
                    final avis = _avis[piece.id] ?? const _Avis();
                    return _LignePieceTile(
                      piece: piece,
                      avis: avis,
                      peutEcrire: widget.peutEcrire && !_envoi,
                      onBascule: () => setState(() {
                        // présente → manquante → non vérifiée → présente
                        _avis[piece.id] = switch (avis.presente) {
                          true => avis.copier(presente: false),
                          false => avis.copier(effacerPresente: true),
                          null => avis.copier(presente: true),
                        };
                      }),
                      onObservation: () => _observation(piece),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Le catalogue des pièces n\'a pas pu être lu : '
                  '${messageErreur(e)}',
                  style: const TextStyle(color: AppColors.danger),
                ),
              ),
            ),
          ),
          if (_erreur != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _erreur!,
                style: const TextStyle(color: AppColors.danger),
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                if (pieces.isNotEmpty)
                  _BilanChip(
                    bilan: bilanDuDossier(pieces: pieces, lignes: lignes),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: _envoi ? null : () => Navigator.of(context).pop(),
                  child: const Text('Fermer'),
                ),
                const SizedBox(width: 8),
                if (widget.peutEcrire)
                  FilledButton(
                    onPressed: (_nbChangements == 0 || _envoi)
                        ? null
                        : () => _enregistrer(pieces),
                    child: _envoi
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _nbChangements == 0
                                ? 'Enregistrer'
                                : 'Enregistrer ($_nbChangements)',
                          ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _identite(Apprenant a) {
  final grade = a.grade;
  final nom = grade == null ? a.nomComplet : '$grade ${a.nomComplet}';
  final mat = a.matricule;
  return mat == null ? nom : '$nom · $mat';
}

/// Les trois états, dits une fois pour toutes en tête de liste.
class _Legende extends StatelessWidget {
  const _Legende();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Text(
        'Touchez la case pour passer d\'un état à l\'autre : pièce présente, '
        'pièce manquante, pièce non vérifiée. « Non vérifiée » n\'est pas '
        '« manquante » — c\'est qu\'on n\'a pas encore regardé.',
        style: TextStyle(color: AppColors.inkMuted, fontSize: 13),
      ),
    );
  }
}

class _LignePieceTile extends StatelessWidget {
  const _LignePieceTile({
    required this.piece,
    required this.avis,
    required this.peutEcrire,
    required this.onBascule,
    required this.onObservation,
  });

  final PiecePension piece;
  final _Avis avis;
  final bool peutEcrire;
  final VoidCallback onBascule;
  final VoidCallback onObservation;

  @override
  Widget build(BuildContext context) {
    final (icone, couleur, mot) = switch (avis.presente) {
      true => (Icons.check_box, AppColors.success, 'Présente'),
      false => (Icons.disabled_by_default, AppColors.danger, 'Manquante'),
      null => (
        Icons.check_box_outline_blank,
        AppColors.inkMuted,
        'Non vérifiée',
      ),
    };
    final observation = avis.observation;

    return ListTile(
      dense: true,
      leading: IconButton(
        icon: Icon(icone, color: couleur),
        tooltip: peutEcrire ? 'Changer l\'état' : mot,
        onPressed: peutEcrire ? onBascule : null,
      ),
      title: Text(piece.libelle),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                mot,
                style: TextStyle(
                  color: couleur,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              if (piece.obligatoire) ...[
                const SizedBox(width: 8),
                const StatusChip(
                  label: 'Obligatoire',
                  level: AlertLevel.warning,
                ),
              ],
              if (avis.verifieLe != null) ...[
                const SizedBox(width: 8),
                Text(
                  'le ${DateFormat('dd/MM/yyyy').format(avis.verifieLe!)}',
                  style: const TextStyle(
                    color: AppColors.inkMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
          if (observation != null && observation.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                observation,
                style: const TextStyle(
                  color: AppColors.inkMuted,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.notes_outlined, size: 18),
        tooltip: 'Observation et date',
        onPressed: peutEcrire ? onObservation : null,
      ),
    );
  }
}

class _BilanChip extends StatelessWidget {
  const _BilanChip({required this.bilan});

  final BilanDossierPension bilan;

  @override
  Widget build(BuildContext context) {
    return StatusChip(
      label: bilan.libelle,
      level: switch (bilan.etat) {
        EtatDossier.complet => AlertLevel.success,
        EtatDossier.incomplet => AlertLevel.critical,
        EtatDossier.nonVerifie => AlertLevel.warning,
        EtatDossier.sansCatalogue => AlertLevel.info,
      },
    );
  }
}

/// Ce qu'on dit quand il n'y a pas encore de catalogue.
class _CatalogueVide extends StatelessWidget {
  const _CatalogueVide({required this.estAdmin});

  final bool estAdmin;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.playlist_add, size: 40, color: AppColors.inkMuted),
            const SizedBox(height: 12),
            const Text(
              'Aucune pièce au catalogue.',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            const Text(
              'La liste des pièces exigées est celle de la Direction des '
              'Ressources Humaines : elle se saisit une fois, et sert à '
              'tous les dossiers.',
              style: TextStyle(color: AppColors.inkMuted, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            if (estAdmin) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => showPiecesPensionDialog(context),
                icon: const Icon(Icons.playlist_add, size: 18),
                label: const Text('Saisir les pièces'),
              ),
            ] else ...[
              const SizedBox(height: 16),
              const Text(
                'Demandez à l\'administrateur de la saisir.',
                style: TextStyle(color: AppColors.inkMuted, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
