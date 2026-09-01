import '../core/roles.dart';

/// Le profil applicatif d'un agent — une ligne de `socle.profiles`, une seule
/// pour toute l'école, quels que soient les modules dont il relève.
class Profil {
  const Profil({
    required this.id,
    required this.nom,
    required this.prenom,
    this.matricule,
    this.grade,
    this.titre,
    this.roleScolarite,
    this.roleLogistique,
    this.divisionId,
    this.celluleId,
    this.promotionId,
    this.actif = true,
    this.doitChangerMotDePasse = false,
  });

  final String id;
  final String nom;
  final String prenom;

  /// L'identifiant de connexion. Nul tant qu'un compte n'a pas été rattaché
  /// à une fiche militaire.
  final String? matricule;

  final String? grade;

  /// Le titre sous lequel on le nomme, quand il diffère du libellé de son
  /// poste — le Commandant de l'école tient le compte d'administrateur, mais
  /// on ne l'appelle pas « l'administrateur ». Nul pour la plupart.
  final String? titre;

  /// Les deux rôles, chacun facultatif. Les deux nuls : le compte existe mais
  /// n'ouvre rien — c'est l'état d'un compte créé mais pas encore affecté.
  final RoleScolarite? roleScolarite;
  final RoleLogistique? roleLogistique;

  /// La division d'enseignement (scolarité) et la cellule du service
  /// (soutien technique). Un agent peut relever des deux.
  final String? divisionId;
  final int? celluleId;

  /// La promotion que commande un Commandant de Brigade — elle borne ce qu'il
  /// voit et note. Nulle pour tous les autres.
  final String? promotionId;

  final bool actif;
  final bool doitChangerMotDePasse;

  String get nomComplet => '$prenom $nom'.trim();

  /// L'identité telle qu'on désigne un militaire : le grade, puis le nom. Le
  /// personnel civil n'ayant pas de grade, on retombe sur le seul nom.
  String get identiteComplete =>
      (grade == null || grade!.trim().isEmpty) ? nomComplet : '${grade!.trim()} $nomComplet';

  /// Les permissions cumulées des deux rôles.
  Set<Permission> get permissions =>
      permissionsDe(scolarite: roleScolarite, logistique: roleLogistique);

  bool peut(Permission permission) => permissions.contains(permission);

  /// Relève-t-il de ce module ? Sert à décider si on lui montre la section.
  bool get releveDeLaScolarite => roleScolarite != null;
  bool get releveDuSoutienTechnique => roleLogistique != null;

  /// Comment on le nomme à l'écran : son titre s'il en a un, sinon le libellé
  /// de son poste.
  String appellation(String? libelleDuPoste) {
    final propre = titre?.trim();
    if (propre != null && propre.isNotEmpty) return propre;
    return libelleDuPoste ?? 'Poste non reconnu';
  }

  factory Profil.fromJson(Map<String, dynamic> json) => Profil(
    id: json['id'] as String,
    nom: (json['nom'] as String?) ?? '',
    prenom: (json['prenom'] as String?) ?? '',
    matricule: json['matricule'] as String?,
    grade: json['grade'] as String?,
    titre: json['titre'] as String?,
    roleScolarite: roleScolariteDepuisDb(json['role'] as String?),
    roleLogistique: roleLogistiqueDepuisDb(json['role_logistique'] as String?),
    divisionId: json['division_id'] as String?,
    celluleId: json['cellule_id'] as int?,
    promotionId: json['promotion_id'] as String?,
    actif: (json['actif'] as bool?) ?? true,
    doitChangerMotDePasse: (json['doit_changer_mot_de_passe'] as bool?) ?? false,
  );
}
