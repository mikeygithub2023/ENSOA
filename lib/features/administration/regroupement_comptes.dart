import '../../core/postes.dart';
import '../../models/profil.dart';

/// La cellule où l'on cherche un compte : on pense « le garage », « la
/// santé », pas « le compte n° 27 ». Les comptes de l'école ne portent pas
/// de cellule en base ; c'est leur poste qui la dit, et pour un service créé
/// par l'administrateur, le nom de ce service.
String celluleDuPoste(Poste? poste) => switch (poste) {
  Poste.administrateur => 'Commandement et administration',
  Poste.chefDivision => 'Commandants de division',
  Poste.commandantPromotion => 'Commandants de promotion',
  Poste.commandantBrigade => 'Commandants de brigade',
  Poste.infirmerie => 'Service de santé',
  Poste.eleveStagiaire => 'Élèves / Stagiaires',
  Poste.chefSoutienTechnique => 'État-major Soutien technique',
  Poste.soutienPetrolier => 'Soutien pétrolier',
  Poste.garage => 'Garage',
  Poste.armurerie => 'Armurerie',
  Poste.postePolice => 'Poste de Police',
  Poste.officierAdjoint => 'Officiers adjoints',
  Poste.profilPersonnalise => 'Service non précisé',
  null => 'Poste non reconnu',
};

/// Les comptes rangés par cellule, dans l'ordre de l'organisation de
/// l'école ; les services créés suivent, par ordre alphabétique. Dans chaque
/// cellule, les comptes vont par ordre alphabétique du nom, puis du prénom.
///
/// [services] : le nom de chaque service créé, par identifiant.
List<(String, List<Profil>)> regrouperComptes(
  List<Profil> comptes,
  Map<String, String> services,
) {
  final parCellule = <String, List<Profil>>{};
  final rang = <String, (int, String)>{};

  for (final c in comptes) {
    final poste = posteDepuisRoles(c.roleScolarite, c.roleLogistique);
    final service = poste == Poste.profilPersonnalise
        ? services[c.profilPersonnaliseId]
        : null;
    final cellule = service ?? celluleDuPoste(poste);
    parCellule.putIfAbsent(cellule, () => []).add(c);
    rang[cellule] = poste == null
        ? (Poste.values.length + 1, '')
        : poste == Poste.profilPersonnalise
        ? (Poste.values.length, _cle(cellule))
        : (poste.index, '');
  }

  int parNom(Profil a, Profil b) {
    final noms = _cle(a.nom).compareTo(_cle(b.nom));
    return noms != 0 ? noms : _cle(a.prenom).compareTo(_cle(b.prenom));
  }

  final cellules = parCellule.keys.toList()
    ..sort((a, b) {
      final (ra, ca) = rang[a]!;
      final (rb, cb) = rang[b]!;
      return ra != rb ? ra.compareTo(rb) : ca.compareTo(cb);
    });
  return [for (final k in cellules) (k, parCellule[k]!..sort(parNom))];
}

/// « Élodie » se range avec les E, et « kone » avec « KONE ».
String _cle(String texte) {
  const accents = {
    'à': 'a',
    'â': 'a',
    'ä': 'a',
    'á': 'a',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'î': 'i',
    'ï': 'i',
    'í': 'i',
    'ô': 'o',
    'ö': 'o',
    'ó': 'o',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ú': 'u',
    'ç': 'c',
    'ÿ': 'y',
    'œ': 'oe',
    'æ': 'ae',
  };
  final b = StringBuffer();
  for (final ch in texte.trim().toLowerCase().split('')) {
    b.write(accents[ch] ?? ch);
  }
  return b.toString();
}
