/// SERVICE
class Service {
  final String id; // IDSERVICE
  final String libelle; // LIBELLE_SERVICE
  const Service({required this.id, required this.libelle});
}

/// CELLULE — rattachée à un SERVICE.
class Cellule {
  final String id; // IDCELLULE
  final String libelle; // LIBELLE_CELLULE
  final String serviceId; // IDSERVICE
  const Cellule({
    required this.id,
    required this.libelle,
    required this.serviceId,
  });
}
