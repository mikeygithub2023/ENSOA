/// Pannes et demandes de mise en réparation.
///
/// Une PANNE est un signalement attaché à un véhicule — elle n'affecte pas son
/// état, un véhicule peut en porter et rester disponible. Une DEMANDE DE MISE
/// EN RÉPARATION est la décision de réparer, prise au vu des pannes : demandée,
/// puis validée par un supérieur — c'est alors que le véhicule passe en
/// réparation — ou refusée.
library;

enum GravitePanne { legere, majeure, critique }

extension GravitePanneInfos on GravitePanne {
  String get label => switch (this) {
    GravitePanne.legere => 'Légère',
    GravitePanne.majeure => 'Majeure',
    GravitePanne.critique => 'Critique',
  };

  String get valeurDb => switch (this) {
    GravitePanne.legere => 'legere',
    GravitePanne.majeure => 'majeure',
    GravitePanne.critique => 'critique',
  };
}

GravitePanne graviteDepuisDb(String valeur) => switch (valeur) {
  'majeure' => GravitePanne.majeure,
  'critique' => GravitePanne.critique,
  _ => GravitePanne.legere,
};

class Panne {
  final String id;
  final String vehiculeId;
  final String description;
  final GravitePanne gravite;
  final DateTime dateSignalement;
  final String signaleParId;

  /// Renseignée quand la panne est reprise dans une demande de réparation.
  final String? demandeId;
  final bool resolue;

  /// La réparation pendant laquelle la panne a été décelée, quand elle n'a
  /// pas été signalée avant.
  final String? reparationId;

  const Panne({
    required this.id,
    required this.vehiculeId,
    required this.description,
    this.gravite = GravitePanne.legere,
    required this.dateSignalement,
    required this.signaleParId,
    this.demandeId,
    this.resolue = false,
    this.reparationId,
  });
}

/// Une panne décelée au garage et laissée en l'état, à consigner au retour
/// sur base.
class PanneDecelee {
  final String description;
  final GravitePanne gravite;

  const PanneDecelee(this.description, this.gravite);
}

enum StatutDemandeReparation { demandee, validee, refusee }

extension StatutDemandeReparationInfos on StatutDemandeReparation {
  String get label => switch (this) {
    StatutDemandeReparation.demandee => 'En attente',
    StatutDemandeReparation.validee => 'Validée',
    StatutDemandeReparation.refusee => 'Refusée',
  };

  String get valeurDb => switch (this) {
    StatutDemandeReparation.demandee => 'demandee',
    StatutDemandeReparation.validee => 'validee',
    StatutDemandeReparation.refusee => 'refusee',
  };
}

StatutDemandeReparation statutDemandeDepuisDb(String valeur) =>
    switch (valeur) {
      'validee' => StatutDemandeReparation.validee,
      'refusee' => StatutDemandeReparation.refusee,
      _ => StatutDemandeReparation.demandee,
    };

class DemandeReparation {
  final String id;
  final String vehiculeId;
  final StatutDemandeReparation statut;
  final String? commentaire;
  final DateTime dateDemande;
  final String demandeParId;
  final DateTime? dateDecision;
  final String? decideParId;

  /// La réparation ouverte le jour de la validation ; nulle avant.
  final String? reparationId;

  const DemandeReparation({
    required this.id,
    required this.vehiculeId,
    this.statut = StatutDemandeReparation.demandee,
    this.commentaire,
    required this.dateDemande,
    required this.demandeParId,
    this.dateDecision,
    this.decideParId,
    this.reparationId,
  });
}
