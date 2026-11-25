// Où en est un dossier de pension.
//
// La question se pose deux cents fois : « lesquels sont prêts ? » Y
// répondre, c'est confronter le catalogue des pièces exigées aux
// vérifications faites. Trois réponses possibles, et une quatrième qu'il
// faut distinguer des autres — le catalogue est vide, personne ne l'a
// encore saisi, et l'écran ne doit alors annoncer ni complet ni incomplet.
//
// Rendu en fonction pure, et éprouvé dans
// `test/pension_decorations_test.dart` : un dossier annoncé complet à tort
// est un homme qui part à la retraite sans sa pension.

import '../../models/pension.dart';

/// Ce qu'on peut dire d'un dossier.
enum EtatDossier {
  /// Aucune pièce au catalogue : il n'y a rien à vérifier, et le dire
  /// « incomplet » accuserait le bureau d'un manquement qui n'est pas le
  /// sien.
  sansCatalogue,

  /// Le catalogue existe, mais aucune pièce n'a été vérifiée pour cet
  /// homme.
  nonVerifie,

  /// Une pièce exigée au moins manque, ou n'a pas été vérifiée.
  incomplet,

  /// Toutes les pièces exigées sont au dossier.
  complet,
}

/// Le compte, pour un militaire.
class BilanDossierPension {
  const BilanDossierPension({
    required this.etat,
    required this.exigeesTotal,
    required this.exigeesPresentes,
    required this.piecesActives,
    required this.presentes,
    required this.verifiees,
  });

  final EtatDossier etat;

  /// Les pièces dont dépend la complétude : les obligatoires s'il y en a,
  /// toutes les pièces actives sinon.
  final int exigeesTotal;
  final int exigeesPresentes;

  /// Le catalogue en service.
  final int piecesActives;

  /// Toutes pièces confondues, obligatoires ou non.
  final int presentes;

  /// Les pièces sur lesquelles quelqu'un s'est prononcé — présentes ou
  /// manquantes. « Non vérifié » et « manquant » ne sont pas la même
  /// chose, et le bureau a besoin de les distinguer.
  final int verifiees;

  int get exigeesManquantes => exigeesTotal - exigeesPresentes;

  /// Ce que l'écran affiche d'un coup d'œil.
  String get libelle => switch (etat) {
    EtatDossier.sansCatalogue => 'Aucune pièce au catalogue',
    EtatDossier.nonVerifie => 'Non vérifié',
    EtatDossier.complet => 'Complet',
    EtatDossier.incomplet =>
      exigeesManquantes == 1
          ? '1 pièce à réunir'
          : '$exigeesManquantes pièces à réunir',
  };
}

/// Confronte le catalogue aux vérifications d'un militaire.
///
/// [pieces] ne doit porter que les pièces actives — une pièce retirée du
/// dossier ne manque plus. [lignes] ne doit porter que celles de ce
/// militaire ; les lignes qui visent une pièce désactivée sont ignorées.
BilanDossierPension bilanDuDossier({
  required List<PiecePension> pieces,
  required List<LignePension> lignes,
}) {
  final actives = pieces.where((p) => p.active).toList();
  if (actives.isEmpty) {
    return const BilanDossierPension(
      etat: EtatDossier.sansCatalogue,
      exigeesTotal: 0,
      exigeesPresentes: 0,
      piecesActives: 0,
      presentes: 0,
      verifiees: 0,
    );
  }

  final idsActifs = {for (final p in actives) p.id};
  final retenues = {
    for (final l in lignes)
      if (idsActifs.contains(l.pieceId)) l.pieceId: l,
  };

  // Les obligatoires font la complétude. Sans aucune obligatoire, c'est le
  // catalogue entier qui l'emporte : sinon un catalogue tout facultatif
  // rendrait tous les dossiers complets d'avance.
  final obligatoires = actives.where((p) => p.obligatoire).toList();
  final exigees = obligatoires.isEmpty ? actives : obligatoires;

  final exigeesPresentes = exigees
      .where((p) => retenues[p.id]?.presente ?? false)
      .length;
  final presentes = actives
      .where((p) => retenues[p.id]?.presente ?? false)
      .length;

  final etat = retenues.isEmpty
      ? EtatDossier.nonVerifie
      : exigeesPresentes == exigees.length
      ? EtatDossier.complet
      : EtatDossier.incomplet;

  return BilanDossierPension(
    etat: etat,
    exigeesTotal: exigees.length,
    exigeesPresentes: exigeesPresentes,
    piecesActives: actives.length,
    presentes: presentes,
    verifiees: retenues.length,
  );
}

/// Range deux dates de retraite par urgence : la plus proche d'abord, et
/// celles qu'on ne connaît pas à la fin.
///
/// Une fiche sans date de retraite n'est pas urgente — elle est inconnue.
/// La mettre en tête ferait passer l'ignorance pour une alerte.
int compareUrgenceRetraite(DateTime? a, DateTime? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return a.compareTo(b);
}
