import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../data/models/user.dart';
import '../../data/repositories/fuel_providers.dart';

/// Génère puis ouvre l'aperçu d'impression de l'état des distributions pour
/// une soute donnée, au format strict de l'imprimé officiel ENSOA (en-tête
/// EMGA/ENSOA, armoiries, tableau NOM ET PRENOMS / CONTACT / VEHICULE /
/// IMMATRICULATION / QUANTITE / DATE / SOUTIER).
Future<void> imprimerEtatDistributions({
  required String souteLibelle,
  required String sousTitre,
  required List<DistributionVue> lignes,
  required AppUser? Function(String utilisateurId) resoudreSoutier,
}) async {
  final armoiries = (await rootBundle.load(
    'assets/images/armoiries_ci.png',
  )).buffer.asUint8List();
  final logoEnsoa = (await rootBundle.load(
    'assets/images/logo_ensoa.png',
  )).buffer.asUint8List();
  final imgArmoiries = pw.MemoryImage(armoiries);
  final imgLogo = pw.MemoryImage(logoEnsoa);
  final df = DateFormat('dd/MM/yyyy');

  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 24),
      header: (context) {
        if (context.pageNumber > 1) return pw.SizedBox();
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(width: 0.6),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            pw.Text(
                              'ETAT-MAJOR GENERAL DES ARMEES',
                              style: pw.TextStyle(
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.Text(
                              '--------',
                              style: const pw.TextStyle(fontSize: 8),
                            ),
                            pw.Text(
                              'COMMANDEMENT DES ECOLES ET CENTRES DE',
                              textAlign: pw.TextAlign.center,
                              style: pw.TextStyle(
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.Text(
                              'FORMATION',
                              style: pw.TextStyle(
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.Text(
                              '--oo0oo--',
                              style: const pw.TextStyle(fontSize: 8),
                            ),
                            pw.Text(
                              'École Nationale des Sous-officiers d\'Active',
                              style: pw.TextStyle(
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Image(imgLogo, height: 56),
                    ],
                  ),
                ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Image(imgArmoiries, height: 56),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'République de Côte d\'Ivoire',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                      pw.Text(
                        'Union - Discipline - travail',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 18),
            pw.Text(
              'SOUTE DE ${souteLibelle.toUpperCase()}',
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                decoration: pw.TextDecoration.underline,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              sousTitre,
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                decoration: pw.TextDecoration.underline,
              ),
            ),
            pw.SizedBox(height: 16),
          ],
        );
      },
      footer: (context) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 10),
        child: pw.Center(
          child: pw.Text(
            'S\'instruire pour ne pas subir',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
          ),
        ),
      ),
      build: (context) => [
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
          ),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey700),
          cellStyle: const pw.TextStyle(fontSize: 9),
          cellAlignment: pw.Alignment.centerLeft,
          headerAlignment: pw.Alignment.center,
          cellAlignments: const {
            2: pw.Alignment.center,
            3: pw.Alignment.center,
            4: pw.Alignment.center,
            5: pw.Alignment.center,
          },
          border: pw.TableBorder.all(width: 0.4, color: PdfColors.grey400),
          headers: const [
            'NOM ET PRENOMS',
            'CONTACT',
            'VEHICULE',
            'IMMATRICULATION',
            'QUANTITE',
            'DATE',
            'SOUTIER',
          ],
          data: [
            for (final v in lignes)
              [
                '${v.distribution.gradeDestinataire ?? ''} ${v.distribution.destinataire}'
                    .trim(),
                v.distribution.contact ?? '—',
                v.distribution.vehicule ?? '—',
                v.distribution.vhlImmatriculation ?? '—',
                '${v.distribution.typeCarburant} ${v.distribution.quantitePercue} L',
                df.format(v.distribution.date),
                _libelleSoutier(resoudreSoutier(v.distribution.utilisateurId)),
              ],
          ],
        ),
      ],
    ),
  );

  await Printing.layoutPdf(
    onLayout: (format) => doc.save(),
    name: 'Distribution carburant - $souteLibelle',
  );
}

String _libelleSoutier(AppUser? u) =>
    u == null ? '—' : '${u.grade} ${u.nomComplet}';
