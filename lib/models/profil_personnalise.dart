/// Un service que l'école crée elle-même.
///
/// L'Officier Adjoint répartit les tâches d'une activité entre quatre services
/// écrits dans le code — soutien pétrolier, garage, armurerie, service de
/// santé. L'école en compte d'autres, et en comptera d'autres encore :
/// intendance, section des sports, transmissions. Ceux-là vivent en base, et
/// naissent sans qu'on recompile quoi que ce soit.
class ProfilPersonnalise {
  const ProfilPersonnalise({
    required this.id,
    required this.libelle,
    this.description,
    this.actif = true,
  });

  final String id;
  final String libelle;
  final String? description;

  /// Un profil retiré ne reçoit plus de tâches et n'ouvre plus de compte,
  /// mais les tâches qu'il a déjà reçues gardent son nom : les effacer
  /// trouerait l'historique des activités.
  final bool actif;

  factory ProfilPersonnalise.fromJson(Map<String, dynamic> json) =>
      ProfilPersonnalise(
        id: json['id'].toString(),
        libelle: json['libelle'] as String,
        description: json['description'] as String?,
        actif: (json['actif'] as bool?) ?? true,
      );
}
