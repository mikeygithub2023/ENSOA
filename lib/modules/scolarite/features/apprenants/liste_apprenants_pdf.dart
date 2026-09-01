import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../models/apprenant.dart';
import 'pdf_header.dart';

final _dateFmt = DateFormat('dd/MM/yyyy');

/// Liste nominative d'élèves ou de stagiaires, prête à être signée et
/// classée.
///
/// C'est une pièce d'appel, pas un état de résultats : elle porte
/// l'identité, le grade et le matricule, jamais les notes. Les notes se
/// lisent sur le bulletin, qui a ses propres règles de diffusion.
pw.Document buildListeApprenantsPdf(
  List<Apprenant> apprenants, {
  required String titre,
  required String sousTitre,
  required Uint8List armoiries,
  pw.ThemeData? theme,
}) {
  final image = pw.MemoryImage(armoiries);
  final doc = pw.Document(theme: theme);

  // On imprime dans l'ordre où on appelle : par nom, puis par prénom.
  final tries = [...apprenants]
    ..sort((a, b) {
      final parNom = a.nom.toLowerCase().compareTo(b.nom.toLowerCase());
      return parNom != 0
          ? parNom
          : a.prenom.toLowerCase().compareTo(b.prenom.toLowerCase());
    });

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 28),
      header: (context) => context.pageNumber == 1
          ? pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                buildInstitutionalHeader(image),
                pw.SizedBox(height: 14),
                pw.Center(
                  child: pw.Text(
                    titre.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                      decoration: pw.TextDecoration.underline,
                    ),
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Center(
                  child: pw.Text(
                    sousTitre,
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ),
                pw.SizedBox(height: 12),
              ],
            )
          : pw.SizedBox(height: 8),
      // Le total figure sur chaque page : une liste d'appel se lit souvent
      // page par page, détachée du reste.
      footer: (context) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Effectif : ${tries.length}',
            style: const pw.TextStyle(fontSize: 8),
          ),
          pw.Text(
            'Page ${context.pageNumber} / ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8),
          ),
        ],
      ),
      build: (context) => [
        if (tries.isEmpty)
          pw.Text(
            'Aucun apprenant dans cette liste.',
            style: const pw.TextStyle(fontSize: 10),
          )
        else
          pw.TableHelper.fromTextArray(
            headers: const [
              'N°',
              'Matricule',
              'Grade',
              'Nom & Prénoms',
              'Sexe',
              'Né(e) le',
              'Statut',
            ],
            data: [
              for (var i = 0; i < tries.length; i++)
                [
                  '${i + 1}',
                  tries[i].matricule ?? '—',
                  tries[i].grade ?? '—',
                  tries[i].nomComplet,
                  _sexe(tries[i].sexe),
                  tries[i].dateNaissance == null
                      ? '—'
                      : _dateFmt.format(tries[i].dateNaissance!),
                  tries[i].statut.label,
                ],
            ],
            border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
            headerStyle: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
            ),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellHeight: 18,
            columnWidths: {
              0: const pw.FixedColumnWidth(26),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(3),
              3: const pw.FlexColumnWidth(4),
              4: const pw.FixedColumnWidth(38),
              5: const pw.FlexColumnWidth(2),
              6: const pw.FlexColumnWidth(2),
            },
            cellAlignments: {
              0: pw.Alignment.center,
              4: pw.Alignment.center,
              5: pw.Alignment.center,
              6: pw.Alignment.center,
            },
          ),
        pw.SizedBox(height: 24),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  'Bouaké, le ${_dateFmt.format(DateTime.now())}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.SizedBox(height: 40),
                pw.Text(
                  'Signature et cachet',
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  );

  return doc;
}

String _sexe(String? valeur) => switch (valeur) {
  'M' => 'M',
  'F' => 'F',
  _ => '—',
};
