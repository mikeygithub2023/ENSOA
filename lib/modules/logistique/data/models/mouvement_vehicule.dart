/// MOUVEMENT — trajet/déplacement d'un véhicule (mission, sortie autorisée),
/// PAS un mouvement de carburant malgré le nom. Sert au contrôle croisé
/// missions/déplacements demandé par le cahier des charges.
enum EtatMouvement { enCours, termine, annule }

extension EtatMouvementLabel on EtatMouvement {
  String get label {
    switch (this) {
      case EtatMouvement.enCours:
        return 'En cours';
      case EtatMouvement.termine:
        return 'Terminé';
      case EtatMouvement.annule:
        return 'Annulé';
    }
  }
}

class MouvementVehicule {
  final String id; // IDMOUVEMENT
  final String objet; // OBJET_MOUVEMENT
  final DateTime dateDepart; // DATE_DEPART_MOUVEMENT
  final DateTime? dateFin; // DATE_FIN_MOUVEMENT
  final EtatMouvement etat; // ETAT_MOUVEMENT
  final String vehiculeId; // IDVEHICULE
  final String utilisateurId; // IDUTILISATEUR
  final int kmDepart; // KM_DEPART
  final int? kmArrivee; // KM_ARRIVE
  final String destination; // DESTINATION
  final String gradeChefBord; // GRADE_CHEF_BORD
  final String nomChefBord; // NOM_CHEF_BORD
  final String contactChefBord; // CONTACT_CHEF_BORD

  const MouvementVehicule({
    required this.id,
    required this.objet,
    required this.dateDepart,
    this.dateFin,
    this.etat = EtatMouvement.enCours,
    required this.vehiculeId,
    required this.utilisateurId,
    required this.kmDepart,
    this.kmArrivee,
    required this.destination,
    required this.gradeChefBord,
    required this.nomChefBord,
    required this.contactChefBord,
  });
}
