import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Restreint à une promotion des données chargées pour toute une division.
///
/// Les onglets (Situation de Prise d'Armes, Consultations, Permissions,
/// Absences) interrogent la base par phase/stage quand l'un d'eux est
/// sélectionné, et par division sinon. Entre les deux se glisse la
/// promotion : elle ne correspond à aucune requête, mais ses phases sont
/// connues à l'écran. On filtre donc le résultat de la division sur ces
/// phases plutôt que d'ajouter un provider par promotion — la division est
/// déjà chargée, et l'effectif d'une promotion se lit dessus sans un
/// aller-retour de plus.
///
/// [classes] nul signifie « aucune restriction » : toute la division. Un
/// ensemble vide, lui, est une restriction réelle — une promotion sans
/// phase n'a aucun apprenant, et l'écran doit le montrer plutôt que de
/// retomber sur la division entière.
extension PorteePromotion<T> on AsyncValue<List<T>> {
  AsyncValue<List<T>> dansLesClasses(
    Set<String>? classes,
    String? Function(T) classeDe,
  ) {
    if (classes == null) return this;
    return whenData(
      (liste) => liste.where((e) => classes.contains(classeDe(e))).toList(),
    );
  }
}
