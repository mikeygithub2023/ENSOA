import 'dart:typed_data';

import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sig_ensoa/core/theme.dart';
import '../../data/models/armement.dart';
import '../../data/repositories/armament_providers.dart';
import '../../shared/widgets/widgets.dart';
import 'import_armes.dart';

/// Verser un registre d'armes existant dans la base, depuis un fichier
/// Excel.
///
/// Trois temps, dans cet ordre : on montre le format attendu, on lit le
/// fichier, et **on dit ce qui va se passer ligne par ligne avant que quoi
/// que ce soit n'entre**. C'est ce dernier temps qui compte : un registre
/// s'importe une fois, et une erreur s'y rattrape à la main, arme par arme.
Future<void> afficherImportArmes(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.all(24),
      child: const _ImportArmesDialog(),
    ),
  );
}

class _ImportArmesDialog extends ConsumerStatefulWidget {
  const _ImportArmesDialog();

  @override
  ConsumerState<_ImportArmesDialog> createState() => _ImportArmesDialogState();
}

class _ImportArmesDialogState extends ConsumerState<_ImportArmesDialog> {
  String? _nomFichier;
  List<LigneArme>? _lignes;
  String? _erreurLecture;
  bool _lecture = false;
  bool _envoi = false;

  int _compte(StatutLigneArme s) =>
      _lignes?.where((l) => l.statut == s).length ?? 0;

  List<LigneArme> get _aCreer =>
      _lignes?.where((l) => l.statut == StatutLigneArme.nouveau).toList() ??
      const [];

  List<LigneArme> get _aRetablir =>
      _lignes?.where((l) => l.statut == StatutLigneArme.aRetablir).toList() ??
      const [];

  bool get _rienAFaire => _aCreer.isEmpty && _aRetablir.isEmpty;

  // --- Le modèle ----------------------------------------------------------

  Future<void> _telechargerModele() async {
    final classeur = Excel.createExcel();
    final feuille = classeur[classeur.sheets.keys.first];
    feuille.appendRow([
      for (final c in colonnesArme) TextCellValue(c.libelle),
    ]);
    // Une ligne d'exemple : un modèle vide laisse deviner le format, une
    // ligne remplie le montre.
    feuille.appendRow([
      for (final c in colonnesArme) TextCellValue(c.exemple),
    ]);
    final octets = classeur.encode();
    if (octets == null) return;

    final messager = ScaffoldMessenger.of(context);
    final chemin = await FilePicker.platform.saveFile(
      dialogTitle: 'Enregistrer le modèle Excel',
      fileName: 'modele_import_armes.xlsx',
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      bytes: Uint8List.fromList(octets),
    );
    if (chemin == null || !mounted) return;
    messager.showSnackBar(
      SnackBar(
        content: Text('Modèle enregistré : $chemin'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  // --- Le fichier ---------------------------------------------------------

  Future<void> _choisirFichier() async {
    setState(() {
      _erreurLecture = null;
      _lignes = null;
    });
    final choix = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );
    if (choix == null) return;

    final fichier = choix.files.single;
    final octets = fichier.bytes;
    if (octets == null) {
      setState(() => _erreurLecture = 'Impossible de lire ce fichier.');
      return;
    }

    setState(() => _lecture = true);
    try {
      // Le registre courant est relu plutôt que pris dans le cache : c'est
      // lui qui sert à dire « déjà présente », et une liste vieille de dix
      // minutes ferait entrer deux fois une arme enregistrée entre-temps.
      await ref.read(armesProvider.notifier).refresh();
      final registre = ref.read(armesProvider);
      // Les armes retirées ne sont dans aucune liste, mais elles gardent
      // leur numéro de série : sans elles, l'import annonce « à créer » un
      // numéro que la base refusera, et le lot entier tombe.
      final retirees = await ref
          .read(armesProvider.notifier)
          .retireesDuRegistre();

      final classeur = Excel.decodeBytes(octets);
      if (classeur.tables.isEmpty) {
        setState(() {
          _erreurLecture = 'Le classeur ne contient aucune feuille.';
          _lecture = false;
        });
        return;
      }
      final feuille = classeur.tables.values.first;
      final toutes = feuille.rows;
      final donnees = toutes.length > 1 ? toutes.sublist(1) : <List<Data?>>[];

      final analysees = analyserLignesArmes(
        brutes: [
          for (final ligne in donnees) [for (final c in ligne) _texte(c)],
        ],
        registreExistant: registre,
        registreRetire: retirees,
      );

      setState(() {
        _nomFichier = fichier.name;
        _lignes = analysees;
        _lecture = false;
      });
    } catch (e) {
      setState(() {
        _erreurLecture = 'Fichier illisible : $e';
        _lecture = false;
      });
    }
  }

  String _texte(Data? cellule) {
    final v = cellule?.value;
    if (v == null) return '';
    if (v is TextCellValue) return v.value.text ?? '';
    if (v is IntCellValue) return '${v.value}';
    if (v is DoubleCellValue) {
      // Un tableur stocke « 5 » comme 5.0 : l'afficher ainsi ferait croire
      // à une donnée douteuse là où il n'y en a pas.
      return v.value == v.value.roundToDouble()
          ? '${v.value.round()}'
          : '${v.value}';
    }
    return v.toString();
  }

  // --- L'écriture ---------------------------------------------------------

  Future<void> _importer() async {
    final aCreer = _aCreer;
    final aRetablir = _aRetablir;
    if (aCreer.isEmpty && aRetablir.isEmpty) return;
    setState(() => _envoi = true);
    try {
      await ref
          .read(armesProvider.notifier)
          .importer(
            [for (final l in aCreer) construireImportArme(l)],
            retablies: {
              for (final l in aRetablir)
                l.existante!.id: construireImportArme(l),
            },
          );
      if (!mounted) return;
      showSuccessSnackBar(
        context,
        aRetablir.isEmpty
            ? '${aCreer.length} arme(s) versées au registre.'
            : '${aCreer.length} arme(s) versées au registre, '
                  '${aRetablir.length} rétablie(s).',
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _envoi = false);
        showErrorSnackBar(context, e);
      }
    }
  }

  // --- L'écran ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final ecran = MediaQuery.of(context).size;
    final largeur = ecran.width - 48 < 1100 ? ecran.width - 48 : 1100.0;
    final hauteur = ecran.height - 48 < 760 ? ecran.height - 48 : 760.0;

    return SizedBox(
      width: largeur,
      height: hauteur,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 12, 0),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Importer un registre d\'armes',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _envoi ? null : () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'La feuille doit porter une ligne d\'en-tête, puis les '
                    'armes. Les colonnes sont lues dans l\'ordre ci-dessous, '
                    'pas d\'après leur titre. Le numéro de série est ce qui '
                    'distingue une arme d\'une autre : c\'est par lui que '
                    'l\'import reconnaît celles qui sont déjà au registre.',
                    style: TextStyle(color: AppColors.inkMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  _TableauFormat(onTelecharger: _telechargerModele),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      FilledButton.icon(
                        onPressed: _lecture ? null : _choisirFichier,
                        icon: const Icon(Icons.upload_file_outlined, size: 18),
                        label: Text(
                          _nomFichier == null
                              ? 'Choisir un fichier Excel (.xlsx)'
                              : 'Changer de fichier',
                        ),
                      ),
                      if (_nomFichier != null) ...[
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            _nomFichier!,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppColors.inkMuted),
                          ),
                        ),
                      ],
                      if (_lecture) ...[
                        const SizedBox(width: 12),
                        const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ],
                    ],
                  ),
                  if (_erreurLecture != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _erreurLecture!,
                      style: const TextStyle(color: AppColors.danger),
                    ),
                  ],
                  if (_lignes != null) ...[
                    const SizedBox(height: 24),
                    _Decompte(
                      nouvelles: _compte(StatutLigneArme.nouveau),
                      aRetablir: _compte(StatutLigneArme.aRetablir),
                      dejaPresentes: _compte(StatutLigneArme.dejaPresent),
                      doublons: _compte(StatutLigneArme.doublonDansLeFichier),
                      erreurs: _compte(StatutLigneArme.erreur),
                    ),
                    const SizedBox(height: 12),
                    if (_lignes!.isEmpty)
                      const EmptyState(
                        message: 'Aucune ligne de données dans ce fichier.',
                        icon: Icons.table_rows_outlined,
                      )
                    else
                      _TableauApercu(lignes: _lignes!),
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
                if (_lignes != null)
                  Expanded(
                    child: Text(
                      _rienAFaire
                          ? 'Rien à verser : tout ce que porte ce fichier est '
                                'déjà au registre, ou reste à corriger.'
                          : '${[
                              if (_aCreer.isNotEmpty)
                                '${_aCreer.length} arme(s) seront créées',
                              if (_aRetablir.isNotEmpty)
                                '${_aRetablir.length} rétablie(s)',
                            ].join(', ')}. Les autres lignes sont laissées '
                                'de côté.',
                      style: const TextStyle(
                        color: AppColors.inkMuted,
                        fontSize: 13,
                      ),
                    ),
                  )
                else
                  const Spacer(),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: _envoi ? null : () => Navigator.of(context).pop(),
                  child: const Text('Annuler'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: (_envoi || _rienAFaire) ? null : _importer,
                  icon: _envoi
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.download_done_outlined, size: 18),
                  label: Text(
                    _envoi ? 'Import en cours...' : 'Importer les nouvelles',
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

/// Le format attendu, colonne par colonne — avec le modèle à télécharger.
class _TableauFormat extends StatelessWidget {
  const _TableauFormat({required this.onTelecharger});

  final VoidCallback onTelecharger;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.blueMist,
        borderRadius: BorderRadius.circular(AppRadii.control),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Colonnes attendues',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
              TextButton.icon(
                onPressed: onTelecharger,
                icon: const Icon(Icons.download_outlined, size: 16),
                label: const Text('Télécharger le modèle'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < colonnesArme.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                '${i + 1}. ${colonnesArme[i].libelle} — '
                '${colonnesArme[i].format}',
                style: const TextStyle(fontSize: 12.5),
              ),
            ),
        ],
      ),
    );
  }
}

class _Decompte extends StatelessWidget {
  const _Decompte({
    required this.nouvelles,
    required this.aRetablir,
    required this.dejaPresentes,
    required this.doublons,
    required this.erreurs,
  });

  final int nouvelles;
  final int aRetablir;
  final int dejaPresentes;
  final int doublons;
  final int erreurs;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text(
          'Aperçu',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(width: 8),
        // `StatusChip` n'offre que info/warning/critical dans ce module ;
        // le vert manquait, et il porte ici l'essentiel — ce qui va entrer.
        _Pastille(texte: '$nouvelles à créer', couleur: AppColors.success),
        if (aRetablir > 0)
          _Pastille(
            texte: '$aRetablir à rétablir',
            couleur: AppColors.ivoryOrange,
          ),
        if (dejaPresentes > 0)
          _Pastille(
            texte: '$dejaPresentes déjà au registre',
            couleur: AppColors.blue,
          ),
        if (doublons > 0)
          _Pastille(
            texte: '$doublons en double dans le fichier',
            couleur: AppColors.warning,
          ),
        if (erreurs > 0)
          _Pastille(texte: '$erreurs en erreur', couleur: AppColors.danger),
      ],
    );
  }
}

class _Pastille extends StatelessWidget {
  const _Pastille({required this.texte, required this.couleur});

  final String texte;
  final Color couleur;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: couleur.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(AppRadii.pill),
    ),
    child: Text(
      texte,
      style: TextStyle(
        color: couleur,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

/// Le fichier, ligne par ligne, avec ce qu'il adviendra de chacune.
class _TableauApercu extends StatelessWidget {
  const _TableauApercu({required this.lignes});

  final List<LigneArme> lignes;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(AppColors.blueMist),
          columns: [
            const DataColumn(label: Text('Ligne')),
            const DataColumn(label: Text('Sort')),
            for (final c in colonnesArme) DataColumn(label: Text(c.libelle)),
          ],
          rows: [
            for (final l in lignes)
              DataRow(
                color: WidgetStateProperty.all(_teinte(l.statut)),
                cells: [
                  DataCell(Text('${l.numero}')),
                  DataCell(_Sort(ligne: l)),
                  for (final v in l.valeurs) DataCell(Text(v)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Color? _teinte(StatutLigneArme s) => switch (s) {
    StatutLigneArme.nouveau => null,
    StatutLigneArme.aRetablir => AppColors.ivoryOrange.withValues(alpha: 0.08),
    StatutLigneArme.dejaPresent => AppColors.blue.withValues(alpha: 0.06),
    StatutLigneArme.doublonDansLeFichier => AppColors.warning.withValues(
      alpha: 0.08,
    ),
    StatutLigneArme.erreur => AppColors.danger.withValues(alpha: 0.06),
  };
}

/// Ce qu'il adviendra d'une ligne, dit en clair — et la raison au survol.
class _Sort extends StatelessWidget {
  const _Sort({required this.ligne});

  final LigneArme ligne;

  @override
  Widget build(BuildContext context) {
    final (texte, couleur, icone, raison) = switch (ligne.statut) {
      StatutLigneArme.nouveau => (
        'À créer',
        AppColors.success,
        Icons.add_circle_outline,
        'Aucune arme ne porte ce numéro de série.',
      ),
      StatutLigneArme.aRetablir => (
        'À rétablir',
        AppColors.ivoryOrange,
        Icons.restore_rounded,
        'Cette arme avait été retirée du registre. Elle va y revenir avec '
            'les données du fichier, et ses bons de sortie la suivent.\n'
            'En créer une seconde porterait le même numéro de série : la '
            'base le refuserait.',
      ),
      StatutLigneArme.dejaPresent => (
        'Déjà au registre',
        AppColors.blue,
        Icons.inventory_2_outlined,
        _descriptionExistante(ligne.existante),
      ),
      StatutLigneArme.doublonDansLeFichier => (
        'Doublon',
        AppColors.warning,
        Icons.copy_all_outlined,
        'Ce numéro de série paraît déjà plus haut dans le fichier. '
            'La première ligne est retenue.',
      ),
      StatutLigneArme.erreur => (
        'Erreur',
        AppColors.danger,
        Icons.error_outline,
        ligne.erreurs.join('\n'),
      ),
    };

    return Tooltip(
      message: raison,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 16, color: couleur),
          const SizedBox(width: 6),
          Text(
            texte,
            style: TextStyle(
              color: couleur,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }

  String _descriptionExistante(Arme? a) {
    if (a == null) return 'Cette arme est déjà enregistrée.';
    return 'Déjà enregistrée : ${a.designationComplete} — '
        'n° ${a.numeroSerie} — ${a.etat.label}'
        '${(a.positionActuelle ?? '').trim().isEmpty ? '' : ' — ${a.positionActuelle}'}.\n'
        'La ligne est laissée de côté : l\'état et la position tenus ici '
        'sont à jour, ceux du fichier datent de son export.';
  }
}
