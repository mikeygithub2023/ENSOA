import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:sig_ensoa/core/erreurs.dart';
import 'package:sig_ensoa/core/theme.dart' hide AlertLevel, AlertLevelColor;
import '../../models/classe.dart';
import '../../models/cours.dart';
import '../../models/matiere.dart';
import '../matieres/providers/matieres_providers.dart';
import 'data/cours_repository.dart';
import 'providers/cours_providers.dart';

final _dateFmt = DateFormat('dd/MM/yyyy');

/// Saisie d'un cours, d'un exercice d'application ou d'un devoir.
///
/// La nature commande le reste du formulaire : un cours a une date de
/// séance, un devoir une échéance, et l'un comme l'autre peuvent porter un
/// document. Un exercice ou un devoir se rattache au cours qu'il applique —
/// facultatif, mais c'est ce lien qui fait la progression pédagogique.
Future<void> showRegisterCoursDialog(
  BuildContext context, {
  required Classe classe,
  required List<Cours> coursExistants,
  Cours? cours,
  TypeRessource typeInitial = TypeRessource.cours,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.all(24),
      child: _RegisterCoursDialog(
        classe: classe,
        coursExistants: coursExistants,
        cours: cours,
        typeInitial: typeInitial,
      ),
    ),
  );
}

class _RegisterCoursDialog extends ConsumerStatefulWidget {
  const _RegisterCoursDialog({
    required this.classe,
    required this.coursExistants,
    required this.typeInitial,
    this.cours,
  });

  final Classe classe;
  final List<Cours> coursExistants;
  final TypeRessource typeInitial;
  final Cours? cours;

  @override
  ConsumerState<_RegisterCoursDialog> createState() =>
      _RegisterCoursDialogState();
}

class _RegisterCoursDialogState extends ConsumerState<_RegisterCoursDialog> {
  late TypeRessource _type;
  late final TextEditingController _titreController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _dureeController;
  String? _matiereId;
  String? _coursParentId;
  DateTime? _dateSeance;
  DateTime? _dateRemise;

  Uint8List? _fichier;
  String? _fichierNom;
  bool _supprimerFichier = false;

  bool _submitting = false;
  String? _error;

  bool get _edition => widget.cours != null;

  @override
  void initState() {
    super.initState();
    final cours = widget.cours;
    _type = cours?.type ?? widget.typeInitial;
    _titreController = TextEditingController(text: cours?.titre);
    _descriptionController = TextEditingController(text: cours?.description);
    _dureeController = TextEditingController(
      text: cours?.dureeMinutes?.toString(),
    );
    _matiereId = cours?.matiereId;
    _coursParentId = cours?.coursId;
    _dateSeance = cours?.dateSeance ?? (cours == null ? DateTime.now() : null);
    _dateRemise = cours?.dateRemise;
    _fichierNom = cours?.fichierNom;
  }

  @override
  void dispose() {
    _titreController.dispose();
    _descriptionController.dispose();
    _dureeController.dispose();
    super.dispose();
  }

  Future<void> _choisirFichier() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null) return;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      setState(() => _error = 'Impossible de lire ce fichier.');
      return;
    }
    setState(() {
      _fichier = bytes;
      _fichierNom = file.name;
      _supprimerFichier = false;
      _error = null;
    });
  }

  Future<void> _choisirDate({required bool seance}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (seance ? _dateSeance : _dateRemise) ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
    );
    if (picked == null) return;
    setState(() {
      if (seance) {
        _dateSeance = picked;
      } else {
        _dateRemise = picked;
      }
    });
  }

  Future<void> _submit() async {
    final titre = _titreController.text.trim();
    if (titre.isEmpty) {
      setState(() => _error = 'Renseignez le titre.');
      return;
    }

    // Une durée illisible vaut mieux refusée qu'ignorée : l'instructeur
    // croirait avoir limité le devoir alors qu'il l'aurait laissé ouvert.
    int? duree;
    final dureeSaisie = _dureeController.text.trim();
    if (_type == TypeRessource.devoir && dureeSaisie.isNotEmpty) {
      duree = int.tryParse(dureeSaisie);
      if (duree == null || duree <= 0 || duree > 600) {
        setState(
          () => _error =
              'La durée doit être un nombre de minutes entre 1 et 600.',
        );
        return;
      }
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(coursRepositoryProvider);
    final draft = CoursDraft(
      divisionId: widget.classe.divisionId,
      classeId: widget.classe.id,
      type: _type,
      titre: titre,
      matiereId: _matiereId,
      coursId: _coursParentId,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      dateSeance: _dateSeance,
      dateRemise: _type == TypeRessource.devoir ? _dateRemise : null,
      dureeMinutes: duree,
      fichier: _fichier,
      fichierNom: _fichierNom,
      supprimerFichier: _supprimerFichier,
    );
    try {
      final cours = widget.cours;
      if (cours == null) {
        await repository.createCours(draft);
      } else {
        await repository.updateCours(cours.id, draft);
      }
      ref.invalidate(coursByClasseProvider(widget.classe.id));
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            cours == null
                ? 'Enregistré : ${_type.singulier}.'
                : 'Modification enregistrée.',
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final width = screenSize.width - 48 < 640 ? screenSize.width - 48 : 640.0;
    final height = screenSize.height - 48 < 760
        ? screenSize.height - 48
        : 760.0;
    final matieres =
        ref.watch(matieresCatalogueProvider).value ?? const <Matiere>[];
    final coursDisponibles = widget.coursExistants
        .where((c) => c.type == TypeRessource.cours && c.id != widget.cours?.id)
        .toList();

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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _edition
                            ? 'Modifier — ${_type.singulier}'
                            : 'Nouveau ${_type.singulier}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      Text(
                        '${widget.classe.nom} (${widget.classe.type.label})',
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
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SegmentedButton<TypeRessource>(
                    segments: [
                      for (final type in TypeRessource.values)
                        ButtonSegment(value: type, label: Text(type.label)),
                    ],
                    selected: {_type},
                    onSelectionChanged: (selection) => setState(() {
                      _type = selection.first;
                      if (_type == TypeRessource.cours) _coursParentId = null;
                      if (_type != TypeRessource.devoir) _dateRemise = null;
                    }),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _type.description,
                    style: const TextStyle(
                      color: AppColors.inkMuted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _titreController,
                    decoration: const InputDecoration(
                      labelText: 'Titre',
                      hintText: 'Ex. Topographie — lecture de carte',
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _matiereId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Matière (facultatif)',
                      suffixIcon: _matiereId == null
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              tooltip: 'Effacer',
                              onPressed: () =>
                                  setState(() => _matiereId = null),
                            ),
                    ),
                    items: [
                      for (final matiere in matieres)
                        DropdownMenuItem(
                          value: matiere.id,
                          child: Text(matiere.nom),
                        ),
                    ],
                    onChanged: (value) => setState(() => _matiereId = value),
                  ),
                  if (_type != TypeRessource.cours) ...[
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _coursParentId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Rattaché au cours (facultatif)',
                        suffixIcon: _coursParentId == null
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                tooltip: 'Effacer',
                                onPressed: () =>
                                    setState(() => _coursParentId = null),
                              ),
                      ),
                      items: [
                        for (final cours in coursDisponibles)
                          DropdownMenuItem(
                            value: cours.id,
                            child: Text(cours.titre),
                          ),
                      ],
                      onChanged: (value) =>
                          setState(() => _coursParentId = value),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _ChampDate(
                          label: _type == TypeRessource.cours
                              ? 'Date de la séance'
                              : 'Date de remise aux apprenants',
                          value: _dateSeance,
                          onChoisir: () => _choisirDate(seance: true),
                          onEffacer: () => setState(() => _dateSeance = null),
                        ),
                      ),
                      if (_type == TypeRessource.devoir) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ChampDate(
                            label: 'Échéance',
                            value: _dateRemise,
                            onChoisir: () => _choisirDate(seance: false),
                            onEffacer: () => setState(() => _dateRemise = null),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _dureeController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Temps imparti (minutes)',
                              hintText: 'Sans limite si vide',
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (_type == TypeRessource.devoir) ...[
                    const SizedBox(height: 6),
                    const Text(
                      'Le compte à rebours démarre quand l\'apprenant ouvre '
                      'le sujet, et se poursuit côté serveur : reculer '
                      'l\'horloge de son téléphone ne lui rend pas de temps. '
                      'À zéro, la copie part avec les réponses cochées.',
                      style: TextStyle(fontSize: 12, color: AppColors.inkMuted),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description / consignes (facultatif)',
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 20),
                  _ChampDocument(
                    nom: _supprimerFichier ? null : _fichierNom,
                    modifie: _fichier != null,
                    onChoisir: _choisirFichier,
                    onRetirer: () => setState(() {
                      _fichier = null;
                      _fichierNom = null;
                      _supprimerFichier = true;
                    }),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
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
                  onPressed: _submitting ? null : _submit,
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

class _ChampDate extends StatelessWidget {
  const _ChampDate({
    required this.label,
    required this.value,
    required this.onChoisir,
    required this.onEffacer,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onChoisir;
  final VoidCallback onEffacer;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onChoisir,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: value == null
              ? const Icon(Icons.calendar_today_outlined, size: 18)
              : IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  tooltip: 'Effacer',
                  onPressed: onEffacer,
                ),
        ),
        child: Text(value == null ? '' : _dateFmt.format(value!)),
      ),
    );
  }
}

/// Document joint — n'importe quel format : le support d'un cours peut être
/// un PDF, un traitement de texte, une présentation ou un scan.
class _ChampDocument extends StatelessWidget {
  const _ChampDocument({
    required this.nom,
    required this.modifie,
    required this.onChoisir,
    required this.onRetirer,
  });

  final String? nom;
  final bool modifie;
  final VoidCallback onChoisir;
  final VoidCallback onRetirer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.blueMist,
        borderRadius: BorderRadius.circular(AppRadii.control),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.attach_file, size: 20, color: AppColors.blueDeep),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nom ?? 'Aucun document joint',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: nom == null ? AppColors.inkMuted : AppColors.ink,
                  ),
                ),
                if (modifie)
                  const Text(
                    'Sera déposé à l\'enregistrement.',
                    style: TextStyle(color: AppColors.inkMuted, fontSize: 12),
                  ),
              ],
            ),
          ),
          if (nom != null)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              tooltip: 'Retirer le document',
              onPressed: onRetirer,
            ),
          OutlinedButton.icon(
            onPressed: onChoisir,
            icon: const Icon(Icons.upload_file, size: 18),
            label: Text(nom == null ? 'Joindre' : 'Remplacer'),
          ),
        ],
      ),
    );
  }
}
