/// Les deux bureaux qui se partagent la scolarité.
///
/// L'école ne tient pas « la scolarité » d'un seul tenant : deux bureaux s'y
/// partagent le travail, et jusqu'ici l'application les mêlait dans un seul
/// écran à sept onglets. Chacun n'y avait affaire qu'à trois ou quatre.
///
///  - **Instruction** tient la notation : les modules, le contrôle continu,
///    les examens, et les résultats qui s'en déduisent.
///  - **Ressources humaines** tient la personne : qui est au rang, qui est en
///    permission, qui est absent, qui est à l'infirmerie, et ce que l'effectif
///    donne à lire — sans les notes, qui ne les regardent pas.
///
/// La liste nominative et la fiche de chacun appartiennent aux deux : c'est le
/// même écran, le même effectif, avec autour le jeu d'onglets du bureau où
/// l'on se trouve. Rien n'est retiré à personne par ce découpage ; il ne fait
/// que cesser de montrer à chacun le travail de l'autre.
enum Bureau {
  instruction,
  ressourcesHumaines;

  /// Le titre de l'écran, et le nom du bureau dans la barre de navigation.
  String get libelle => switch (this) {
    Bureau.instruction => 'Instruction',
    Bureau.ressourcesHumaines => 'Ressources humaines',
  };

  /// Le titre de l'écran de l'effectif sous ce bureau.
  ///
  /// L'instruction garde « Élèves & Stagiaires » : son entrée de menu porte
  /// déjà ce nom, et sous la rubrique de l'administrateur c'est l'intitulé de
  /// l'onglet. Les RH n'ont qu'un écran, qui porte donc le nom du bureau.
  String get titreEffectif => switch (this) {
    Bureau.instruction => 'Élèves & Stagiaires',
    Bureau.ressourcesHumaines => 'Ressources humaines',
  };

  /// Ce que l'écran annonce sous son titre : de quoi ce bureau répond.
  String get propos => switch (this) {
    Bureau.instruction =>
      "Les modules, le contrôle continu, les examens et les résultats de "
          "l'effectif retenu.",
    Bureau.ressourcesHumaines =>
      "La situation de l'effectif retenu : prise d'armes, statistiques, "
          "consultations, permissions, absences.",
  };
}
