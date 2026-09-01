import 'medicament.dart';

/// Une ligne de fiche de réapprovisionnement : un médicament et la quantité
/// commandée. [stockAuMomentDeLaDemande] est figé à la saisie — la fiche
/// réimprimée plus tard doit montrer la situation qui a motivé la commande,
/// pas le stock du jour où on la rouvre. [medicamentNom], [medicamentUnite]
/// et [medicamentType] sont lus par jointure en même temps que la ligne,
/// pour l'affichage et l'impression.
class LigneReapprovisionnement {
  const LigneReapprovisionnement({
    required this.id,
    required this.medicamentId,
    required this.quantiteDemandee,
    required this.stockAuMomentDeLaDemande,
    this.medicamentNom,
    this.medicamentUnite,
    this.medicamentType,
  });

  final String id;
  final String medicamentId;
  final int quantiteDemandee;
  final int stockAuMomentDeLaDemande;
  final String? medicamentNom;
  final String? medicamentUnite;
  final TypeMedicament? medicamentType;

  factory LigneReapprovisionnement.fromJson(Map<String, dynamic> json) {
    final medicament = json['medicaments'] as Map<String, dynamic>?;
    final type = medicament?['type'] as String?;
    return LigneReapprovisionnement(
      id: json['id'] as String,
      medicamentId: json['medicament_id'] as String,
      quantiteDemandee: json['quantite_demandee'] as int,
      stockAuMomentDeLaDemande: json['stock_au_moment_de_la_demande'] as int,
      medicamentNom: medicament?['nom'] as String?,
      medicamentUnite: medicament?['unite'] as String?,
      medicamentType: type == null ? null : typeMedicamentFromString(type),
    );
  }
}

/// Fiche de demande de réapprovisionnement de la pharmacie. Elle exprime un
/// besoin : elle ne touche pas au stock, qui ne bougera qu'à la réception
/// effective, par un mouvement de stock.
class DemandeReapprovisionnement {
  const DemandeReapprovisionnement({
    required this.id,
    required this.dateDemande,
    required this.lignes,
    this.observations,
  });

  final String id;
  final DateTime dateDemande;
  final List<LigneReapprovisionnement> lignes;
  final String? observations;

  /// Nombre total d'unités commandées, toutes lignes confondues.
  int get totalUnites =>
      lignes.fold<int>(0, (somme, ligne) => somme + ligne.quantiteDemandee);

  factory DemandeReapprovisionnement.fromJson(Map<String, dynamic> json) {
    final lignes =
        (json['demandes_reapprovisionnement_lignes'] as List<dynamic>? ??
                const [])
            .map(
              (e) =>
                  LigneReapprovisionnement.fromJson(e as Map<String, dynamic>),
            )
            .toList()
          ..sort(
            (a, b) => (a.medicamentNom ?? '').toLowerCase().compareTo(
              (b.medicamentNom ?? '').toLowerCase(),
            ),
          );

    return DemandeReapprovisionnement(
      id: json['id'] as String,
      dateDemande: DateTime.parse(json['date_demande'] as String),
      observations: json['observations'] as String?,
      lignes: lignes,
    );
  }
}
