import '../../models/controle.dart';
import '../../models/matiere.dart';
import '../../models/note.dart';
import '../../models/sous_module.dart';

/// Règle de calcul des moyennes, partagée par le bulletin imprimé et les
/// statistiques d'une classe/stage : les deux doivent donner le même chiffre
/// pour le même apprenant, sans quoi l'un des deux ment.
///
/// Un apprenant sans note à une évaluation y est « non classé » : cette
/// évaluation est écartée du calcul, jamais comptée comme un zéro.

/// Coefficient de chaque matière pour une classe/stage, lu en direct depuis
/// l'écran Matières (contrairement au coefficient d'un module, figé sur le
/// contrôle lui-même).
Map<String, num> coefficientsMatieres(
  List<MatiereModule> matiereModules,
  String classeId,
) {
  return {
    for (final module in matiereModules)
      if (module.classeId == classeId) module.matiereId: module.coefficient,
  };
}

/// Note d'un module : la moyenne pondérée de ses sous-modules.
///
/// Un module ne porte plus de note directe. Chaque sous-module a son
/// coefficient dans la phase, et le sport n'y fait pas exception : ses
/// épreuves sont des sous-modules comme les autres, à ceci près que leur
/// note vient d'une performance et d'un barème plutôt que de la main de
/// l'instructeur.
///
/// Un sous-module sans note est écarté du calcul — jamais compté comme un
/// zéro, conformément à la règle de l'école. `null` si aucun n'est noté.
num? moyenneSousModules(
  List<Note> notes,
  String controleId,
  List<SousModule> sousModules,
) {
  final duModule = sousModules.where((s) => s.moduleId == controleId);
  if (duModule.isEmpty) return null;

  num totalCoef = 0;
  num totalPoints = 0;
  for (final sousModule in duModule) {
    final note = _noteDuSousModule(notes, sousModule.id);
    if (note == null) continue;
    totalCoef += sousModule.coefficient;
    totalPoints += note * sousModule.coefficient;
  }
  return totalCoef == 0 ? null : totalPoints / totalCoef;
}

num? _noteDuSousModule(List<Note> notes, String sousModuleId) {
  for (final note in notes) {
    if (note.sousModuleId == sousModuleId) return note.note;
  }
  return null;
}

/// Moyenne des notes par matière d'un contrôle continu/examen, pondérée par
/// le coefficient de chaque matière (1 par défaut si la matière n'a pas de
/// coefficient affecté pour cette classe).
num? moyenneMatieres(
  List<Note> notes,
  String controleId,
  Map<String, num> coefMatiereById,
) {
  num totalCoef = 0;
  num totalPoints = 0;
  var trouvee = false;
  for (final note in notes) {
    if (note.controleId != controleId) continue;
    trouvee = true;
    final coef = coefMatiereById[note.matiereId] ?? 1;
    totalCoef += coef;
    totalPoints += note.note * coef;
  }
  if (!trouvee || totalCoef == 0) return null;
  return totalPoints / totalCoef;
}

/// Note d'un apprenant à une évaluation, quelle qu'en soit la nature —
/// `null` s'il n'y est pas classé.
num? noteAuControle(
  Controle controle,
  List<Note> notes,
  Map<String, num> coefMatiereById, {
  List<SousModule> sousModules = const [],
}) {
  // Le module Sport se calcule comme un module : ses séances sont ses
  // sous-modules, toutes de coefficient 1.
  return controle.type == ControleType.module ||
          controle.type == ControleType.sport
      ? moyenneSousModules(notes, controle.id, sousModules)
      : moyenneMatieres(notes, controle.id, coefMatiereById);
}

/// Moyenne pondérée d'un apprenant sur [controles], chaque évaluation pesant
/// son propre coefficient. `null` s'il n'est classé nulle part.
///
/// [notes] ne doit contenir que les notes de cet apprenant.
num? moyenneGenerale({
  required List<Controle> controles,
  required List<Note> notes,
  required Map<String, num> coefMatiereById,
  List<SousModule> sousModules = const [],
}) {
  num totalCoef = 0;
  num totalPoints = 0;
  for (final controle in controles) {
    final note = noteAuControle(
      controle,
      notes,
      coefMatiereById,
      sousModules: sousModules,
    );
    if (note == null) continue;
    totalCoef += controle.coefficient;
    totalPoints += note * controle.coefficient;
  }
  return totalCoef == 0 ? null : totalPoints / totalCoef;
}
