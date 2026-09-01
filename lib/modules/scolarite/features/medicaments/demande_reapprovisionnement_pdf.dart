import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../models/demande_reapprovisionnement.dart';
import '../../models/medicament.dart';
import '../apprenants/pdf_header.dart';

final _dateFmt = DateFormat('dd/MM/yyyy');

/// Fiche de demande de réapprovisionnement de la pharmacie, destinée au
/// circuit papier : les médicaments commandés, rangés par classe
/// pharmacologique, avec le stock constaté au moment de la demande (figé à
/// la saisie) en regard de la quantité commandée — c'est cette confrontation
/// qui justifie la commande auprès du commandement.
///
/// L'en-tête institutionnel est celui des permissions (voir
/// [buildInstitutionalHeader]), repris en tête de chaque page.
/// [armoiries] est le PNG des armoiries de Côte d'Ivoire, chargé par
/// l'appelant (ce fichier reste indépendant de Flutter/rootBundle pour
/// pouvoir être testé en Dart pur), et [theme] la typographie commune aux
/// documents imprimés (voir `chargerThemePdf`).
pw.Document buildDemandeReapprovisionnementPdf(
  DemandeReapprovisionnement demande, {
  required Uint8List armoiries,
  pw.ThemeData? theme,
}) {
  final doc = pw.Document(theme: theme);
  final armoiriesImage = pw.MemoryImage(armoiries);

  final parType = <TypeMedicament, List<LigneReapprovisionnement>>{};
  for (final ligne in demande.lignes) {
    parType
        .putIfAbsent(ligne.medicamentType ?? TypeMedicament.autre, () => [])
        .add(ligne);
  }

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 28),
      header: (context) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 10),
        child: buildInstitutionalHeader(armoiriesImage),
      ),
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Page ${context.pageNumber} / ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
        ),
      ),
      build: (context) => [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'N° _______ /ENSOA/SM',
              style: const pw.TextStyle(fontSize: 8),
            ),
            pw.Spacer(),
            pw.Text(
              'BOUAKÉ, LE ${_dateFmt.format(demande.dateDemande)}',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ],
        ),
        pw.SizedBox(height: 14),
        pw.Center(
          child: pw.Text(
            'DEMANDE DE RÉAPPROVISIONNEMENT DE LA PHARMACIE',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              decoration: pw.TextDecoration.underline,
            ),
          ),
        ),
        pw.SizedBox(height: 14),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(0.7),
            1: pw.FlexColumnWidth(4.6),
            2: pw.FlexColumnWidth(1.6),
            3: pw.FlexColumnWidth(1.5),
            4: pw.FlexColumnWidth(1.8),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _entete('N°'),
                _entete('DÉSIGNATION'),
                _entete('UNITÉ'),
                _entete('STOCK', alignRight: true),
                _entete('QUANTITÉ DEMANDÉE', alignRight: true),
              ],
            ),
            ..._lignes(parType),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Text(
              'TOTAL : ',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              '${demande.lignes.length} article(s), '
              '${demande.totalUnites} unité(s)',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
        if (demande.observations != null &&
            demande.observations!.isNotEmpty) ...[
          pw.SizedBox(height: 14),
          pw.Text(
            'OBSERVATIONS',
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            demande.observations!,
            style: const pw.TextStyle(fontSize: 8.5),
          ),
        ],
        pw.SizedBox(height: 30),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'LE MÉDECIN CHEF',
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                decoration: pw.TextDecoration.underline,
              ),
            ),
            pw.Spacer(),
            pw.Text(
              'COMMANDANT ECOLE',
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                decoration: pw.TextDecoration.underline,
              ),
            ),
          ],
        ),
      ],
    ),
  );
  return doc;
}

/// Les lignes rangées par classe pharmacologique, chaque classe précédée de
/// son intitulé sur toute la largeur — comme le catalogue à l'écran. La
/// numérotation, elle, court sur toute la fiche : c'est elle qui sert à
/// pointer les articles à la réception.
List<pw.TableRow> _lignes(
  Map<TypeMedicament, List<LigneReapprovisionnement>> parType,
) {
  final rows = <pw.TableRow>[];
  var numero = 1;
  for (final type in TypeMedicament.values) {
    final lignes = parType[type];
    if (lignes == null) continue;
    rows.add(
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey100),
        children: [
          _cellule(''),
          _cellule(type.label.toUpperCase(), gras: true),
          _cellule(''),
          _cellule(''),
          _cellule(''),
        ],
      ),
    );
    for (final ligne in lignes) {
      rows.add(
        pw.TableRow(
          children: [
            _cellule('${numero++}'),
            _cellule(ligne.medicamentNom ?? 'Médicament inconnu'),
            _cellule(ligne.medicamentUnite ?? '-'),
            _cellule('${ligne.stockAuMomentDeLaDemande}', alignRight: true),
            _cellule('${ligne.quantiteDemandee}', alignRight: true, gras: true),
          ],
        ),
      );
    }
  }
  return rows;
}

pw.Widget _entete(String label, {bool alignRight = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
    child: pw.Text(
      label,
      textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
      style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
    ),
  );
}

pw.Widget _cellule(
  String valeur, {
  bool alignRight = false,
  bool gras = false,
}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
    child: pw.Text(
      valeur,
      textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
      style: pw.TextStyle(
        fontSize: 8,
        fontWeight: gras ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    ),
  );
}
