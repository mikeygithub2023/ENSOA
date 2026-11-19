/// Une section regroupe les élèves d'une promotion.
///
/// Elle s'attache à la **promotion**, pas à la phase : l'élève entre en
/// section à l'incorporation et la garde jusqu'à sa sortie, tandis que les
/// phases se succèdent sous lui. C'est la même distinction que celle posée
/// par la migration 065 — la promotion rattache, la phase situe.
///
/// Un stage n'a pas de sections : il n'a pas de promotion non plus.
class Section {
  const Section({
    required this.id,
    required this.promotionId,
    required this.nom,
    this.ordre = 0,
  });

  final String id;
  final String promotionId;
  final String nom;

  /// Rang de la section dans sa promotion. Les sections se nomment
  /// « 1ère », « 2ème »… : trier sur le nom les mettrait dans le désordre
  /// dès la dixième.
  final int ordre;

  factory Section.fromJson(Map<String, dynamic> json) {
    return Section(
      id: json['id'] as String,
      promotionId: json['promotion_id'] as String,
      nom: json['nom'] as String,
      ordre: json['ordre'] as int? ?? 0,
    );
  }
}
