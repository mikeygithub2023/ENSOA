/// Le grade que porte un élève du fait de la phase où il se trouve, et de la
/// division qui la donne.
///
/// Ce n'est pas une étiquette qu'on choisit : un élève en FCB ou en CA 1 est
/// « de première année », en CA 2 il est « de deuxième année ». La valeur est
/// proposée à l'inscription et à l'import, et reste modifiable — un cas
/// particulier se corrige à la main.
///
/// La Formation Commune de Base se fait des deux côtés de l'école : la
/// Division de Formation Initiale la fait passer à ses généralistes, la
/// Division de Formation des Spécialistes à ses spécialistes. Même nom de
/// phase, deux grades — d'où [divisionCode]. Les phases nommées ESOS 1 et
/// ESOS 2 disent la spécialité dans leur nom et n'en ont pas besoin.
///
/// La même règle vit côté base (`scolarite.grade_de_la_phase`), qui l'applique
/// au passage d'une phase à la suivante : sans elle, une promotion entière
/// passerait en CA 2 en restant « de première année » sur ses bulletins. Si
/// vous modifiez ce barème, modifiez aussi celui-là.
library;

/// Le code de la Division de Formation des Spécialistes, tel que
/// `socle.divisions` le porte.
const String codeDivisionSpecialistes = 'formation_specialistes';

String? defaultGradeForClasse(String classeNom, {String? divisionCode}) {
  // Les noms se saisissent à la main : « CA 1 », « CA1 » et « ca 1 » désignent
  // la même phase.
  final cle = classeNom.toUpperCase().replaceAll(' ', '');
  final specialiste = divisionCode == codeDivisionSpecialistes;

  return switch (cle) {
    'FCB' || 'CA1' =>
      specialiste
          ? "Elève sous-officier spécialiste de première année"
          : "Elève sous-officier d'active de première année",
    'ESOA1' => "Elève sous-officier d'active de première année",
    'CA2' =>
      specialiste
          ? "Elève sous-officier spécialiste de deuxième année"
          : "Elève sous-officier d'active de deuxième année",
    'ESOA2' => "Elève sous-officier d'active de deuxième année",
    'ESOS1' => "Elève sous-officier spécialiste de première année",
    'ESOS2' => "Elève sous-officier spécialiste de deuxième année",
    _ => null,
  };
}
