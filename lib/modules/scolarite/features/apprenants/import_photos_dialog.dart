// Poser les photos d'un dossier entier, d'un seul geste.
//
// L'école a ses photos dans un dossier, nommées par matricule ou par
// numéro mécanographique. Les poser une par une, c'est ouvrir deux cent
// cinquante-six fiches et refaire deux cent cinquante-six fois le même
// geste ; personne ne le fait, et les fiches restent sans visage.
//
// L'écran ne décide rien de lui-même : il montre à qui chaque fichier a
// été rattaché, et pourquoi les autres sont restés de côté. Rien n'est
// envoyé avant que cette liste ait été relue — une photo posée sur la
// mauvaise fiche ne se voit pas, et ne se corrige que si quelqu'un s'en
// aperçoit.

import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sig_ensoa/core/erreurs.dart';
import 'package:sig_ensoa/core/theme.dart' hide AlertLevel, AlertLevelColor;
import '../../models/apprenant.dart';
import '../../shared/widgets/common.dart';
import 'import_photos.dart';
import 'providers/apprenants_providers.dart';

/// Le nombre de fichiers acceptés d'un coup.
///
/// Les octets de toutes les photos choisies tiennent en mémoire avant le
/// premier envoi — le navigateur n'offre pas de les lire au fur et à
/// mesure. Cent photos de bureau font une trentaine de mégaoctets ; les
/// deux cent cinquante-six de l'école se posent donc en trois fois, et
/// c'est dit avant qu'on s'y essaie.
const int _maxFichiers = 100;

/// Ouvre l'import des photos sur [effectif] — la liste telle que l'écran
/// la délimite, hors recherche par nom.
///
/// [portee] nomme cette liste à l'écran (« le personnel de la Division de
/// Commandement et Logistique », « le FCB »), pour qu'on sache contre quoi
/// les fichiers sont rapprochés. Un fichier qui désigne un militaire
/// d'ailleurs ne trouve rien, et c'est voulu.
Future<void> showImportPhotosDialog(
  BuildContext context, {
  required List<Apprenant> effectif,
  required String portee,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.all(24),
      child: _ImportPhotosDialog(effectif: effectif, portee: portee),
    ),
  );
}

class _ImportPhotosDialog extends ConsumerStatefulWidget {
  const _ImportPhotosDialog({required this.effectif, required this.portee});

  final List<Apprenant> effectif;
  final String portee;

  @override
  ConsumerState<_ImportPhotosDialog> createState() =>
      _ImportPhotosDialogState();
}

class _ImportPhotosDialogState extends ConsumerState<_ImportPhotosDialog> {
  /// Les octets choisis, dans l'ordre des rapprochements.
  List<Uint8List?> _octets = const [];
  List<RapprochementPhoto> _rapprochements = const [];

  /// Les militaires désignés par deux fichiers : on ne pose ni l'un ni
  /// l'autre, puisque rien ne dit lequel est le bon.
  Set<String> _servisDeuxFois = const {};

  String? _erreurChoix;
  bool _chargement = false;

  bool _envoiEnCours = false;
  int _posees = 0;
  List<String>? _refus;

  /// Les fichiers que l'on peut poser : un militaire trouvé, et un seul
  /// fichier pour lui.
  Iterable<int> get _indexAPoser => [
    for (var i = 0; i < _rapprochements.length; i++)
      if (_rapprochements[i].estTrouve &&
          !_servisDeuxFois.contains(_rapprochements[i].apprenant!.id) &&
          _octets[i] != null)
        i,
  ];

  int get _nbAPoser => _indexAPoser.length;

  int get _nbRemplacements =>
      _indexAPoser.where((i) => _rapprochements[i].remplaceUnePhoto).length;

  int get _nbEcartes => _rapprochements.length - _nbAPoser;

  Future<void> _choisirLesFichiers() async {
    setState(() {
      _chargement = true;
      _erreurChoix = null;
      _refus = null;
    });
    try {
      final choix = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.image,
        withData: true,
      );
      if (choix == null) {
        if (mounted) setState(() => _chargement = false);
        return;
      }
      if (choix.files.length > _maxFichiers) {
        if (!mounted) return;
        setState(() {
          _chargement = false;
          _erreurChoix =
              '${choix.files.length} fichiers choisis. '
              'L\'écran en prend $_maxFichiers à la fois — '
              'reprenez par lots.';
        });
        return;
      }
      final fichiers = [
        for (final f in choix.files) FichierPhoto(f.name, f.size),
      ];
      final rapprochements = rapprocherLesPhotos(
        fichiers: fichiers,
        effectif: widget.effectif,
      );
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _octets = [for (final f in choix.files) f.bytes];
        _rapprochements = rapprochements;
        _servisDeuxFois = militairesServisDeuxFois(rapprochements);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreurChoix = 'Lecture du dossier impossible : ${messageErreur(e)}';
      });
    }
  }

  Future<void> _poser() async {
    setState(() {
      _envoiEnCours = true;
      _posees = 0;
      _refus = null;
    });
    final depot = ref.read(apprenantsRepositoryProvider);
    final refus = <String>[];
    var posees = 0;

    for (final i in _indexAPoser) {
      final r = _rapprochements[i];
      try {
        await depot.poserPhoto(
          apprenantId: r.apprenant!.id,
          bytes: _octets[i]!,
          fileName: r.fichier,
        );
        posees++;
      } catch (e) {
        refus.add('${r.fichier} — ${messageErreur(e)}');
      }
      if (!mounted) return;
      setState(() => _posees = posees);
    }

    // La photo d'une fiche garde son chemin quand l'extension ne change
    // pas : c'est l'URL signée qu'il faut refaire, sinon l'écran affiche
    // encore l'ancien visage depuis son cache.
    ref.invalidate(apprenantsListProvider);
    ref.invalidate(apprenantByIdProvider);
    ref.invalidate(apprenantPhotoUrlProvider);

    if (!mounted) return;
    setState(() {
      _envoiEnCours = false;
      _refus = refus;
    });
    if (refus.isEmpty) {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            posees == 1 ? 'Photo posée.' : '$posees photos posées.',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final taille = MediaQuery.of(context).size;
    final largeur = taille.width - 48 < 880 ? taille.width - 48 : 880.0;
    final hauteur = taille.height - 48 < 720 ? taille.height - 48 : 720.0;

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
                    'Importer les photos',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _envoiEnCours
                      ? null
                      : () => Navigator.of(context).pop(),
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
                  _Consigne(portee: widget.portee),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      FilledButton.icon(
                        onPressed: (_chargement || _envoiEnCours)
                            ? null
                            : _choisirLesFichiers,
                        icon: const Icon(
                          Icons.photo_library_outlined,
                          size: 18,
                        ),
                        label: Text(
                          _rapprochements.isEmpty
                              ? 'Choisir les photos'
                              : 'Changer de sélection',
                        ),
                      ),
                      if (_chargement) ...[
                        const SizedBox(width: 12),
                        const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ],
                    ],
                  ),
                  if (_erreurChoix != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _erreurChoix!,
                      style: const TextStyle(color: AppColors.danger),
                    ),
                  ],
                  if (_rapprochements.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        const Text(
                          'Rapprochement',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(width: 16),
                        StatusChip(
                          label: '$_nbAPoser à poser',
                          level: AlertLevel.success,
                        ),
                        if (_nbRemplacements > 0) ...[
                          const SizedBox(width: 8),
                          StatusChip(
                            label: '$_nbRemplacements remplacement(s)',
                            level: AlertLevel.warning,
                          ),
                        ],
                        if (_nbEcartes > 0) ...[
                          const SizedBox(width: 8),
                          StatusChip(
                            label: '$_nbEcartes écarté(s)',
                            level: AlertLevel.critical,
                          ),
                        ],
                      ],
                    ),
                    if (_servisDeuxFois.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Deux fichiers au moins désignent le même militaire. '
                        'Aucun des deux n\'est posé : rien ne dit lequel est '
                        'le bon. Retirez le fichier en trop du dossier.',
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    _TableauRapprochement(
                      rapprochements: _rapprochements,
                      servisDeuxFois: _servisDeuxFois,
                    ),
                  ],
                  if (_refus != null && _refus!.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'Photos refusées',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.danger,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final ligne in _refus!)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          ligne,
                          style: const TextStyle(
                            color: AppColors.danger,
                            fontSize: 13,
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
                  onPressed: _envoiEnCours
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Fermer'),
                ),
                const Spacer(),
                if (_envoiEnCours) ...[
                  Text(
                    '$_posees / $_nbAPoser',
                    style: const TextStyle(color: AppColors.inkMuted),
                  ),
                  const SizedBox(width: 12),
                ],
                FilledButton(
                  onPressed: (_nbAPoser == 0 || _envoiEnCours) ? null : _poser,
                  child: _envoiEnCours
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _nbAPoser <= 1
                              ? 'Poser la photo'
                              : 'Poser les $_nbAPoser photos',
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

/// Comment nommer les fichiers pour qu'ils trouvent leur militaire.
class _Consigne extends StatelessWidget {
  const _Consigne({required this.portee});

  final String portee;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.blueMist.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Portée du rapprochement : $portee. Un fichier qui désigne un '
            'militaire hors de cette liste ne trouve personne.',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Nommez chaque fichier par le matricule, le matricule solde, le '
            'numéro mécanographique ou le nom complet du militaire — '
            '« 39287.jpg », « 001 08 0505.jpg », « AIME MOH JULIEN.jpg ». '
            'Les espaces, tirets, apostrophes et accents ne gênent pas, et le '
            '« (1) » que Windows ajoute en recopiant est ignoré.',
            style: TextStyle(color: AppColors.inkMuted, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            '$_maxFichiers fichiers au plus à la fois, '
            '${formatPoids(poidsMaxPhoto)} au plus par photo.',
            style: const TextStyle(color: AppColors.inkMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// Fichier par fichier, ce qui va se passer.
class _TableauRapprochement extends StatelessWidget {
  const _TableauRapprochement({
    required this.rapprochements,
    required this.servisDeuxFois,
  });

  final List<RapprochementPhoto> rapprochements;
  final Set<String> servisDeuxFois;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 24,
          columns: const [
            DataColumn(label: Text('')),
            DataColumn(label: Text('Fichier')),
            DataColumn(label: Text('Poids')),
            DataColumn(label: Text('Militaire')),
          ],
          rows: [
            for (final r in rapprochements)
              DataRow(
                cells: [
                  DataCell(_Pastille(r, servisDeuxFois)),
                  DataCell(Text(r.fichier)),
                  DataCell(Text(formatPoids(r.octets))),
                  DataCell(Text(_designation(r, servisDeuxFois))),
                ],
              ),
          ],
        ),
      ),
    );
  }

  static String _designation(RapprochementPhoto r, Set<String> servisDeuxFois) {
    final a = r.apprenant;
    if (a == null) return libelleDuMotif(r.motif!);
    if (servisDeuxFois.contains(a.id)) {
      return '${a.nomComplet} — deux fichiers pour lui';
    }
    final grade = a.grade;
    final nom = grade == null ? a.nomComplet : '$grade ${a.nomComplet}';
    return r.remplaceUnePhoto ? '$nom (remplace sa photo)' : nom;
  }
}

class _Pastille extends StatelessWidget {
  const _Pastille(this.rapprochement, this.servisDeuxFois);

  final RapprochementPhoto rapprochement;
  final Set<String> servisDeuxFois;

  @override
  Widget build(BuildContext context) {
    final a = rapprochement.apprenant;
    if (a == null || servisDeuxFois.contains(a.id)) {
      return const Icon(Icons.block, color: AppColors.danger, size: 18);
    }
    return rapprochement.remplaceUnePhoto
        ? const Icon(Icons.swap_horiz, color: AppColors.warning, size: 18)
        : const Icon(Icons.check_circle, color: AppColors.success, size: 18);
  }
}
