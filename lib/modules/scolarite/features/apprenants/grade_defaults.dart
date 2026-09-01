/// Le grade que porte un élève du fait de la phase où il se trouve.
///
/// Ce n'est pas une étiquette qu'on choisit : un élève en FCB ou en CA 1 est
/// « de première année », en CA 2 il est « de deuxième année ». La valeur est
/// proposée à l'inscription et à l'import, et reste modifiable — un cas
/// particulier se corrige à la main.
///
/// La même règle vit côté base (`scolarite.grade_de_la_phase`), qui l'applique
/// au passage d'une phase à la suivante : sans elle, une promotion entière
/// passerait en CA 2 en restant « de première année » sur ses bulletins. Si
/// vous modifiez ce barème, modifiez aussi celui-là.
String? defaultGradeForClasse(String classeNom) {
  // Les noms se saisissent à la main : « CA 1 », « CA1 » et « ca 1 » désignent
  // la même phase.
  final cle = classeNom.toUpperCase().replaceAll(' ', '');

  return switch (cle) {
    'FCB' || 'CA1' || 'ESOA1' =>
      "Elève sous-officier d'active de première année",
    'CA2' || 'ESOA2' => "Elève sous-officier d'active de deuxième année",
    'ESOS1' => "Elève sous-officier spécialiste de première année",
    'ESOS2' => "Elève sous-officier spécialiste de deuxième année",
    _ => null,
  };
}
