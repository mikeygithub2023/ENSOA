import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../models/apprenant.dart';
import '../../models/classe.dart';
import '../../models/controle.dart';
import '../../models/division.dart';
import '../../models/matiere.dart';
import '../../models/note.dart';
import '../../models/promotion.dart';
import '../../models/sous_module.dart';
import 'moyennes.dart';
import 'pdf_header.dart';

/// Tout ce qu'il faut pour imprimer le bulletin d'un apprenant — regroupé
/// ici pour ne pas faire dépendre le générateur PDF des providers Riverpod.
/// [controles] ne doit contenir que les contrôles cochés par l'administrateur
/// (menu "Bulletins", voir [Controle.inclusBulletin]) pour la classe/stage de
/// l'apprenant ; [notes] doit contenir toutes les notes de l'apprenant pour
/// ces contrôles (tous types confondus, y compris les notes par matière d'un
/// contrôle continu/examen) ; [matieres] sert à afficher le nom des matières
/// détaillées sous chaque contrôle continu/examen ; [matiereModules] fournit
/// le coefficient actuel de chaque matière pour cette phase ou ce stage (lu en
/// direct depuis l'écran Matières, pas figé — contrairement au coefficient
/// d'un module, snapshotté sur le contrôle lui-même) ; [photo] est le
/// fichier photo de l'apprenant déjà téléchargé par l'appelant (`null` s'il
/// n'en a pas ou si le téléchargement a échoué — un cadre vide est alors
/// affiché à la place).
class BulletinPrintData {
  const BulletinPrintData({
    required this.apprenant,
    required this.classe,
    required this.division,
    required this.controles,
    required this.notes,
    required this.matieres,
    required this.matiereModules,
    this.sousModules = const [],
    this.promotion,
    this.phases = const [],
    this.photo,
  });

  final Apprenant apprenant;
  final Classe classe;
  final Division division;
  final List<Controle> controles;
  final List<Note> notes;
  final List<Matiere> matieres;
  final List<MatiereModule> matiereModules;

  /// Les sous-modules des modules de la phase : la note d'un module est
  /// leur moyenne pondérée, elle ne se lit nulle part ailleurs.
  final List<SousModule> sousModules;

  /// Renseignée quand le bulletin porte sur une promotion entière plutôt
  /// que sur une seule phase : les évaluations viennent alors de toutes
  /// ses phases, et l'en-tête nomme la promotion.
  final Promotion? promotion;

  /// Les phases de la promotion, avec leur coefficient — renseignées quand le
  /// bulletin porte sur une promotion entière. Le bulletin s'organise alors
  /// phase par phase, chacune avec sa moyenne, et la moyenne générale les
  /// pondère par ces coefficients.
  ///
  /// Vide pour un bulletin de phase seule ou de stage : il n'y a rien à
  /// distinguer ni à pondérer.
  final List<Classe> phases;

  final Uint8List? photo;
}

String _formatNote(num value) {
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);
}

/// Une ligne du bulletin (un contrôle) — [note] est `null` quand l'apprenant
/// n'a aucune note pour ce contrôle ("Non classé"), auquel cas la ligne est
/// exclue du calcul des moyennes (voir mémoire "Notes manquantes = non
/// classé").
class _Ligne {
  const _Ligne({
    required this.libelle,
    required this.coefficient,
    required this.note,
  });

  final String libelle;
  final num coefficient;
  final num? note;
}

/// Un contrôle continu/examen peut couvrir plusieurs matières (une note par
/// matière) : la ligne du bulletin agrège ces notes en une moyenne pondérée
/// par le coefficient actuel de chaque matière (écran Matières). Un module,
/// lui, agrège les notes de ses sous-modules, pondérées par leur propre
/// coefficient.
List<_Ligne> _lignesPourType(
  BulletinPrintData item,
  List<Controle> controles,
  ControleType type,
  Map<String, num> coefMatiereById,
) {
  return [
    for (final controle in controles)
      _Ligne(
        libelle: _libelleLigne(item, controle),
        coefficient: controle.coefficient,
        note: type == ControleType.module || type == ControleType.sport
            ? moyenneSousModules(item.notes, controle.id, item.sousModules)
            : _moyenneMatieres(item.notes, controle.id, coefMatiereById),
      ),
  ];
}

/// L'intitulé d'une ligne.
///
/// Il ne nomme plus la phase : le bulletin de promotion est désormais
/// organisé phase par phase, et le titre du bloc s'en charge.
String _libelleLigne(BulletinPrintData item, Controle controle) =>
    controle.libelle;

/// Moyenne des notes par matière d'un contrôle, pondérée par le coefficient
/// de chaque matière (1 par défaut si la matière n'a pas de coefficient
/// affecté pour cette classe).
num? _moyenneMatieres(
  List<Note> notes,
  String controleId,
  Map<String, num> coefMatiereById,
) => moyenneMatieres(notes, controleId, coefMatiereById);

/// Moyenne pondérée par les coefficients des lignes classées (celles ayant
/// une note) ; `null` si aucune ligne n'est classée.
num? _moyennePonderee(List<_Ligne> lignes) {
  final classees = lignes.where((l) => l.note != null).toList();
  if (classees.isEmpty) return null;
  num totalCoef = 0;
  num totalPoints = 0;
  for (final ligne in classees) {
    totalCoef += ligne.coefficient;
    totalPoints += ligne.note! * ligne.coefficient;
  }
  return totalCoef == 0 ? null : totalPoints / totalCoef;
}

/// Génère le bulletin des apprenants passés en paramètre — une page par
/// apprenant, reprenant l'en-tête institutionnel ENSOA des permissions.
/// [armoiries] est le PNG des armoiries de Côte d'Ivoire, chargé par
/// l'appelant (ce fichier reste indépendant de Flutter/rootBundle pour
/// pouvoir être testé en Dart pur), et [theme] la typographie commune aux
/// documents imprimés (voir `chargerThemePdf`).
pw.Document buildBulletinsPdf(
  List<BulletinPrintData> items, {
  required Uint8List armoiries,
  pw.ThemeData? theme,
}) {
  final doc = pw.Document(theme: theme);
  final armoiriesImage = pw.MemoryImage(armoiries);

  for (final item in items) {
    final apprenant = item.apprenant;
    final matiereNomById = {for (final m in item.matieres) m.id: m.nom};

    // Le bulletin d'une promotion se lit phase par phase : chacune a ses
    // évaluations et sa moyenne, et la moyenne générale les pondère par le
    // coefficient de la phase. Un bulletin de phase seule ou de stage n'a
    // qu'un bloc — le calcul est alors exactement celui d'avant.
    final phasesTriees = [...item.phases]
      ..sort((a, b) => a.ordre.compareTo(b.ordre));
    final blocs = <({Classe classe, List<Controle> controles})>[
      if (item.promotion == null || phasesTriees.isEmpty)
        (classe: item.classe, controles: item.controles)
      else
        for (final phase in phasesTriees)
          (
            classe: phase,
            controles: item.controles
                .where((c) => c.classeId == phase.id)
                .toList(),
          ),
    ].where((b) => b.controles.isNotEmpty).toList();

    // Chaque bloc porte le coefficient de matière de SA phase : deux phases
    // peuvent pondérer la même matière différemment.
    final blocsCalcules = [
      for (final bloc in blocs)
        () {
          final coefMatiereById = {
            for (final mm in item.matiereModules)
              if (mm.classeId == bloc.classe.id) mm.matiereId: mm.coefficient,
          };
          final sections = _sectionsPour(
            item,
            bloc.classe,
            bloc.controles,
            coefMatiereById,
          );
          final lignes = [for (final s in sections) ...s.lignes];
          return (
            classe: bloc.classe,
            coefMatiereById: coefMatiereById,
            sections: sections,
            moyenne: _moyennePonderee(lignes),
          );
        }(),
    ];

    final surPromotion = item.promotion != null && phasesTriees.isNotEmpty;

    // Sur une promotion, la moyenne générale pondère les moyennes de phase.
    // Une phase où l'apprenant n'est classé nulle part ne compte pas — ni sa
    // note, ni son coefficient : elle est absente du calcul, pas comptée zéro.
    final num? moyenneGenerale;
    if (surPromotion) {
      num totalCoef = 0;
      num totalPoints = 0;
      for (final bloc in blocsCalcules) {
        final moyenne = bloc.moyenne;
        if (moyenne == null) continue;
        totalCoef += bloc.classe.coefficient;
        totalPoints += moyenne * bloc.classe.coefficient;
      }
      moyenneGenerale = totalCoef == 0 ? null : totalPoints / totalCoef;
    } else {
      moyenneGenerale = _moyennePonderee([
        for (final bloc in blocsCalcules)
          for (final s in bloc.sections) ...s.lignes,
      ]);
    }

    // MultiPage plutôt que Page : le bulletin d'une promotion à plusieurs
    // phases ne tient plus sur une feuille, et un débordement silencieux
    // vaudrait une note perdue.
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          buildInstitutionalHeader(armoiriesImage),
          pw.SizedBox(height: 14),
          pw.Center(
            child: pw.Text(
              'BULLETIN DE NOTES',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 14),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.black, width: 0.75),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _field('GRADE', apprenant.grade ?? ''),
                      _field('NOM & PRENOMS', apprenant.nomComplet),
                      _field('MATRICULE', apprenant.matricule ?? ''),
                    ],
                  ),
                ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _field('DIVISION', item.division.nom),
                      if (item.promotion != null)
                        _field('PROMOTION', item.promotion!.intitule),
                      if (!surPromotion)
                        _field(
                          item.classe.type == ClasseType.phase
                              ? 'PHASE'
                              : 'STAGE',
                          item.classe.nom,
                        ),
                    ],
                  ),
                ),
                pw.SizedBox(width: 10),
                _photoBox(item.photo),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          for (final bloc in blocsCalcules) ...[
            // Le bandeau de phase n'apparaît que sur un bulletin de
            // promotion : sur celui d'une phase seule, il répéterait l'en-tête.
            if (surPromotion)
              _bandeauPhase(bloc.classe, bloc.moyenne),
            for (final section in bloc.sections)
              if (section.lignes.isNotEmpty) ...[
                section.type == ControleType.module ||
                        section.type == ControleType.sport
                    ? _sectionTable(section.titre, section.lignes)
                    : _sectionAvecDetailMatieres(
                        section.titre,
                        section.controles,
                        item,
                        matiereNomById,
                        bloc.coefMatiereById,
                      ),
                pw.SizedBox(height: 12),
              ],
            if (surPromotion) ...[
              _ligneMoyenne(
                'MOYENNE DE LA PHASE ${bloc.classe.nom.toUpperCase()}',
                bloc.moyenne,
                encadre: false,
              ),
              pw.SizedBox(height: 18),
            ],
          ],

          pw.SizedBox(height: 6),
          _ligneMoyenne('MOYENNE GENERALE', moyenneGenerale),
          pw.SizedBox(height: 28),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'COMMANDANT ECOLE',
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                decoration: pw.TextDecoration.underline,
              ),
            ),
          ),
          pw.SizedBox(height: 60),
        ],
      ),
    );
  }
  return doc;
}

pw.Widget _sectionTable(String titre, List<_Ligne> lignes) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        titre.toUpperCase(),
        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 4),
      pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
        columnWidths: const {
          0: pw.FlexColumnWidth(4),
          1: pw.FlexColumnWidth(1),
          2: pw.FlexColumnWidth(1.5),
        },
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey200),
            children: [
              _cell('Libellé', bold: true),
              _cell('Coef.', bold: true, align: pw.TextAlign.center),
              _cell('Note / 20', bold: true, align: pw.TextAlign.center),
            ],
          ),
          for (final ligne in lignes)
            pw.TableRow(
              children: [
                _cell(ligne.libelle),
                _cell('${ligne.coefficient}', align: pw.TextAlign.center),
                _cell(
                  ligne.note == null ? 'Non classé' : _formatNote(ligne.note!),
                  align: pw.TextAlign.center,
                ),
              ],
            ),
        ],
      ),
    ],
  );
}

/// Détail d'une matière notée au sein d'un contrôle continu/examen (voir
/// [_detailsMatieres]).
class _MatiereDetail {
  const _MatiereDetail({
    required this.nom,
    required this.note,
    required this.coefficient,
  });

  final String nom;
  final num note;
  final num coefficient;
}

/// Notes par matière d'un contrôle continu/examen précis, triées par nom —
/// seules les matières ayant effectivement une note apparaissent (une
/// matière jamais notée pour ce contrôle n'a pas d'enregistrement).
List<_MatiereDetail> _detailsMatieres(
  List<Note> notes,
  String controleId,
  Map<String, String> matiereNomById,
  Map<String, num> coefMatiereById,
) {
  final details = [
    for (final note in notes)
      if (note.controleId == controleId && note.matiereId != null)
        _MatiereDetail(
          nom: matiereNomById[note.matiereId] ?? note.matiereId!,
          note: note.note,
          coefficient: coefMatiereById[note.matiereId] ?? 1,
        ),
  ];
  details.sort((a, b) => a.nom.toLowerCase().compareTo(b.nom.toLowerCase()));
  return details;
}

/// Section "Contrôle continu"/"Examen" du bulletin — un sous-tableau par
/// contrôle détaillant la note de chaque matière couverte, suivi de la
/// moyenne de ce contrôle (qui alimente directement la moyenne générale).
pw.Widget _sectionAvecDetailMatieres(
  String titre,
  List<Controle> controles,
  BulletinPrintData item,
  Map<String, String> matiereNomById,
  Map<String, num> coefMatiereById,
) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        titre.toUpperCase(),
        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 4),
      for (final controle in controles)
        _controleAvecMatieresTable(
          controle,
          _detailsMatieres(
            item.notes,
            controle.id,
            matiereNomById,
            coefMatiereById,
          ),
          _moyenneMatieres(item.notes, controle.id, coefMatiereById),
        ),
    ],
  );
}

pw.Widget _controleAvecMatieresTable(
  Controle controle,
  List<_MatiereDetail> details,
  num? moyenne,
) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 8),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          '${controle.libelle} (coefficient ${controle.coefficient})',
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 3),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(4),
            1: pw.FlexColumnWidth(1),
            2: pw.FlexColumnWidth(1.5),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _cell('Matière', bold: true),
                _cell('Coef.', bold: true, align: pw.TextAlign.center),
                _cell('Note / 20', bold: true, align: pw.TextAlign.center),
              ],
            ),
            if (details.isEmpty)
              pw.TableRow(
                children: [
                  _cell('Non classé'),
                  _cell('', align: pw.TextAlign.center),
                  _cell('', align: pw.TextAlign.center),
                ],
              )
            else
              for (final detail in details)
                pw.TableRow(
                  children: [
                    _cell(detail.nom),
                    _cell('${detail.coefficient}', align: pw.TextAlign.center),
                    _cell(_formatNote(detail.note), align: pw.TextAlign.center),
                  ],
                ),
          ],
        ),
        pw.SizedBox(height: 3),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Moyenne ${controle.libelle} : ${moyenne == null ? 'Non classé' : '${_formatNote(moyenne)} / 20'}',
            style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
          ),
        ),
      ],
    ),
  );
}

pw.Widget _cell(
  String text, {
  bool bold = false,
  pw.TextAlign align = pw.TextAlign.left,
}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    child: pw.Text(
      text,
      textAlign: align,
      style: pw.TextStyle(
        fontSize: 8.5,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    ),
  );
}

/// Photo d'identité de l'apprenant, ou un cadre avec une silhouette
/// générique s'il n'en a pas (dessinée avec des formes simples plutôt
/// qu'une police d'icônes, pour ne pas dépendre d'un glyphe absent de la
/// police par défaut — voir le bogue du tiret cadratin corrigé plus tôt).
pw.Widget _photoBox(Uint8List? photo) {
  const width = 64.0;
  const height = 80.0;
  return pw.Container(
    width: width,
    height: height,
    alignment: pw.Alignment.center,
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.black, width: 0.75),
      color: PdfColors.grey100,
    ),
    child: photo == null
        ? pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Container(
                width: 24,
                height: 24,
                decoration: const pw.BoxDecoration(
                  shape: pw.BoxShape.circle,
                  color: PdfColors.grey400,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Container(
                width: 40,
                height: 20,
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey400,
                  borderRadius: pw.BorderRadius.circular(12),
                ),
              ),
            ],
          )
        : pw.ClipRect(
            child: pw.Image(pw.MemoryImage(photo), fit: pw.BoxFit.cover),
          ),
  );
}

pw.Widget _field(String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 5),
    child: pw.RichText(
      text: pw.TextSpan(
        children: [
          pw.TextSpan(
            text: '$label : ',
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
          ),
          pw.TextSpan(
            text: value.toUpperCase(),
            style: const pw.TextStyle(fontSize: 8),
          ),
        ],
      ),
    ),
  );
}

/// Les quatre sections d'un bloc — modules, sport, contrôles continus,
/// examens — pour une phase ou un stage donné.
///
/// Modules et sport n'existent que dans une phase : un stage n'en a pas.
List<
  ({
    ControleType type,
    String titre,
    List<Controle> controles,
    List<_Ligne> lignes,
  })
>
_sectionsPour(
  BulletinPrintData item,
  Classe classe,
  List<Controle> controles,
  Map<String, num> coefMatiereById,
) {
  ({
    ControleType type,
    String titre,
    List<Controle> controles,
    List<_Ligne> lignes,
  })
  section(ControleType type) => (
    type: type,
    titre: type.sectionLabel(classe.type),
    controles: controles.where((c) => c.type == type).toList(),
    lignes: _lignesPourType(
      item,
      controles.where((c) => c.type == type).toList(),
      type,
      coefMatiereById,
    ),
  );

  return [
    if (classe.type == ClasseType.phase) section(ControleType.module),
    if (classe.type == ClasseType.phase) section(ControleType.sport),
    section(ControleType.continu),
    section(ControleType.examen),
  ];
}

/// Le bandeau qui ouvre une phase sur un bulletin de promotion : son nom et
/// son coefficient, pour qu'on lise du même coup ce que la phase pèse.
pw.Widget _bandeauPhase(Classe phase, num? moyenne) {
  return pw.Container(
    width: double.infinity,
    margin: const pw.EdgeInsets.only(bottom: 8),
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    color: PdfColors.grey300,
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          'PHASE ${phase.nom.toUpperCase()}',
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(
          'Coefficient ${_formatNote(phase.coefficient)}',
          style: const pw.TextStyle(fontSize: 9),
        ),
      ],
    ),
  );
}

/// Une ligne de moyenne — encadrée pour la moyenne générale, simplement
/// soulignée pour celle d'une phase.
pw.Widget _ligneMoyenne(String libelle, num? moyenne, {bool encadre = true}) {
  return pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: pw.BoxDecoration(
      border: encadre
          ? pw.Border.all(color: PdfColors.black, width: 0.75)
          : const pw.Border(
              top: pw.BorderSide(color: PdfColors.black, width: 0.5),
            ),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          libelle,
          style: pw.TextStyle(
            fontSize: encadre ? 11 : 10,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.Text(
          moyenne == null ? 'Non classé' : '${_formatNote(moyenne)} / 20',
          style: pw.TextStyle(
            fontSize: encadre ? 11 : 10,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}
