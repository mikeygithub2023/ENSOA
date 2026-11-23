import '../../models/classe.dart';
import '../../models/division.dart';

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
          "consultations, permissions, absences, locaux disciplinaires.",
  };
}

/// Les divisions que ce bureau propose dans son filtre.
///
/// La Division de Commandement et Logistique n'instruit personne : elle n'a
/// ni promotion, ni phase, ni note, et regroupe le personnel de l'école.
/// L'instruction ne la propose donc pas — un bureau qui note des élèves n'a
/// rien à y chercher. Les ressources humaines, elles, la tiennent comme les
/// trois autres : la prise d'armes du matin compte toute l'école.
List<Division> divisionsDuBureau(List<Division> divisions, Bureau bureau) {
  if (bureau == Bureau.ressourcesHumaines) return divisions;
  return divisions.where((d) => !d.tientDuPersonnel).toList();
}

/// Cette portée permet-elle d'ouvrir une fiche — à la main ou par import ?
///
/// Deux cas, et deux seulement : une phase ou un stage où verser un élève,
/// ou bien une division qui tient du personnel, lequel n'est en formation
/// nulle part et s'enregistre donc sans phase. Sous « Toutes », ou sous une
/// division dont aucune promotion n'est retenue, on ne sait pas où écrire :
/// les boutons se taisent plutôt que d'échouer à l'enregistrement.
bool ouvreUneFiche({
  required Division? division,
  required Classe? classeInscription,
}) {
  if (division == null) return false;
  return classeInscription != null || division.tientDuPersonnel;
}
