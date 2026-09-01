import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// En-tête institutionnel ENSOA (chaîne de commandement à gauche, armoiries
/// de Côte d'Ivoire + République à droite) — repris à l'identique sur tous
/// les documents imprimés (permissions, bulletins).
pw.Widget buildInstitutionalHeader(pw.MemoryImage armoiries) {
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.black, width: 0.75),
          ),
          child: pw.Column(
            children: [
              pw.Text(
                'ETAT-MAJOR GENERAL DES ARMEES',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
              ),
              pw.Text('--------', style: const pw.TextStyle(fontSize: 8)),
              pw.Text(
                'COMMANDEMENT DES ECOLES ET CENTRES DE FORMATION',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
              ),
              pw.Text('--oo0oo--', style: const pw.TextStyle(fontSize: 8)),
              pw.Text(
                "ECOLE NATIONALE DES SOUS-OFFICIERS D'ACTIVE",
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ],
          ),
        ),
      ),
      pw.SizedBox(width: 10),
      pw.Expanded(
        child: pw.Padding(
          padding: const pw.EdgeInsets.only(left: 22),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Image(armoiries, height: 40),
              pw.SizedBox(height: 2),
              pw.Text(
                'RÉPUBLIQUE DE CÔTE D\'IVOIRE',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'UNION - DISCIPLINE - TRAVAIL',
                style: const pw.TextStyle(fontSize: 8),
              ),
              pw.SizedBox(height: 3),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Container(
                    width: 16,
                    height: 0.75,
                    color: const PdfColor.fromInt(0xff9bbb59),
                  ),
                  pw.Container(
                    margin: const pw.EdgeInsets.symmetric(horizontal: 3),
                    width: 4,
                    height: 4,
                    decoration: const pw.BoxDecoration(
                      shape: pw.BoxShape.circle,
                      color: PdfColor.fromInt(0xff9bbb59),
                    ),
                  ),
                  pw.Container(
                    width: 16,
                    height: 0.75,
                    color: const PdfColor.fromInt(0xff9bbb59),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
