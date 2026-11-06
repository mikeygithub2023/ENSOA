import '../../data/models/oa.dart';

/// Une ligne de la liste des tâches, qu'elle vienne d'une activité ou de la
/// liste quotidienne de quelqu'un : l'écran les range et les filtre ensemble.
class LigneTache {
  const LigneTache({
    required this.cle,
    required this.titre,
    required this.echeance,
    required this.faite,
    required this.contexte,
    required this.activiteId,
    required this.personne,
    required this.aMoi,
    this.enAttenteVisa = false,
    this.priorite = PrioriteTache.normale,
    this.finieLe,
    this.detail,
    this.deActivite,
    this.quotidienne,
  });

  final String cle;
  final String titre;
  final DateTime? echeance;
  final bool faite;
  final bool enAttenteVisa;
  final PrioriteTache priorite;
  final DateTime? finieLe;

  /// Le nom de l'activité, ou « Tâche quotidienne ».
  final String contexte;

  /// Nul pour une tâche quotidienne.
  final String? activiteId;

  /// À qui elle revient : un service, ou une personne nommée.
  final String personne;

  /// La tâche me revient-elle ?
  final bool aMoi;

  /// « Imputée par… », le commentaire laissé en la terminant.
  final String? detail;

  final TacheActivite? deActivite;
  final TacheQuotidienne? quotidienne;

  /// Une échéance à minuit n'a pas d'heure : elle court toute la journée.
  bool get aUneHeure =>
      echeance != null && (echeance!.hour != 0 || echeance!.minute != 0);

  bool enRetard(DateTime maintenant) {
    if (faite || enAttenteVisa || echeance == null) return false;
    if (aUneHeure) return echeance!.isBefore(maintenant);
    return _jour(echeance!).isBefore(_jour(maintenant));
  }

  bool estLe(DateTime jour) =>
      echeance != null && _jour(echeance!) == _jour(jour);
}

DateTime _jour(DateTime d) => DateTime(d.year, d.month, d.day);

const cleToutesActivites = 'toutes';
const cleTachesQuotidiennes = 'quotidiennes';
const cleToutLeMonde = 'tous';
const cleMoi = 'moi';

enum SegmentTaches { toutes, aVenir, aujourdhui }

/// Réunit les deux sortes de tâches. Une tâche annulée n'attend plus rien et
/// ne paraît pas.
List<LigneTache> construireLignes({
  required List<TacheActivite> taches,
  required Set<String> mesTaches,
  required List<Activite> activites,
  required List<TacheQuotidienne> quotidiennes,
  required String? moi,
}) {
  final titres = {for (final a in activites) a.id: a.titre};
  return [
    for (final t in taches)
      if (t.statut != StatutTache.annulee)
        LigneTache(
          cle: 'activite:${t.id}',
          titre: t.description,
          echeance: t.dateLimite?.toLocal(),
          faite: t.statut == StatutTache.validee,
          enAttenteVisa: t.statut == StatutTache.terminee,
          finieLe: (t.valideeLe ?? t.termineeLe)?.toLocal(),
          contexte: titres[t.activiteId] ?? 'Activité',
          activiteId: t.activiteId,
          personne: t.destinataire,
          aMoi: mesTaches.contains(t.id),
          detail: t.commentaire,
          deActivite: t,
        ),
    for (final q in quotidiennes)
      LigneTache(
        cle: 'quotidienne:${q.id}',
        titre: q.description,
        echeance: q.echeance?.toLocal(),
        faite: q.faite,
        finieLe: q.termineeLe?.toLocal(),
        priorite: q.priorite,
        contexte: 'Tâche quotidienne',
        activiteId: null,
        personne: q.assigneNom,
        aMoi: q.assigneA == moi,
        detail: q.assigneA == moi && q.imputee ? 'De ${q.creeParNom}' : null,
        quotidienne: q,
      ),
  ];
}

List<LigneTache> filtrerLignes(
  List<LigneTache> lignes, {
  required DateTime maintenant,
  SegmentTaches segment = SegmentTaches.toutes,
  DateTime? jour,
  String activite = cleToutesActivites,
  String personne = cleToutLeMonde,
}) {
  return lignes.where((l) {
    if (activite == cleTachesQuotidiennes && l.activiteId != null) return false;
    if (activite != cleTachesQuotidiennes &&
        activite != cleToutesActivites &&
        l.activiteId != activite) {
      return false;
    }
    if (personne == cleMoi && !l.aMoi) return false;
    if (personne != cleMoi &&
        personne != cleToutLeMonde &&
        l.personne != personne) {
      return false;
    }
    if (jour != null && !l.estLe(jour)) return false;
    return switch (segment) {
      SegmentTaches.toutes => true,
      SegmentTaches.aujourdhui => l.estLe(maintenant),
      SegmentTaches.aVenir =>
        !l.faite &&
            l.echeance != null &&
            _jour(l.echeance!).isAfter(_jour(maintenant)),
    };
  }).toList();
}

/// Les sections de la liste : ce qui presse d'abord. Les plus urgentes passent
/// en tête au sein d'une même date.
List<(String, List<LigneTache>)> sectionsDe(
  List<LigneTache> lignes,
  DateTime maintenant,
) {
  int parEcheance(LigneTache a, LigneTache b) {
    final dates = (a.echeance ?? DateTime(2100)).compareTo(
      b.echeance ?? DateTime(2100),
    );
    return dates != 0 ? dates : b.priorite.index.compareTo(a.priorite.index);
  }

  final enRetard = <LigneTache>[];
  final aujourdhui = <LigneTache>[];
  final plusTard = <LigneTache>[];
  final sansEcheance = <LigneTache>[];
  final terminees = <LigneTache>[];

  for (final l in lignes) {
    if (l.faite) {
      terminees.add(l);
    } else if (l.enRetard(maintenant)) {
      enRetard.add(l);
    } else if (l.echeance == null) {
      sansEcheance.add(l);
    } else if (l.estLe(maintenant)) {
      aujourdhui.add(l);
    } else if (_jour(l.echeance!).isAfter(_jour(maintenant))) {
      plusTard.add(l);
    } else {
      // Échéance passée, mais faite et en attente du visa.
      aujourdhui.add(l);
    }
  }

  terminees.sort(
    (a, b) =>
        (b.finieLe ?? DateTime(2000)).compareTo(a.finieLe ?? DateTime(2000)),
  );

  return [
    ('En retard', enRetard..sort(parEcheance)),
    ("Aujourd'hui", aujourdhui..sort(parEcheance)),
    ('Plus tard', plusTard..sort(parEcheance)),
    ('Sans échéance', sansEcheance..sort(parEcheance)),
    // Bornée : la liste de ce qui reste à faire ne doit pas se noyer, au fil
    // des mois, sous tout ce qui a été fait.
    ('Terminées', terminees.take(20).toList()),
  ].where((s) => s.$2.isNotEmpty).toList();
}
