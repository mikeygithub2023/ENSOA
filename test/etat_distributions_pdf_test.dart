import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:sig_ensoa/modules/logistique/data/models/carburant.dart';
import 'package:sig_ensoa/modules/logistique/data/repositories/fuel_providers.dart';
import 'package:sig_ensoa/modules/logistique/features/fuel/distribution_pdf.dart';
import 'package:sig_ensoa/modules/scolarite/features/apprenants/pdf_fonts.dart';

/// L'état des distributions tient dans la page, colonne « RÉPARTITION »
/// comprise.
///
/// Un tableau trop large ne lève aucune erreur : il déborde en silence, et
/// on ne s'en aperçoit qu'une fois la feuille sortie. On mesure donc les
/// textes avec la police réellement embarquée dans le document, et on les
/// confronte aux largeurs déclarées.
///
/// Le test ne juge que ce qui est mesurable — ce qui déborde, et ce qui se
/// replie. Il ne dit rien de l'élégance du résultat.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Les proportions déclarées dans `construireEtatDistributions`.
  const flex = <String, double>{
    'DATE': 1.1,
    'NOM ET PRENOMS': 2.6,
    'CONTACT': 1.3,
    'VEHICULE': 1.5,
    'IMMATRICULATION': 1.6,
    'QUANTITE': 1.2,
    'REPARTITION': 1.4,
    'SOUTIER': 1.9,
  };

  // Le contenu le plus large attendu dans chaque colonne, en service.
  const pires = <String, String>{
    'DATE': '02/03/2026',
    'NOM ET PRENOMS': 'MDL-CHEF Kouassi N\'Guessan Yao',
    'CONTACT': '07 00 00 00 00',
    'VEHICULE': 'Toyota Land Cruiser',
    'IMMATRICULATION': '1234 AA 01',
    'QUANTITE': 'Gasoil 10000 L',
    'REPARTITION': 'Activités Ordinaires',
    'SOUTIER': 'MDL-CHEF Kouassi N\'Guessan',
  };

  const marges = 28.0 + 28.0;
  const rembourrage = 5.0 + 5.0; // EdgeInsets.all(5), des deux côtés
  const taille = 9.0;

  late Map<String, double> largeurs;
  late PdfFont normale;
  late PdfFont grasse;

  setUpAll(() async {
    final theme = await chargerThemePdf();
    expect(
      theme,
      isNotNull,
      reason: 'aucune police : le document sortirait en caractères de repli, '
          'aux chasses différentes de celles mesurées ici',
    );
    final contexte = pw.Context(document: pw.Document().document);
    normale = theme!.defaultTextStyle.fontNormal!.getFont(contexte);
    grasse = theme.defaultTextStyle.fontBold!.getFont(contexte);

    final total = flex.values.reduce((a, b) => a + b);
    final utile = PdfPageFormat.a4.landscape.width - marges;
    largeurs = {
      for (final e in flex.entries) e.key: utile * e.value / total,
    };
  });

  double mesure(PdfFont police, String texte) =>
      police.stringMetrics(texte).width * taille;

  test('aucun en-tête ne se replie sur deux lignes', () {
    for (final colonne in flex.keys) {
      expect(
        mesure(grasse, colonne),
        lessThanOrEqualTo(largeurs[colonne]! - rembourrage),
        reason: 'l\'en-tête « $colonne » ne tient pas dans sa colonne',
      );
    }
  });

  test('aucun mot ne déborde de sa colonne', () {
    // Le texte se replie entre les mots : une cellule ne déborde vraiment
    // que si un mot seul dépasse la largeur disponible.
    for (final e in pires.entries) {
      for (final mot in e.value.split(' ')) {
        expect(
          mesure(normale, mot),
          lessThanOrEqualTo(largeurs[e.key]! - rembourrage),
          reason: '« $mot » déborde de la colonne ${e.key}',
        );
      }
    }
  });

  test('l\'état se construit avec la colonne répartition', () async {
    DistributionVue ligne(String destinataire, String repartition) =>
        DistributionVue(
          distribution: Distribution(
            id: '1',
            souteStockId: '10',
            utilisateurId: 'u1',
            quantitePercue: 40,
            date: DateTime(2026, 3, 2),
            typeCarburant: 'Gasoil',
            destinataire: destinataire,
            gradeDestinataire: 'SLT',
            contact: '07 00 00 00 00',
            vehicule: 'Toyota Land Cruiser',
            vhlImmatriculation: '1234 AA 01',
          ),
          souteLibelle: 'Soute Bouaké',
          repartitionLibelle: repartition,
        );

    final bytes = await construireEtatDistributions(
      souteLibelle: 'Soute Bouaké',
      sousTitre: 'DISTRIBUTION DE CARBURANT DU 01/03/2026 AU 31/03/2026',
      lignes: [
        ligne('Koné Mamadou', 'Activités Ordinaires'),
        ligne('Yao N\'Guessan', 'BA1'),
      ],
      resoudreSoutier: (_) => null,
    );

    // %PDF- : la signature du format, en tête de fichier.
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(1000));
  });
}
