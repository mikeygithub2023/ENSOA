import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../models/depense.dart';
import '../apprenants/pdf_header.dart';

final _dateFmt = DateFormat('dd/MM/yyyy');

/// État des dépenses du service médical sur une période, présenté par
/// date : un bloc par journée, avec le détail de chaque dépense et le
/// sous-total du jour, puis le total général. L'en-tête institutionnel est
/// celui des permissions (voir [buildInstitutionalHeader]), repris en tête
/// de chaque page pour que l'état reste identifiable une fois agrafé.
/// [armoiries] est le PNG des armoiries de Côte d'Ivoire, chargé par
/// l'appelant (ce fichier reste indépendant de Flutter/rootBundle pour
/// pouvoir être testé en Dart pur). [theme] porte la typographie commune
/// aux documents imprimés (voir `chargerThemePdf`). [filtre] rappelle, le
/// cas échéant, la nature de dépense sur laquelle la liste imprimée est
/// restreinte.
pw.Document buildDepensesPdf(
  List<Depense> depenses, {
  required Uint8List armoiries,
  required DateTime debut,
  required DateTime fin,
  TypeDepense? filtre,
  pw.ThemeData? theme,
}) {
  final doc = pw.Document(theme: theme);
  final armoiriesImage = pw.MemoryImage(armoiries);

  // Un état comptable se lit dans l'ordre chronologique, à l'inverse de la
  // liste à l'écran qui met les dépenses les plus récentes en tête.
  final parJour = <DateTime, List<Depense>>{};
  for (final depense in depenses) {
    final jour = DateTime(
      depense.dateDepense.year,
      depense.dateDepense.month,
      depense.dateDepense.day,
    );
    parJour.putIfAbsent(jour, () => []).add(depense);
  }
  final jours = parJour.keys.toList()..sort();
  final total = depenses.fold<int>(0, (somme, d) => somme + d.montant);

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
              'BOUAKÉ, LE ${_dateFmt.format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ],
        ),
        pw.SizedBox(height: 14),
        pw.Center(
          child: pw.Text(
            'ÉTAT DES DÉPENSES DU SERVICE MÉDICAL',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              decoration: pw.TextDecoration.underline,
            ),
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Center(
          child: pw.Text(
            'Période du ${_dateFmt.format(debut)} au ${_dateFmt.format(fin)}'
            // Tiret simple, pas un tiret cadratin : les polices intégrées au
            // PDF (Helvetica) n'ont pas le glyphe « — » et l'impriment en
            // carré vide.
            '${filtre == null ? '' : ' - ${filtre.label}'}',
            style: const pw.TextStyle(fontSize: 9),
          ),
        ),
        pw.SizedBox(height: 14),
        if (jours.isEmpty)
          pw.Center(
            child: pw.Text(
              'Aucune dépense enregistrée sur la période.',
              style: const pw.TextStyle(fontSize: 9),
            ),
          )
        else
          for (final jour in jours) _blocJour(jour, parJour[jour]!),
        pw.SizedBox(height: 6),
        _ligneTotal('TOTAL GÉNÉRAL', total),
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

/// Une journée de dépenses : bandeau de date, détail des dépenses, puis le
/// sous-total du jour.
pw.Widget _blocJour(DateTime jour, List<Depense> depenses) {
  final sousTotal = depenses.fold<int>(0, (somme, d) => somme + d.montant);

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        color: PdfColors.grey300,
        child: pw.Text(
          _dateFmt.format(jour).toUpperCase(),
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        ),
      ),
      pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
        columnWidths: const {
          0: pw.FlexColumnWidth(2.3),
          1: pw.FlexColumnWidth(4.6),
          2: pw.FlexColumnWidth(2.8),
          3: pw.FlexColumnWidth(1.8),
        },
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey200),
            children: [
              _entete('POSTE'),
              _entete('LIBELLÉ'),
              _entete('CONCERNÉ'),
              _entete('MONTANT (FCFA)', alignRight: true),
            ],
          ),
          for (final depense in depenses)
            pw.TableRow(
              children: [
                _cellule(depense.categorie.label),
                _cellule(_libelleDetaille(depense)),
                _cellule(_concerne(depense)),
                _cellule(formatMontant(depense.montant), alignRight: true),
              ],
            ),
        ],
      ),
      pw.SizedBox(height: 3),
      _ligneTotal(
        'Sous-total du ${_dateFmt.format(jour)}',
        sousTotal,
        petit: true,
      ),
      pw.SizedBox(height: 10),
    ],
  );
}

/// Le libellé saisi, complété des observations quand il y en a — l'état
/// imprimé doit se suffire à lui-même.
String _libelleDetaille(Depense depense) {
  final observations = depense.observations;
  if (observations == null || observations.isEmpty) return depense.libelle;
  return '${depense.libelle}\n$observations';
}

/// Colonne "concerné" : le patient et la consultation d'origine pour une
/// dépense de consultation, la mention du service pour les besoins
/// courants.
String _concerne(Depense depense) {
  if (depense.type == TypeDepense.service) return 'Service médical';
  final patient = depense.patient ?? 'Patient inconnu';
  final matricule = depense.apprenantMatricule;
  final consultation = depense.dateConsultation;
  return [
    matricule == null || matricule.isEmpty ? patient : '$patient ($matricule)',
    if (consultation != null)
      'Consultation du ${_dateFmt.format(consultation)}',
  ].join('\n');
}

pw.Widget _ligneTotal(String label, int montant, {bool petit = false}) {
  final taille = petit ? 8.0 : 10.0;
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.end,
    children: [
      pw.Text(
        '$label : ',
        style: pw.TextStyle(fontSize: taille, fontWeight: pw.FontWeight.bold),
      ),
      pw.Text(
        '${formatMontant(montant)} FCFA',
        style: pw.TextStyle(fontSize: taille, fontWeight: pw.FontWeight.bold),
      ),
    ],
  );
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

pw.Widget _cellule(String valeur, {bool alignRight = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
    child: pw.Text(
      valeur,
      textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
      style: const pw.TextStyle(fontSize: 7.5),
    ),
  );
}
