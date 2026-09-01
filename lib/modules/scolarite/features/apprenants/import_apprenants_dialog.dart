import 'dart:typed_data';

import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sig_ensoa/core/erreurs.dart';
import 'package:sig_ensoa/core/theme.dart' hide AlertLevel, AlertLevelColor;
import '../../models/apprenant.dart';
import '../../models/classe.dart';
import '../../models/division.dart';
import '../../shared/widgets/common.dart';
import 'data/apprenants_repository.dart';
import 'grade_defaults.dart';
import 'providers/apprenants_providers.dart';

class _TemplateColumn {
  const _TemplateColumn(this.key, this.label, this.format, this.exemple);
  final String key;
  final String label;
  final String format;
  final String exemple;
}

/// Ordre exact des colonnes attendu dans la feuille à importer. Les lignes
/// sont lues par position (pas par nom d'en-tête) : les utilisateurs doivent
/// respecter cet ordre. Le type, la division et la classe/stage ne sont pas
/// des colonnes : toutes les lignes importées sont rattachées à la classe/
/// stage depuis laquelle l'import est lancé. Les autres rubriques de la
/// fiche signalétique (filiation, urgence, santé, formation civile) se
/// complètent ensuite via la fiche de l'apprenant.
///
/// La colonne Grade n'existe que pour un stage : pour une classe (élève),
/// le grade est déduit automatiquement de la classe (voir
/// `grade_defaults.dart`), donc pas besoin de la faire saisir.
List<_TemplateColumn> _templateColumnsFor(ClasseType type) {
  const matricule = _TemplateColumn(
    'matricule',
    'Matricule',
    'Optionnel, unique si renseigné',
    'M-2024-001',
  );
  const grade = _TemplateColumn('grade', 'Grade', 'Texte libre', 'Sergent');
  const nom = _TemplateColumn('nom', 'Nom', 'Obligatoire', 'KOUAME');
  const prenoms = _TemplateColumn(
    'prenoms',
    'Prénoms',
    'Obligatoire',
    'Yao Jean',
  );
  // Le sexe décide du barème appliqué aux épreuves sportives : sans lui,
  // une performance reste sans note. Il se saisit donc dès l'import.
  const sexe = _TemplateColumn('sexe', 'Sexe', 'M ou F', 'M');
  const telephone = _TemplateColumn(
    'telephone',
    'Téléphone',
    'Texte libre',
    '+225 07 00 00 00 00',
  );
  const dateNaissance = _TemplateColumn(
    'date_naissance',
    'Date de naissance',
    'JJ/MM/AAAA',
    '12/05/2000',
  );
  const lieuNaissance = _TemplateColumn(
    'lieu_naissance',
    'Lieu de naissance',
    'Texte libre',
    'Abidjan',
  );
  return type == ClasseType.stage
      ? [
          matricule,
          grade,
          nom,
          prenoms,
          sexe,
          telephone,
          dateNaissance,
          lieuNaissance,
        ]
      : [
          matricule,
          nom,
          prenoms,
          sexe,
          telephone,
          dateNaissance,
          lieuNaissance,
        ];
}

Future<void> showImportApprenantsDialog(
  BuildContext context, {
  required Division division,
  required Classe classe,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.all(24),
      child: _ImportApprenantsDialog(division: division, classe: classe),
    ),
  );
}

class _ImportRow {
  _ImportRow({
    required this.rowNumber,
    required this.values,
    required this.errors,
  });

  final int rowNumber;
  final List<String> values;
  final List<String> errors;

  bool get isValid => errors.isEmpty;
}

/// Un groupe de lignes/apprenants partageant le même nom, prénom et date de
/// naissance dans la classe/stage ciblé(e) — signalé à l'utilisateur avant
/// l'enregistrement pour décision (importer quand même ou exclure).
class _DuplicateGroup {
  _DuplicateGroup({
    required this.label,
    required this.existing,
    required this.rows,
  });

  final String label;
  final List<Apprenant> existing;
  final List<_ImportRow> rows;
}

class _ImportApprenantsDialog extends ConsumerStatefulWidget {
  const _ImportApprenantsDialog({required this.division, required this.classe});

  final Division division;
  final Classe classe;

  @override
  ConsumerState<_ImportApprenantsDialog> createState() =>
      _ImportApprenantsDialogState();
}

class _ImportApprenantsDialogState
    extends ConsumerState<_ImportApprenantsDialog> {
  String? _fileName;
  List<_ImportRow>? _rows;
  String? _parseError;
  bool _loading = false;
  bool _submitting = false;

  int get _validCount => _rows?.where((r) => r.isValid).length ?? 0;
  int get _errorCount => (_rows?.length ?? 0) - _validCount;

  List<_TemplateColumn> get _templateColumns =>
      _templateColumnsFor(widget.classe.type);

  int _idx(String key) => _templateColumns.indexWhere((c) => c.key == key);

  Future<void> _downloadTemplate() async {
    final workbook = Excel.createExcel();
    final sheet = workbook[workbook.sheets.keys.first];
    sheet.appendRow([for (final c in _templateColumns) TextCellValue(c.label)]);
    final bytes = workbook.encode();
    if (bytes == null) return;

    final messenger = ScaffoldMessenger.of(context);
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Enregistrer le modèle Excel',
      fileName: 'modele_import_apprenants.xlsx',
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      bytes: Uint8List.fromList(bytes),
    );
    if (path == null || !mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text('Modèle enregistré : $path'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Future<void> _pickFile() async {
    setState(() {
      _parseError = null;
      _rows = null;
    });
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );
    if (result == null) return;

    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      setState(() => _parseError = 'Impossible de lire ce fichier.');
      return;
    }

    setState(() => _loading = true);
    try {
      final workbook = Excel.decodeBytes(bytes);
      if (workbook.tables.isEmpty) {
        setState(() {
          _parseError = 'Le classeur ne contient aucune feuille.';
          _loading = false;
        });
        return;
      }
      final sheet = workbook.tables.values.first;
      final allRows = sheet.rows;
      final dataRows = allRows.length > 1
          ? allRows.sublist(1)
          : <List<Data?>>[];

      final parsed = <_ImportRow>[];
      for (var i = 0; i < dataRows.length; i++) {
        final raw = dataRows[i];
        final values = List.generate(
          _templateColumns.length,
          (col) => col < raw.length ? _cellText(raw[col]) : '',
        );
        if (values.every((v) => v.trim().isEmpty)) continue;
        parsed.add(
          _ImportRow(
            rowNumber: i + 2,
            values: values,
            errors: _validateRow(values),
          ),
        );
      }

      setState(() {
        _fileName = file.name;
        _rows = parsed;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _parseError = 'Fichier invalide : ${messageErreur(e)}';
        _loading = false;
      });
    }
  }

  List<String> _validateRow(List<String> values) {
    final errors = <String>[];

    if (widget.classe.type == ClasseType.stage &&
        values[_idx('matricule')].trim().isEmpty) {
      errors.add('Matricule manquant');
    }
    if (values[_idx('nom')].trim().isEmpty) errors.add('Nom manquant');
    if (values[_idx('prenoms')].trim().isEmpty) {
      errors.add('Prénoms manquants');
    }

    final dateNaissance = values[_idx('date_naissance')].trim();
    if (dateNaissance.isNotEmpty && !_isValidDate(dateNaissance)) {
      errors.add('Date de naissance invalide (attendu JJ/MM/AAAA)');
    }

    return errors;
  }

  bool _isValidDate(String value) {
    final m = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(value);
    if (m == null) return false;
    final day = int.parse(m.group(1)!);
    final month = int.parse(m.group(2)!);
    if (month < 1 || month > 12 || day < 1 || day > 31) return false;
    return true;
  }

  DateTime? _parseDate(String value) {
    if (!_isValidDate(value.trim())) return null;
    final m = RegExp(
      r'^(\d{1,2})/(\d{1,2})/(\d{4})$',
    ).firstMatch(value.trim())!;
    return DateTime(
      int.parse(m.group(3)!),
      int.parse(m.group(2)!),
      int.parse(m.group(1)!),
    );
  }

  String? _emptyToNull(String value) =>
      value.trim().isEmpty ? null : value.trim();

  /// Le sexe attendu est « M » ou « F ». On accepte les formes courantes
  /// — « m », « Masculin », « H », « Homme », « f », « Féminin » — parce
  /// qu'un fichier vient rarement normalisé, et on laisse vide plutôt que
  /// de trancher devant une valeur qu'on ne comprend pas : mieux vaut une
  /// fiche à compléter qu'un barème appliqué au mauvais sexe.
  String? _parseSexe(String value) {
    final v = value.trim().toLowerCase();
    if (v.isEmpty) return null;
    if (v.startsWith('m') || v.startsWith('h')) return 'M';
    if (v.startsWith('f')) return 'F';
    return null;
  }

  /// Retire tous les espaces du matricule (pas seulement en début/fin) pour
  /// que la recherche par matricule ne dépende pas de la façon dont il a
  /// été saisi dans le fichier Excel.
  String? _normalizeMatricule(String value) {
    final stripped = value.replaceAll(RegExp(r'\s+'), '');
    return stripped.isEmpty ? null : stripped;
  }

  ApprenantDraft _draftFromRow(_ImportRow row) {
    final isEleve = widget.classe.type == ClasseType.phase;
    return ApprenantDraft(
      divisionId: widget.division.id,
      classeId: widget.classe.id,
      type: isEleve ? 'eleve' : 'stagiaire',
      matricule: _normalizeMatricule(row.values[_idx('matricule')]),
      nom: row.values[_idx('nom')].trim(),
      prenom: row.values[_idx('prenoms')].trim(),
      grade: isEleve
          ? defaultGradeForClasse(widget.classe.nom)
          : _emptyToNull(row.values[_idx('grade')]),
      sexe: _parseSexe(row.values[_idx('sexe')]),
      telephone: _emptyToNull(row.values[_idx('telephone')]),
      dateNaissance: _parseDate(row.values[_idx('date_naissance')]),
      lieuNaissance: _emptyToNull(row.values[_idx('lieu_naissance')]),
    );
  }

  String _dupKey(String nom, String prenom, DateTime date) {
    return '${nom.trim().toLowerCase()}|${prenom.trim().toLowerCase()}|${date.year}-${date.month}-${date.day}';
  }

  /// Compare les lignes valides du fichier — entre elles et avec les
  /// apprenants déjà enregistrés dans la classe/stage ciblé(e) — sur
  /// nom + prénom + date de naissance.
  Future<List<_DuplicateGroup>> _detectDuplicates(
    List<_ImportRow> validRows,
  ) async {
    final existingApprenants = await ref
        .read(apprenantsRepositoryProvider)
        .fetchByClasse(widget.classe.id)
        .timeout(const Duration(seconds: 20));

    final existingByKey = <String, List<Apprenant>>{};
    for (final a in existingApprenants) {
      final date = a.dateNaissance;
      if (date == null) continue;
      existingByKey
          .putIfAbsent(_dupKey(a.nom, a.prenom, date), () => [])
          .add(a);
    }

    final idxNom = _idx('nom');
    final idxPrenoms = _idx('prenoms');
    final idxDateNaissance = _idx('date_naissance');

    final rowsByKey = <String, List<_ImportRow>>{};
    for (final row in validRows) {
      final date = _parseDate(row.values[idxDateNaissance]);
      if (date == null) continue;
      rowsByKey
          .putIfAbsent(
            _dupKey(row.values[idxNom], row.values[idxPrenoms], date),
            () => [],
          )
          .add(row);
    }

    final groups = <_DuplicateGroup>[];
    for (final entry in rowsByKey.entries) {
      final existing = existingByKey[entry.key] ?? const <Apprenant>[];
      if (existing.isEmpty && entry.value.length <= 1) continue;
      final sample = entry.value.first;
      groups.add(
        _DuplicateGroup(
          label:
              '${sample.values[idxNom].trim()} ${sample.values[idxPrenoms].trim()} — ${sample.values[idxDateNaissance].trim()}',
          existing: existing,
          rows: entry.value,
        ),
      );
    }
    return groups;
  }

  Future<Set<int>?> _showDuplicateReviewDialog(
    List<_DuplicateGroup> groups,
  ) async {
    final forceImport = <int>{};
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          scrollable: true,
          title: Text('Doublons potentiels détectés (${groups.length})'),
          content: SizedBox(
            width: 560,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 440),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Ces lignes partagent nom, prénom et date de naissance avec un '
                      'apprenant déjà présent dans cette phase ou ce stage, ou entre elles. '
                      'Décidez lesquelles importer quand même.',
                      style: TextStyle(color: AppColors.inkMuted, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    for (final group in groups) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.blueMist,
                          borderRadius: BorderRadius.circular(AppRadii.control),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              group.label,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (group.existing.isNotEmpty) ...[
                              const Text(
                                'Déjà présent(s) dans cette phase ou ce stage :',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.inkMuted,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              for (final a in group.existing)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    '• ${a.nomComplet} — ${a.matricule ?? "sans matricule"} — ${a.statut.label}',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                              const SizedBox(height: 8),
                            ],
                            if (group.rows.length > 1)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  '${group.rows.length} lignes du fichier partagent ces informations.',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.warning,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            for (final row in group.rows)
                              CheckboxListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                title: Text(
                                  'Ligne ${row.rowNumber} — importer quand même',
                                  style: const TextStyle(fontSize: 13),
                                ),
                                value: forceImport.contains(row.rowNumber),
                                onChanged: (checked) => setDialogState(() {
                                  if (checked == true) {
                                    forceImport.add(row.rowNumber);
                                  } else {
                                    forceImport.remove(row.rowNumber);
                                  }
                                }),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler l\'import'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Continuer'),
            ),
          ],
        ),
      ),
    );
    return proceed == true ? forceImport : null;
  }

  Future<void> _reviewAndSubmit() async {
    final validRows = (_rows ?? const <_ImportRow>[])
        .where((r) => r.isValid)
        .toList();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _submitting = true);

    try {
      final duplicateGroups = await _detectDuplicates(validRows);
      if (!mounted) return;

      var rowsToImport = validRows;
      if (duplicateGroups.isNotEmpty) {
        final forceImport = await _showDuplicateReviewDialog(duplicateGroups);
        if (!mounted) return;
        if (forceImport == null) {
          setState(() => _submitting = false);
          return;
        }
        final excludedRowNumbers = <int>{
          for (final g in duplicateGroups)
            for (final r in g.rows)
              if (!forceImport.contains(r.rowNumber)) r.rowNumber,
        };
        rowsToImport = validRows
            .where((r) => !excludedRowNumbers.contains(r.rowNumber))
            .toList();
      }

      if (rowsToImport.isEmpty) {
        setState(() => _submitting = false);
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Aucune ligne à importer.'),
            backgroundColor: AppColors.warning,
          ),
        );
        return;
      }

      final result = await ref
          .read(apprenantsRepositoryProvider)
          .importApprenants([
            for (final row in rowsToImport) _draftFromRow(row),
          ]);
      ref.invalidate(apprenantsListProvider);

      if (!mounted) return;
      Navigator.of(context).pop();
      final hasFailures = result.failed.isNotEmpty;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            hasFailures
                ? '${result.inserted} ligne(s) importée(s), ${result.failed.length} échec(s) : ${result.failed.join(' · ')}'
                : '${result.inserted} ligne(s) importée(s) avec succès.',
          ),
          backgroundColor: hasFailures ? AppColors.warning : AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Erreur lors de l\'import : $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final width = screenSize.width - 48 < 960 ? screenSize.width - 48 : 960.0;
    final height = screenSize.height - 48 < 760
        ? screenSize.height - 48
        : 760.0;

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
                    widget.classe.type == ClasseType.phase
                        ? 'Importer des élèves (Excel)'
                        : 'Importer des stagiaires (Excel)',
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
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
            child: _ContextBanner(
              division: widget.division,
              classe: widget.classe,
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'La feuille doit contenir une ligne d\'en-tête suivie des données, avec les colonnes '
                    'dans l\'ordre exact ci-dessous (les lignes sont lues par position, pas par nom d\'en-tête).',
                    style: TextStyle(color: AppColors.inkMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  _FormatTable(
                    classe: widget.classe,
                    onDownloadTemplate: _downloadTemplate,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      FilledButton.icon(
                        onPressed: _loading ? null : _pickFile,
                        icon: const Icon(Icons.upload_file_outlined, size: 18),
                        label: Text(
                          _fileName == null
                              ? 'Choisir un fichier Excel (.xlsx)'
                              : 'Changer de fichier',
                        ),
                      ),
                      if (_fileName != null) ...[
                        const SizedBox(width: 12),
                        Text(
                          _fileName!,
                          style: const TextStyle(color: AppColors.inkMuted),
                        ),
                      ],
                      if (_loading) ...[
                        const SizedBox(width: 12),
                        const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ],
                    ],
                  ),
                  if (_parseError != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _parseError!,
                      style: const TextStyle(color: AppColors.danger),
                    ),
                  ],
                  if (_rows != null) ...[
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        const Text(
                          'Aperçu',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(width: 16),
                        StatusChip(
                          label: '$_validCount valide(s)',
                          level: AlertLevel.success,
                        ),
                        const SizedBox(width: 8),
                        if (_errorCount > 0)
                          StatusChip(
                            label: '$_errorCount en erreur',
                            level: AlertLevel.critical,
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _rows!.isEmpty
                        ? const EmptyState(
                            message:
                                'Aucune ligne de données trouvée dans ce fichier.',
                            icon: Icons.table_rows_outlined,
                          )
                        : Card(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(
                                  AppColors.blueMist,
                                ),
                                columns: [
                                  const DataColumn(label: Text('Ligne')),
                                  const DataColumn(label: Text('Statut')),
                                  for (final c in _templateColumns)
                                    DataColumn(label: Text(c.label)),
                                ],
                                rows: [
                                  for (final row in _rows!)
                                    DataRow(
                                      color: row.isValid
                                          ? null
                                          : WidgetStateProperty.all(
                                              AppColors.danger.withValues(
                                                alpha: 0.06,
                                              ),
                                            ),
                                      cells: [
                                        DataCell(Text('${row.rowNumber}')),
                                        DataCell(
                                          row.isValid
                                              ? const Icon(
                                                  Icons.check_circle,
                                                  color: AppColors.success,
                                                  size: 18,
                                                )
                                              : Tooltip(
                                                  message: row.errors.join(
                                                    '\n',
                                                  ),
                                                  child: const Icon(
                                                    Icons.error,
                                                    color: AppColors.danger,
                                                    size: 18,
                                                  ),
                                                ),
                                        ),
                                        for (final v in row.values)
                                          DataCell(Text(v)),
                                      ],
                                    ),
                                ],
                              ),
                            ),
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
                  child: const Text('Fermer'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: (_validCount == 0 || _submitting)
                      ? null
                      : _reviewAndSubmit,
                  child: _submitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Valider l\'aperçu'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Rappelle la division et la classe/stage auxquels toutes les lignes
/// importées seront rattachées — non modifiable.
class _ContextBanner extends StatelessWidget {
  const _ContextBanner({required this.division, required this.classe});

  final Division division;
  final Classe classe;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
              '${classe.type == ClasseType.phase ? "Classe" : "Stage"} : ${classe.nom} · ${division.nom}',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.blueDeep,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Format attendu de la feuille à importer, présenté comme un tableau dont
/// l'en-tête reprend exactement les rubriques (dans l'ordre attendu), avec
/// une ligne de format et une ligne d'exemple sous chaque colonne.
class _FormatTable extends StatelessWidget {
  const _FormatTable({required this.classe, required this.onDownloadTemplate});

  final Classe classe;
  final VoidCallback onDownloadTemplate;

  List<_TemplateColumn> get _templateColumns =>
      _templateColumnsFor(classe.type);

  String _formatFor(int index, _TemplateColumn c) {
    if (index == 0) {
      return classe.type == ClasseType.stage
          ? 'Obligatoire, unique'
          : 'Optionnel, unique si renseigné';
    }
    return c.format;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'Format de la feuille à importer',
              trailing: OutlinedButton.icon(
                onPressed: onDownloadTemplate,
                icon: const Icon(Icons.download_outlined, size: 16),
                label: const Text('Télécharger le modèle'),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Les colonnes de votre fichier doivent suivre cet ordre et ces en-têtes.',
              style: TextStyle(color: AppColors.inkMuted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.control),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 20,
                  horizontalMargin: 16,
                  dataRowMinHeight: 44,
                  dataRowMaxHeight: 44,
                  headingRowHeight: 52,
                  border: TableBorder(
                    horizontalInside: const BorderSide(color: AppColors.border),
                    verticalInside: const BorderSide(color: AppColors.border),
                  ),
                  headingRowColor: WidgetStateProperty.all(
                    AppColors.blueDeep.withValues(alpha: 0.08),
                  ),
                  columns: [
                    const DataColumn(label: SizedBox(width: 96)),
                    for (var i = 0; i < _templateColumns.length; i++)
                      DataColumn(
                        label: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${i + 1}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.blue,
                              ),
                            ),
                            Text(
                              _templateColumns[i].label,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppColors.navy,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                  rows: [
                    DataRow(
                      cells: [
                        const DataCell(
                          _RowTag(label: 'FORMAT', color: AppColors.inkMuted),
                        ),
                        for (var i = 0; i < _templateColumns.length; i++)
                          DataCell(
                            Text(
                              _formatFor(i, _templateColumns[i]),
                              style: const TextStyle(
                                color: AppColors.inkMuted,
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                      ],
                    ),
                    DataRow(
                      cells: [
                        const DataCell(
                          _RowTag(label: 'EXEMPLE', color: AppColors.success),
                        ),
                        for (final c in _templateColumns)
                          DataCell(
                            Text(
                              c.exemple,
                              style: const TextStyle(
                                color: AppColors.ink,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Petite étiquette colorée identifiant le type de ligne (Format / Exemple),
/// lisible même en scrollant horizontalement dans le tableau.
class _RowTag extends StatelessWidget {
  const _RowTag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

String _cellText(Data? cell) {
  final value = cell?.value;
  if (value == null) return '';
  if (value is DateCellValue) {
    return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
  }
  if (value is DateTimeCellValue) {
    return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
  }
  return value.toString().trim();
}
