import 'dart:typed_data';

import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sig_ensoa/core/theme.dart';
import '../../data/models/vehicule.dart';
import '../../data/repositories/fleet_providers.dart';
import '../../shared/widgets/widgets.dart';
import 'import_vehicules.dart';

/// Verser un parc existant dans la base, depuis un fichier Excel.
///
/// Trois temps, dans cet ordre : on montre le format attendu, on lit le
/// fichier, et **on dit ce qui va se passer ligne par ligne avant que quoi
/// que ce soit n'entre**. C'est ce dernier temps qui compte : un import de
/// parc se fait une fois, et une erreur s'y rattrape à la main, véhicule par
/// véhicule.
Future<void> afficherImportVehicules(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.all(24),
      child: const _ImportVehiculesDialog(),
    ),
  );
}

class _ImportVehiculesDialog extends ConsumerStatefulWidget {
  const _ImportVehiculesDialog();

  @override
  ConsumerState<_ImportVehiculesDialog> createState() =>
      _ImportVehiculesDialogState();
}

class _ImportVehiculesDialogState
    extends ConsumerState<_ImportVehiculesDialog> {
  String? _nomFichier;
  List<LigneVehicule>? _lignes;
  String? _erreurLecture;
  bool _lecture = false;
  bool _envoi = false;

  int _compte(StatutLigne s) =>
      _lignes?.where((l) => l.statut == s).length ?? 0;

  List<LigneVehicule> get _aCreer =>
      _lignes?.where((l) => l.statut == StatutLigne.nouveau).toList() ??
      const [];

  List<LigneVehicule> get _aRetablir =>
      _lignes?.where((l) => l.statut == StatutLigne.aRetablir).toList() ??
      const [];

  bool get _rienAFaire => _aCreer.isEmpty && _aRetablir.isEmpty;

  // --- Le modèle ----------------------------------------------------------

  Future<void> _telechargerModele() async {
    final classeur = Excel.createExcel();
    final feuille = classeur[classeur.sheets.keys.first];
    feuille.appendRow([
      for (final c in colonnesVehicule) TextCellValue(c.libelle),
    ]);
    // Une ligne d'exemple : un modèle vide laisse deviner le format, une
    // ligne remplie le montre.
    feuille.appendRow([
      for (final c in colonnesVehicule) TextCellValue(c.exemple),
    ]);
    final octets = classeur.encode();
    if (octets == null) return;

    final messager = ScaffoldMessenger.of(context);
    final chemin = await FilePicker.platform.saveFile(
      dialogTitle: 'Enregistrer le modèle Excel',
      fileName: 'modele_import_vehicules.xlsx',
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
      // Le parc courant est relu plutôt que pris dans le cache : c'est lui
      // qui sert à dire « déjà présent », et une liste vieille de dix
      // minutes ferait entrer deux fois un véhicule enregistré entre-temps.
      await ref.read(vehiculesProvider.notifier).refresh();
      final parc = ref.read(vehiculesProvider);
      // Les retirés du parc ne sont dans aucune liste, mais ils gardent
      // leur immatriculation : sans eux, l'import annonce « à créer » une
      // plaque que la base refusera, et le lot entier tombe.
      final retires = await ref
          .read(vehiculesProvider.notifier)
          .retiresDuParc();

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

      final analysees = analyserLignes(
        brutes: [
          for (final ligne in donnees) [for (final c in ligne) _texte(c)],
        ],
        parcExistant: parc,
        parcRetire: retires,
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
          .read(vehiculesProvider.notifier)
          .importer(
            [for (final l in aCreer) construireImport(l)],
            retablis: {
              for (final l in aRetablir) l.existant!.id: construireImport(l),
            },
          );
      if (!mounted) return;
      showSuccessSnackBar(
        context,
        aRetablir.isEmpty
            ? '${aCreer.length} véhicule(s) versés au parc.'
            : '${aCreer.length} véhicule(s) versés au parc, '
                  '${aRetablir.length} rétabli(s).',
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
                    'Importer un parc existant',
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
                    'véhicules. Les colonnes sont lues dans l\'ordre '
                    'ci-dessous, pas d\'après leur titre.',
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
                      nouveaux: _compte(StatutLigne.nouveau),
                      aRetablir: _compte(StatutLigne.aRetablir),
                      dejaPresents: _compte(StatutLigne.dejaPresent),
                      doublons: _compte(StatutLigne.doublonDansLeFichier),
                      erreurs: _compte(StatutLigne.erreur),
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
                                'déjà au parc, ou reste à corriger.'
                          : '${[if (_aCreer.isNotEmpty) '${_aCreer.length} véhicule(s) seront créés', if (_aRetablir.isNotEmpty) '${_aRetablir.length} rétabli(s)'].join(', ')}. Les autres lignes sont laissées '
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
                    _envoi ? 'Import en cours...' : 'Importer les nouveaux',
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
          for (var i = 0; i < colonnesVehicule.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                '${i + 1}. ${colonnesVehicule[i].libelle} — '
                '${colonnesVehicule[i].format}',
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
    required this.nouveaux,
    required this.aRetablir,
    required this.dejaPresents,
    required this.doublons,
    required this.erreurs,
  });

  final int nouveaux;
  final int aRetablir;
  final int dejaPresents;
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
        _Pastille(texte: '$nouveaux à créer', couleur: AppColors.success),
        if (aRetablir > 0)
          _Pastille(
            texte: '$aRetablir à rétablir',
            couleur: AppColors.ivoryOrange,
          ),
        if (dejaPresents > 0)
          _Pastille(
            texte: '$dejaPresents déjà au parc',
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

  final List<LigneVehicule> lignes;

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
            for (final c in colonnesVehicule)
              DataColumn(label: Text(c.libelle)),
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

  Color? _teinte(StatutLigne s) => switch (s) {
    StatutLigne.nouveau => null,
    StatutLigne.aRetablir => AppColors.ivoryOrange.withValues(alpha: 0.08),
    StatutLigne.dejaPresent => AppColors.blue.withValues(alpha: 0.06),
    StatutLigne.doublonDansLeFichier => AppColors.warning.withValues(
      alpha: 0.08,
    ),
    StatutLigne.erreur => AppColors.danger.withValues(alpha: 0.06),
  };
}

/// Ce qu'il adviendra d'une ligne, dit en clair — et la raison au survol.
class _Sort extends StatelessWidget {
  const _Sort({required this.ligne});

  final LigneVehicule ligne;

  @override
  Widget build(BuildContext context) {
    final (texte, couleur, icone, raison) = switch (ligne.statut) {
      StatutLigne.nouveau => (
        'À créer',
        AppColors.success,
        Icons.add_circle_outline,
        'Aucun véhicule ne porte cette immatriculation.',
      ),
      StatutLigne.aRetablir => (
        'À rétablir',
        AppColors.ivoryOrange,
        Icons.restore_rounded,
        'Ce véhicule avait été retiré du parc. Il va y revenir avec les '
            'données du fichier, et son historique — réparations, vidanges, '
            'mouvements — le suit.\n'
            'En créer un second porterait la même immatriculation : la base '
            'le refuserait.',
      ),
      StatutLigne.dejaPresent => (
        'Déjà au parc',
        AppColors.blue,
        Icons.inventory_2_outlined,
        _descriptionExistant(ligne.existant),
      ),
      StatutLigne.doublonDansLeFichier => (
        'Doublon',
        AppColors.warning,
        Icons.copy_all_outlined,
        'Cette immatriculation paraît déjà plus haut dans le fichier. '
            'La première ligne est retenue.',
      ),
      StatutLigne.erreur => (
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

  String _descriptionExistant(Vehicule? v) {
    if (v == null) return 'Ce véhicule est déjà enregistré.';
    return 'Déjà enregistré : ${v.marque} ${v.modele} — '
        '${v.immatriculation} — ${v.etat.label} — '
        '${v.kilometrage} km.\n'
        'La ligne est laissée de côté : les données de la base sont à jour, '
        'celles du fichier datent de son export.';
  }
}
