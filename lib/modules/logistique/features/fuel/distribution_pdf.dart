import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:sig_ensoa/modules/scolarite/features/apprenants/pdf_fonts.dart';
import '../../data/models/user.dart';
import '../../data/repositories/fuel_providers.dart';

/// Construit l'état des distributions au format strict de l'imprimé officiel
/// ENSOA (en-tête EMGA/ENSOA, armoiries, tableau NOM ET PRENOMS / CONTACT /
/// VEHICULE / IMMATRICULATION / QUANTITE / DATE / SOUTIER).
///
/// Rend les octets du document plutôt que de l'imprimer : l'appelant les
/// passe à `showPdfPreviewDialog`, comme le font les sept autres documents de
/// l'application. L'ancienne version ouvrait directement la boîte
/// d'impression du système — on ne voyait le document qu'une fois le choix de
/// l'imprimante fait, et une colonne de travers coûtait une feuille.
///
/// [souteLibelle] nul veut dire « toutes les soutes » : le service tient aussi
/// un état d'ensemble, et rien ne justifiait de le lui refuser.
Future<Uint8List> construireEtatDistributions({
  required String? souteLibelle,
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

  // Les polices intégrées au format PDF n'ont ni tiret cadratin ni lettres
  // accentuées : les documents de la scolarité embarquent donc une vraie
  // police, et celui-ci l'avait été oublié. Voir `chargerThemePdf`.
  final doc = pw.Document(theme: await chargerThemePdf());
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
              souteLibelle == null
                  ? 'TOUTES LES SOUTES'
                  : 'SOUTE DE ${souteLibelle.toUpperCase()}',
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
            0: pw.Alignment.center,
            3: pw.Alignment.center,
            4: pw.Alignment.center,
            5: pw.Alignment.center,
            6: pw.Alignment.center,
          },
          // Huit colonnes tiennent mal en largeur automatique : le nom se
          // repliait sur trois lignes pendant que la date gardait sa place.
          // Les proportions sont donc fixées, les colonnes libres au texte
          // (nom, soutier) servies les premières.
          columnWidths: const {
            0: pw.FlexColumnWidth(1.1),
            1: pw.FlexColumnWidth(2.6),
            2: pw.FlexColumnWidth(1.3),
            3: pw.FlexColumnWidth(1.5),
            4: pw.FlexColumnWidth(1.6),
            5: pw.FlexColumnWidth(1.2),
            6: pw.FlexColumnWidth(1.4),
            7: pw.FlexColumnWidth(1.9),
          },
          border: pw.TableBorder.all(width: 0.4, color: PdfColors.grey400),
          headers: const [
            // La date ouvre la ligne : c'est par elle qu'on retrouve une
            // remise dans un état qui en compte cent. Les lignes arrivent
            // ici de la plus récente à la plus ancienne, comme à l'écran.
            'DATE',
            'NOM ET PRENOMS',
            'CONTACT',
            'VEHICULE',
            'IMMATRICULATION',
            'QUANTITE',
            // L'allocation sur laquelle le carburant est imputé. Elle suit
            // la quantité : c'est la même question — combien, et à la
            // charge de qui.
            'REPARTITION',
            'SOUTIER',
          ],
          data: [
            for (final v in lignes)
              [
                df.format(v.distribution.date),
                '${v.distribution.gradeDestinataire ?? ''} ${v.distribution.destinataire}'
                    .trim(),
                v.distribution.contact ?? '—',
                v.distribution.vehicule ?? '—',
                v.distribution.vhlImmatriculation ?? '—',
                '${v.distribution.typeCarburant} ${v.distribution.quantitePercue} L',
                v.repartitionLibelle,
                _libelleSoutier(resoudreSoutier(v.distribution.utilisateurId)),
              ],
          ],
        ),
      ],
    ),
  );

  return doc.save();
}

/// Le nom du soutier, ou ce qui en tient lieu.
///
/// Le repli était un tiret cadratin, que les polices intégrées au format PDF
/// ne possèdent pas : la colonne semblait porter une icône plutôt qu'un nom.
/// On l'écrit en toutes lettres — et le document embarque désormais une
/// police, si bien que l'accent s'imprime aussi.
String _libelleSoutier(AppUser? u) {
  if (u == null) return 'Non identifié';
  final nomme = '${u.grade} ${u.nomComplet}'.trim();
  return nomme.isEmpty ? 'Non identifié' : nomme;
}
