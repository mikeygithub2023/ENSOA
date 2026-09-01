/// Correspond à HISTORIQUE côté HFSQL (IDHISTORIQUE, DATE_HISTORIQUE,
/// LIBELLE_HISTORIQUE, NOM_UTILISATEUR, IDSERVICE) — [action]/[cible]/[detail]
/// sont une structuration app-side, à composer en LIBELLE_HISTORIQUE unique
/// au moment de la synchronisation.
class AuditEntry {
  final String id;
  final DateTime date;
  final String auteurId;
  final String action;
  final String cible;
  final String? detail;

  const AuditEntry({
    required this.id,
    required this.date,
    required this.auteurId,
    required this.action,
    required this.cible,
    this.detail,
  });
}
