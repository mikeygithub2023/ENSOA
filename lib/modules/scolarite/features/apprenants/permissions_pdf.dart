import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../models/apprenant.dart';
import '../../models/classe.dart';
import '../../models/division.dart';
import '../../models/permission.dart';
import 'pdf_header.dart';

/// Tout ce qu'il faut pour imprimer une permission — regroupé ici pour ne
/// pas faire dépendre le générateur PDF des providers Riverpod.
class PermissionPrintData {
  const PermissionPrintData({
    required this.permission,
    required this.apprenant,
    required this.classe,
    required this.division,
  });

  final Permission permission;
  final Apprenant apprenant;
  final Classe classe;
  final Division division;
}

final _dateFmt = DateFormat('dd/MM/yyyy');

/// Voyelles (accentuées comprises) déclenchant l'élision "à le" → "à l'"
/// devant un grade. [mot] est déjà en majuscules à l'usage.
const _voyelles = {
  'A',
  'E',
  'I',
  'O',
  'U',
  'Y',
  'À',
  'Â',
  'Ä',
  'É',
  'È',
  'Ê',
  'Ë',
  'Î',
  'Ï',
  'Ô',
  'Ö',
  'Ù',
  'Û',
  'Ü',
};

/// Choisit "à l'" (élision) ou "au" (contraction) devant le grade du
/// permissionnaire, selon que celui-ci commence par une voyelle ou non —
/// ex. "À L'ÉLÈVE SOUS-OFFICIER..." mais "AU SERGENT-CHEF...". Inclut les
/// espaces nécessaires autour, pour être concaténé directement au grade.
String _articleDevantGrade(String gradeNom) {
  final commenceParVoyelle =
      gradeNom.isNotEmpty && _voyelles.contains(gradeNom[0]);
  return commenceParVoyelle ? " A L'" : ' AU ';
}

/// Génère le PDF des permissions passées en paramètre — une page par
/// permission, reprenant le modèle officiel ENSOA (talon à gauche pour les
/// archives de l'école, titre de permission à droite pour l'intéressé).
/// [armoiries] est le PNG des armoiries de Côte d'Ivoire, chargé par
/// l'appelant (ce fichier reste indépendant de Flutter/rootBundle pour
/// pouvoir être testé en Dart pur), et [theme] la typographie commune aux
/// documents imprimés (voir `chargerThemePdf`).
pw.Document buildPermissionsPdf(
  List<PermissionPrintData> items, {
  required Uint8List armoiries,
  pw.ThemeData? theme,
}) {
  final doc = pw.Document(theme: theme);
  final armoiriesImage = pw.MemoryImage(armoiries);

  for (final item in items) {
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        build: (context) => pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Expanded(
              child: _permissionHalf(
                item: item,
                armoiries: armoiriesImage,
                isSouche: true,
              ),
            ),
            pw.Container(
              margin: const pw.EdgeInsets.symmetric(horizontal: 8),
              width: 1,
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  left: pw.BorderSide(
                    color: PdfColors.grey500,
                    width: 0.75,
                    style: pw.BorderStyle.dashed,
                  ),
                ),
              ),
            ),
            pw.Expanded(
              child: _permissionHalf(
                item: item,
                armoiries: armoiriesImage,
                isSouche: false,
              ),
            ),
          ],
        ),
      ),
    );
  }
  return doc;
}

pw.Widget _permissionHalf({
  required PermissionPrintData item,
  required pw.MemoryImage armoiries,
  required bool isSouche,
}) {
  final apprenant = item.apprenant;
  final permission = item.permission;
  final duree =
      permission.dateRetour.difference(permission.dateDepart).inDays + 1;
  final gradeNom = [
    apprenant.grade,
    apprenant.nom,
    apprenant.prenom,
  ].where((s) => s != null && s.trim().isNotEmpty).join(' ').toUpperCase();
  final urgence = [
    apprenant.urgenceNom,
    if (apprenant.urgenceLien != null && apprenant.urgenceLien!.isNotEmpty)
      '(${apprenant.urgenceLien})',
    apprenant.urgenceContact,
  ].where((s) => s != null && s.trim().isNotEmpty).join(' ');

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.center,
    children: [
      buildInstitutionalHeader(armoiries),
      pw.SizedBox(height: 6),
      pw.Align(
        alignment: pw.Alignment.centerLeft,
        child: pw.Text(
          'N° _______ /ENSOA/DFS',
          style: const pw.TextStyle(fontSize: 8),
        ),
      ),
      pw.SizedBox(height: 10),
      pw.Row(
        children: [
          pw.Expanded(child: pw.SizedBox()),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.only(left: 22),
              child: pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'BOUAKÉ, LE ${_dateFmt.format(DateTime.now())}',
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ),
            ),
          ),
        ],
      ),
      pw.SizedBox(height: 10),
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.black, width: 0.75),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (isSouche) ...[
              _field('GRADE', apprenant.grade ?? ''),
              _field('NOM & PRENOMS', apprenant.nomComplet),
              _field('MATRICULE', apprenant.matricule ?? ''),
            ] else
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 6),
                child: pw.RichText(
                  text: pw.TextSpan(
                    style: const pw.TextStyle(fontSize: 9),
                    children: [
                      const pw.TextSpan(
                        text: 'IL EST ACCORDE UNE PERMISSION DE ',
                      ),
                      pw.TextSpan(
                        text: '$duree JOURS',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.TextSpan(text: _articleDevantGrade(gradeNom)),
                      pw.TextSpan(
                        text: gradeNom,
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            if (!isSouche) _field('MATRICULE', apprenant.matricule ?? ''),
            _field('POUR SE RENDRE A', permission.localite ?? ''),
            _field('DUREE', '$duree JOURS'),
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 5),
              child: pw.RichText(
                text: pw.TextSpan(
                  children: [
                    pw.TextSpan(
                      text: 'DU : ',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.TextSpan(
                      text: '${_dateFmt.format(permission.dateDepart)}   ',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                    pw.TextSpan(
                      text: 'AU',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.TextSpan(
                      text:
                          '   ${_dateFmt.format(permission.dateRetour)}   INCLUS',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                  ],
                ),
              ),
            ),
            _field('MOTIF', permission.motif ?? ''),
            _field('CONTACT', permission.personneContact ?? ''),
            _field(
              "PERSONNE A PREVENIR EN CAS D'URGENCE",
              urgence.isEmpty ? '' : urgence,
            ),
          ],
        ),
      ),
      pw.SizedBox(height: 18),
      if (isSouche)
        pw.Column(
          children: [
            for (final role in const [
              "PRESIDENT DE L'AMICALE",
              'ADJUDANT DE DIVISION',
              'COMMANDANT DE DIVISION',
              'CHEF GRH',
            ])
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 14),
                child: pw.Row(
                  children: [
                    pw.Text(role, style: const pw.TextStyle(fontSize: 8)),
                    pw.Expanded(
                      child: pw.Container(
                        margin: const pw.EdgeInsets.only(left: 8),
                        height: 1,
                        color: PdfColors.grey400,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        )
      else
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
    ],
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
