import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sig_ensoa/core/erreurs.dart';
import 'package:sig_ensoa/core/theme.dart' hide AlertLevel, AlertLevelColor;
import '../../models/apprenant.dart';
import '../../models/visite_medicale.dart';
import 'data/visites_medicales_repository.dart';
import 'providers/visites_medicales_providers.dart';

/// Ajout d'un apprenant à une visite médicale (ou modification de son
/// examen, si [examen] est fourni). Le formulaire reprend le cachet
/// d'examen apposé au dossier médical : mensurations, constantes, acuité
/// visuelle et auditive, analyse d'urine, examen clinique, profil SIGYCOP
/// et conclusion d'aptitude. [apprenants] ne contient, à l'ajout, que les
/// apprenants de la classe/stage convoquée qui ne sont pas encore passés.
Future<void> showRegisterVisiteApprenantDialog(
  BuildContext context, {
  required String visiteId,
  required List<Apprenant> apprenants,
  VisiteMedicaleApprenant? examen,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.all(24),
      child: _RegisterVisiteApprenantDialog(
        visiteId: visiteId,
        apprenants: apprenants,
        examen: examen,
      ),
    ),
  );
}

class _RegisterVisiteApprenantDialog extends ConsumerStatefulWidget {
  const _RegisterVisiteApprenantDialog({
    required this.visiteId,
    required this.apprenants,
    required this.examen,
  });

  final String visiteId;
  final List<Apprenant> apprenants;
  final VisiteMedicaleApprenant? examen;

  @override
  ConsumerState<_RegisterVisiteApprenantDialog> createState() =>
      _RegisterVisiteApprenantDialogState();
}

class _RegisterVisiteApprenantDialogState
    extends ConsumerState<_RegisterVisiteApprenantDialog> {
  late Apprenant? _apprenant = _initialApprenant();
  late VisiteResultat _resultat =
      widget.examen?.resultat ?? VisiteResultat.apte;
  late final _tailleCtrl = _controllerFor(widget.examen?.tailleCm);
  late final _poidsCtrl = _controllerFor(widget.examen?.poidsKg);
  late final _ptmCtrl = _controllerFor(widget.examen?.ptmCm);
  late final _tensionCtrl = _controllerFor(widget.examen?.tensionArterielle);
  late final _poulsCtrl = _controllerFor(widget.examen?.pouls);
  late final _vodCtrl = _controllerFor(widget.examen?.vod);
  late final _vogCtrl = _controllerFor(widget.examen?.vog);
  late final _aodCtrl = _controllerFor(widget.examen?.aod);
  late final _aogCtrl = _controllerFor(widget.examen?.aog);
  late final _urineSucreCtrl = _controllerFor(widget.examen?.urineSucre);
  late final _urineAlbumineCtrl = _controllerFor(widget.examen?.urineAlbumine);
  late final _cliniqueCtrl = _controllerFor(widget.examen?.clinique);
  late final _observationsCtrl = _controllerFor(widget.examen?.observations);
  late final Map<SigycopLettre, int> _sigycop = {...?widget.examen?.sigycop};
  bool _submitting = false;
  String? _error;

  bool get _isEdition => widget.examen != null;

  bool get _isValid => _apprenant != null;

  TextEditingController _controllerFor(Object? value) =>
      TextEditingController(text: value?.toString() ?? '');

  Apprenant? _initialApprenant() {
    final examen = widget.examen;
    if (examen == null) return null;
    for (final apprenant in widget.apprenants) {
      if (apprenant.id == examen.apprenantId) return apprenant;
    }
    return null;
  }

  @override
  void dispose() {
    for (final controller in [
      _tailleCtrl,
      _poidsCtrl,
      _ptmCtrl,
      _tensionCtrl,
      _poulsCtrl,
      _vodCtrl,
      _vogCtrl,
      _aodCtrl,
      _aogCtrl,
      _urineSucreCtrl,
      _urineAlbumineCtrl,
      _cliniqueCtrl,
      _observationsCtrl,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  num? _nombre(TextEditingController controller) =>
      num.tryParse(controller.text.trim().replaceAll(',', '.'));

  String? _texte(TextEditingController controller) {
    final valeur = controller.text.trim();
    return valeur.isEmpty ? null : valeur;
  }

  /// Indice de Pignet = taille - (poids + périmètre thoracique moyen). La
  /// base le recalcule à l'enregistrement ; il n'est affiché ici que pour
  /// que le médecin le voie pendant la saisie.
  num? get _pignet {
    final taille = _nombre(_tailleCtrl);
    final poids = _nombre(_poidsCtrl);
    final ptm = _nombre(_ptmCtrl);
    if (taille == null || poids == null || ptm == null) return null;
    return taille - (poids + ptm);
  }

  Future<void> _submit() async {
    final apprenant = _apprenant;
    if (apprenant == null) return;

    setState(() {
      _submitting = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(visitesMedicalesRepositoryProvider);
    final draft = VisiteApprenantDraft(
      apprenantId: apprenant.id,
      resultat: _resultat,
      observations: _texte(_observationsCtrl),
      tailleCm: _nombre(_tailleCtrl),
      poidsKg: _nombre(_poidsCtrl),
      ptmCm: _nombre(_ptmCtrl),
      tensionArterielle: _texte(_tensionCtrl),
      pouls: int.tryParse(_poulsCtrl.text.trim()),
      vod: _texte(_vodCtrl),
      vog: _texte(_vogCtrl),
      aod: _texte(_aodCtrl),
      aog: _texte(_aogCtrl),
      urineSucre: _texte(_urineSucreCtrl),
      urineAlbumine: _texte(_urineAlbumineCtrl),
      clinique: _texte(_cliniqueCtrl),
      sigycop: _sigycop,
    );
    try {
      final examen = widget.examen;
      if (examen == null) {
        await repository.addApprenant(widget.visiteId, draft);
      } else {
        await repository.updateApprenant(examen.id, draft);
      }
      ref.invalidate(visiteApprenantsProvider(widget.visiteId));
      ref.invalidate(visitesEffectifsProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _isEdition ? 'Examen modifié.' : 'Apprenant ajouté à la visite.',
          ),
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
    final width = screenSize.width - 48 < 620 ? screenSize.width - 48 : 620.0;
    final height = screenSize.height - 48 < 780
        ? screenSize.height - 48
        : 780.0;
    final pignet = _pignet;

    return SizedBox(
      width: width,
      height: height,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _isEdition
                        ? 'Modifier l\'examen'
                        : 'Ajouter un apprenant à la visite',
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
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // L'apprenant d'un examen déjà enregistré ne change plus :
                  // le remplacer reviendrait à créer un autre passage.
                  if (_isEdition)
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Élève / Stagiaire',
                      ),
                      child: Text(
                        _apprenant?.nomComplet ?? 'Apprenant inconnu',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    )
                  else
                    DropdownButtonFormField<Apprenant>(
                      initialValue: _apprenant,
                      decoration: const InputDecoration(
                        labelText: 'Élève / Stagiaire',
                      ),
                      isExpanded: true,
                      items: [
                        for (final a in widget.apprenants)
                          DropdownMenuItem(value: a, child: Text(a.nomComplet)),
                      ],
                      onChanged: (value) => setState(() => _apprenant = value),
                    ),
                  const _FormSectionLabel('Mensurations'),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _tailleCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Taille (cm)',
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _poidsCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Poids (kg)',
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _ptmCtrl,
                          decoration: const InputDecoration(
                            labelText: 'PTM (cm)',
                            helperText: 'Périmètre thoracique moyen',
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'PIGNET',
                      helperText: 'Calculé : taille − (poids + PTM)',
                    ),
                    child: Text(
                      pignet != null ? '$pignet' : '—',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const _FormSectionLabel('Constantes'),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _tensionCtrl,
                          decoration: const InputDecoration(
                            labelText: 'T.A',
                            hintText: 'Ex. 12/8',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _poulsCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Pouls (bpm)',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const _FormSectionLabel('Vision et audition'),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _vodCtrl,
                          decoration: const InputDecoration(
                            labelText: 'VOD',
                            helperText: 'Vision œil droit',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _vogCtrl,
                          decoration: const InputDecoration(
                            labelText: 'VOG',
                            helperText: 'Vision œil gauche',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _aodCtrl,
                          decoration: const InputDecoration(
                            labelText: 'AOD',
                            helperText: 'Audition oreille droite',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _aogCtrl,
                          decoration: const InputDecoration(
                            labelText: 'AOG',
                            helperText: 'Audition oreille gauche',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const _FormSectionLabel('Urines'),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _urineSucreCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Sucre (S)',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _urineAlbumineCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Albumine (A)',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const _FormSectionLabel('Clinique'),
                  TextField(
                    controller: _cliniqueCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Examen clinique',
                      hintText: 'Ex. RAS, souffle systolique...',
                    ),
                    maxLines: 3,
                  ),
                  const _FormSectionLabel('SIGYCOP'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final lettre in SigycopLettre.values)
                        SizedBox(
                          width: 78,
                          child: DropdownButtonFormField<int?>(
                            initialValue: _sigycop[lettre],
                            decoration: InputDecoration(
                              labelText: lettre.lettre,
                              isDense: true,
                            ),
                            isExpanded: true,
                            items: [
                              const DropdownMenuItem<int?>(
                                value: null,
                                child: Text('—'),
                              ),
                              for (var cote = 1; cote <= 6; cote++)
                                DropdownMenuItem<int?>(
                                  value: cote,
                                  child: Text('$cote'),
                                ),
                            ],
                            onChanged: (cote) => setState(() {
                              if (cote == null) {
                                _sigycop.remove(lettre);
                              } else {
                                _sigycop[lettre] = cote;
                              }
                            }),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    SigycopLettre.values
                        .map((l) => '${l.lettre} : ${l.description}')
                        .join(' · '),
                    style: const TextStyle(
                      color: AppColors.inkMuted,
                      fontSize: 12,
                    ),
                  ),
                  const _FormSectionLabel('Conclusion'),
                  DropdownButtonFormField<VisiteResultat>(
                    initialValue: _resultat,
                    decoration: const InputDecoration(labelText: 'Résultat'),
                    isExpanded: true,
                    items: [
                      for (final resultat in VisiteResultat.values)
                        DropdownMenuItem(
                          value: resultat,
                          child: Text(resultat.label),
                        ),
                    ],
                    onChanged: (value) =>
                        setState(() => _resultat = value ?? _resultat),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _observationsCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Observations (facultatif)',
                      hintText:
                          'Ex. tension à surveiller, contre-visite dans 15 jours...',
                    ),
                    maxLines: 3,
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

/// Intertitre du formulaire — reprend les blocs du cachet d'examen pour que
/// la saisie suive l'ordre du document papier.
class _FormSectionLabel extends StatelessWidget {
  const _FormSectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          color: AppColors.ink,
          fontSize: 13,
        ),
      ),
    );
  }
}
