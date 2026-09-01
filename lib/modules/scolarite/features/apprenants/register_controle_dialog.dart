import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sig_ensoa/core/erreurs.dart';
import 'package:sig_ensoa/core/theme.dart' hide AlertLevel, AlertLevelColor;
import '../../models/classe.dart';
import '../../models/controle.dart';
import '../../models/division.dart';
import '../../models/matiere.dart';
import 'data/controles_repository.dart';
import 'providers/controles_providers.dart';

/// Élision de "le" devant une voyelle ("l'examen" et non "le examen").
String _leElide(String noun) {
  const voyelles = {'a', 'e', 'i', 'o', 'u', 'h'};
  return voyelles.contains(noun[0].toLowerCase()) ? "l'$noun" : 'le $noun';
}

/// [moduleMatieres] n'est utile (et requis en pratique) que pour
/// `ControleType.module` : un module EST une matière, donc pas de libellé
/// libre — on choisit une matière parmi celles assignées à la classe qui
/// n'ont pas encore de module. Son coefficient est saisi ici comme pour un
/// contrôle continu/examen — il n'hérite pas du coefficient déjà défini
/// pour cette matière dans les Affectations par classe.
Future<void> showRegisterControleDialog(
  BuildContext context, {
  required Division division,
  required Classe classe,
  required ControleType type,
  List<Matiere> moduleMatieres = const [],
  bool aDesMatieresAffectees = true,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.all(24),
      child: _RegisterControleDialog(
        division: division,
        classe: classe,
        type: type,
        moduleMatieres: moduleMatieres,
        aDesMatieresAffectees: aDesMatieresAffectees,
      ),
    ),
  );
}

/// Modifie un contrôle existant (libellé/matière et coefficient). Pour un
/// module, [moduleMatieres] doit inclure la matière actuelle du contrôle en
/// plus des matières encore disponibles, pour qu'elle reste sélectionnable.
Future<void> showEditControleDialog(
  BuildContext context, {
  required Division division,
  required Classe classe,
  required Controle existing,
  List<Matiere> moduleMatieres = const [],
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.all(24),
      child: _RegisterControleDialog(
        division: division,
        classe: classe,
        type: existing.type,
        moduleMatieres: moduleMatieres,
        existing: existing,
      ),
    ),
  );
}

class _RegisterControleDialog extends ConsumerStatefulWidget {
  const _RegisterControleDialog({
    required this.division,
    required this.classe,
    required this.type,
    required this.moduleMatieres,
    this.aDesMatieresAffectees = true,
    this.existing,
  });

  final Division division;
  final Classe classe;
  final ControleType type;
  final List<Matiere> moduleMatieres;

  /// La phase a-t-elle au moins une matière affectée ? Une liste de choix
  /// vide a deux causes très différentes — aucune matière affectée, ou
  /// toutes déjà pourvues d'un module — et les confondre envoie chercher
  /// la mauvaise chose.
  final bool aDesMatieresAffectees;

  final Controle? existing;

  @override
  ConsumerState<_RegisterControleDialog> createState() =>
      _RegisterControleDialogState();
}

class _RegisterControleDialogState
    extends ConsumerState<_RegisterControleDialog> {
  final _libelleCtrl = TextEditingController();
  final _coefficientCtrl = TextEditingController();

  Matiere? _selectedMatiere;
  bool _submitting = false;
  String? _error;

  bool get _isModule => widget.type == ControleType.module;
  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _libelleCtrl.text = existing.libelle;
      _coefficientCtrl.text = _formatCoefficient(existing.coefficient);
      if (_isModule) {
        for (final matiere in widget.moduleMatieres) {
          if (matiere.id == existing.matiereId) {
            _selectedMatiere = matiere;
            break;
          }
        }
      }
    }
    _libelleCtrl.addListener(() => setState(() {}));
    _coefficientCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _libelleCtrl.dispose();
    _coefficientCtrl.dispose();
    super.dispose();
  }

  String _formatCoefficient(num value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toString();
  }

  num? get _parsedCoefficient =>
      num.tryParse(_coefficientCtrl.text.trim().replaceAll(',', '.'));

  bool get _isValid =>
      (_isModule
          ? _selectedMatiere != null
          : _libelleCtrl.text.trim().isNotEmpty) &&
      _parsedCoefficient != null;

  Future<void> _submit() async {
    if (!_isValid) return;
    final coefficient = _parsedCoefficient!;

    setState(() {
      _submitting = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      final libelle = _isModule
          ? _selectedMatiere!.nom
          : _libelleCtrl.text.trim();
      final matiereId = _isModule ? _selectedMatiere!.id : null;
      if (_isEdit) {
        await ref
            .read(controlesRepositoryProvider)
            .updateControle(
              controleId: widget.existing!.id,
              libelle: libelle,
              coefficient: coefficient,
              matiereId: matiereId,
            );
      } else {
        await ref
            .read(controlesRepositoryProvider)
            .createControle(
              ControleDraft(
                divisionId: widget.division.id,
                classeId: widget.classe.id,
                type: widget.type,
                libelle: libelle,
                coefficient: coefficient,
                matiereId: matiereId,
              ),
            );
      }
      ref.invalidate(controlesByClasseProvider(widget.classe.id));
      if (_isEdit) {
        ref.invalidate(controleByIdProvider(widget.existing!.id));
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(_isEdit ? 'Contrôle modifié.' : 'Contrôle enregistré.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Échec de l\'enregistrement : ${messageErreur(e)}';
          _submitting = false;
        });
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text('Erreur : ${messageErreur(e)}'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final width = screenSize.width - 48 < 480 ? screenSize.width - 48 : 480.0;

    return SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _isEdit
                        ? 'Modifier ${_leElide(widget.type.noun(widget.classe.type))}'
                        : 'Enregistrer un ${widget.type.noun(widget.classe.type)}',
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
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.blueMist,
                    borderRadius: BorderRadius.circular(AppRadii.control),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.groups_outlined,
                        size: 18,
                        color: AppColors.blueDeep,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${widget.classe.type == ClasseType.phase ? "Classe" : "Stage"} : ${widget.classe.nom} · ${widget.division.nom}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.blueDeep,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (_isModule) ...[
                  if (widget.moduleMatieres.isEmpty)
                    Text(
                      widget.aDesMatieresAffectees
                          ? 'Toutes les matières de cette phase ont déjà un '
                                'module. Affectez-en une nouvelle depuis la '
                                'rubrique Matières.'
                          : 'Aucune matière n\'est affectée à cette phase. '
                                'Un module EST une matière : créez-la dans '
                                'Matières › Catalogue, puis affectez-la à '
                                'cette phase dans Matières › Affectations '
                                'par phase.',
                      style: const TextStyle(color: AppColors.inkMuted),
                    )
                  else
                    DropdownButtonFormField<Matiere>(
                      initialValue: _selectedMatiere,
                      decoration: const InputDecoration(labelText: 'Matière'),
                      isExpanded: true,
                      items: [
                        for (final matiere in widget.moduleMatieres)
                          DropdownMenuItem(
                            value: matiere,
                            child: Text(matiere.nom),
                          ),
                      ],
                      onChanged: (value) =>
                          setState(() => _selectedMatiere = value),
                    ),
                  const SizedBox(height: 16),
                ] else ...[
                  TextField(
                    controller: _libelleCtrl,
                    decoration: const InputDecoration(labelText: 'Libellé'),
                  ),
                  const SizedBox(height: 16),
                ],
                if (!_isModule || widget.moduleMatieres.isNotEmpty)
                  TextField(
                    controller: _coefficientCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Coefficient'),
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: const TextStyle(color: AppColors.danger),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                TextButton(
                  onPressed: _submitting
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Annuler'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: (!_isValid || _submitting) ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Enregistrer'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
