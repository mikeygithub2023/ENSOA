import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sig_ensoa/core/supabase_client.dart';
import 'package:sig_ensoa/core/chargement.dart';
import '../models/carburant.dart';

Soute _souteFromRow(Map<String, dynamic> row) =>
    Soute(id: row['id'].toString(), libelle: row['libelle'] as String);

class SoutesNotifier extends Notifier<List<Soute>> {
  @override
  List<Soute> build() {
    Future.microtask(refresh);
    return [];
  }

  Future<void> refresh() async {
    // Les soutes supprimées restent en base — leurs dépotages et
    // distributions y sont rattachés — mais ne remontent plus dans les
    // listes.
    final rows = await logistique
        .from('soute')
        .select()
        .eq('supprime', false)
        .order('libelle');
    state = (rows as List)
        .map((r) => _souteFromRow(r as Map<String, dynamic>))
        .toList();
    ref.read(chargementProvider.notifier).marquerCharge('soutes');
  }

  Future<void> creer(String libelle) async {
    await logistique.from('soute').insert({'libelle': libelle});
    await refresh();
  }

  /// Renommer une soute ne touche ni à son stock ni à son historique.
  Future<void> modifier(String souteId, String libelle) async {
    await logistique
        .from('soute')
        .update({'libelle': libelle})
        .eq('id', int.parse(souteId));
    await refresh();
  }

  /// Suppression douce, comme pour les véhicules : la ligne est marquée
  /// supprimée, jamais effacée. Les dépotages et distributions passés se
  /// rattachent à cette soute — les perdre trouerait les pièces comptables
  /// du dépôt.
  Future<void> supprimer(String souteId) async {
    await logistique
        .from('soute')
        .update({'supprime': true})
        .eq('id', int.parse(souteId));
    await refresh();
  }
}

final soutesProvider = NotifierProvider<SoutesNotifier, List<Soute>>(
  SoutesNotifier.new,
);

TypeStock _typeStockFromRow(Map<String, dynamic> row) =>
    TypeStock(id: row['id'].toString(), libelle: row['libelle'] as String);

class TypesStockNotifier extends Notifier<List<TypeStock>> {
  @override
  List<TypeStock> build() {
    Future.microtask(refresh);
    return [];
  }

  Future<void> refresh() async {
    final rows = await logistique.from('type_stock').select().order('libelle');
    state = (rows as List)
        .map((r) => _typeStockFromRow(r as Map<String, dynamic>))
        .toList();
  }
}

final typesStockProvider =
    NotifierProvider<TypesStockNotifier, List<TypeStock>>(
      TypesStockNotifier.new,
    );

Repartition _repartitionFromRow(Map<String, dynamic> row) =>
    Repartition(id: row['id'].toString(), libelle: row['libelle'] as String);

class RepartitionsNotifier extends Notifier<List<Repartition>> {
  @override
  List<Repartition> build() {
    Future.microtask(refresh);
    return [];
  }

  Future<void> refresh() async {
    final rows = await logistique.from('repartition').select().order('libelle');
    state = (rows as List)
        .map((r) => _repartitionFromRow(r as Map<String, dynamic>))
        .toList();
    ref.read(chargementProvider.notifier).marquerCharge('repartitions');
  }

  /// Corrige le libellé d'une répartition — une faute de frappe, un
  /// changement d'appellation. Les stocks qui s'y rattachent la suivent :
  /// c'est la même ligne, seul son nom change.
  Future<void> renommer(String id, String libelle) async {
    await logistique
        .from('repartition')
        .update({'libelle': libelle})
        .eq('id', int.parse(id));
    await refresh();
    // Les écrans qui affichent le libellé à côté d'un stock le lisent par
    // jointure : sans ce rafraîchissement, ils garderaient l'ancien nom.
    await ref.read(souteStocksProvider.notifier).refresh();
  }

  /// Supprime une répartition. La base refuse tant qu'une soute lui garde du
  /// stock — et c'est bien : effacer la répartition laisserait du carburant
  /// sans destinataire.
  Future<void> supprimer(String id) async {
    await logistique.from('repartition').delete().eq('id', int.parse(id));
    await refresh();
    await ref.read(souteStocksProvider.notifier).refresh();
  }

  Future<Repartition> creer(String libelle) async {
    final row = await logistique
        .from('repartition')
        .insert({'libelle': libelle})
        .select()
        .single();
    await refresh();
    return _repartitionFromRow(row);
  }
}

final repartitionsProvider =
    NotifierProvider<RepartitionsNotifier, List<Repartition>>(
      RepartitionsNotifier.new,
    );

/// Une ligne de jonction Soute × Répartition × TypeStock.
SouteStock _souteStockFromRow(Map<String, dynamic> row) {
  final repartition = row['repartition'] as Map<String, dynamic>?;
  return SouteStock(
    id: row['id'].toString(),
    souteId: row['soute_id'].toString(),
    typeStockId: row['type_stock_id']?.toString() ?? '',
    repartitionId: row['repartition_id']?.toString() ?? '',
    repartitionLibelle: (repartition?['libelle'] as String?) ?? '—',
    qteGasoil: row['qte_gasoil'] as int,
    qteSuper: row['qte_super'] as int,
    seuilNominal: row['seuil_nominal'] as int,
    seuilCritique: row['seuil_critique'] as int,
  );
}

const _selectSouteStockAvecRepartition = '*, repartition(libelle)';

class SouteStocksNotifier extends Notifier<List<SouteStock>> {
  @override
  List<SouteStock> build() {
    Future.microtask(refresh);
    return [];
  }

  Future<void> refresh() async {
    final rows = await logistique
        .from('soute_type_stock')
        .select(_selectSouteStockAvecRepartition);
    state = (rows as List)
        .map((r) => _souteStockFromRow(r as Map<String, dynamic>))
        .toList();
    ref.read(chargementProvider.notifier).marquerCharge('soute_stocks');
  }

  /// Trouve la ligne (soute, répartition) existante, ou la crée si le
  /// dépotage introduit cette répartition dans une soute pour la 1ère fois.
  /// Le nom de la répartition où tout dépotage arrive.
  ///
  /// Elle naît avec la soute, par un déclencheur de la base : une soute
  /// sans elle serait une soute où l'on ne peut rien déposer.
  static const activitesOrdinaires = 'Activités Ordinaires';

  /// La ligne de stock où déposer le carburant reçu par cette soute.
  ///
  /// Un camion-citerne livre DANS LA SOUTE, pas dans une affectation : on
  /// ne demande donc plus au soutier de désigner une répartition au moment
  /// de la réception. La ventilation vers BA1, CA1 ou CA2 viendra ensuite,
  /// par un dépotage interne prélevé sur celle-ci.
  Future<String?> ligneDAccueil(
    String souteId,
    List<Repartition> repartitions,
  ) async {
    final accueil = repartitions.where((r) => r.libelle == activitesOrdinaires);
    if (accueil.isEmpty) return null;

    String? chercher() {
      final ligne = state.where(
        (s) => s.souteId == souteId && s.repartitionId == accueil.first.id,
      );
      return ligne.isEmpty ? null : ligne.first.id;
    }

    // Une soute créée à l'instant a sa ligne en base, pas encore ici : on
    // rafraîchit avant de conclure à son absence, plutôt que d'accuser la
    // base d'un défaut qui n'est qu'un cache en retard.
    return chercher() ??
        await () async {
          await refresh();
          return chercher();
        }();
  }

  Future<String> souteStockIdPour({
    required String souteId,
    required String repartitionId,
    required String typeStockId,
  }) async {
    final existant = state.where(
      (s) => s.souteId == souteId && s.repartitionId == repartitionId,
    );
    if (existant.isNotEmpty) return existant.first.id;
    final row = await logistique
        .from('soute_type_stock')
        .insert({
          'soute_id': int.parse(souteId),
          'repartition_id': int.parse(repartitionId),
          'type_stock_id': int.parse(typeStockId),
          'qte_gasoil': 0,
          'qte_super': 0,
          'seuil_nominal': 0,
          'seuil_critique': 0,
        })
        .select()
        .single();
    await refresh();
    return row['id'].toString();
  }

  Future<void> ajusterQuantite(
    String souteStockId,
    String typeCarburant,
    int delta,
  ) async {
    var trouve = state.where((s) => s.id == souteStockId);
    if (trouve.isEmpty) {
      // Le cache local peut ne pas encore refléter une ligne tout juste créée
      // (ex. souteStockIdPour() venant de l'insérer) — on rafraîchit avant d'échouer.
      await refresh();
      trouve = state.where((s) => s.id == souteStockId);
    }
    if (trouve.isEmpty) {
      throw Exception(
        'Ligne de stock (soute × répartition) introuvable. Réessayez.',
      );
    }
    final actuel = trouve.first;
    final estGasoil = typeCarburant.toLowerCase().contains('gasoil');
    await logistique
        .from('soute_type_stock')
        .update({
          if (estGasoil)
            'qte_gasoil': (actuel.qteGasoil + delta).clamp(0, 1 << 30),
          if (!estGasoil)
            'qte_super': (actuel.qteSuper + delta).clamp(0, 1 << 30),
        })
        .eq('id', int.parse(souteStockId));
    await refresh();
  }
}

final souteStocksProvider =
    NotifierProvider<SouteStocksNotifier, List<SouteStock>>(
      SouteStocksNotifier.new,
    );

/// Vue jointe SOUTE + une de ses répartitions, pour l'affichage.
class SouteVue {
  final Soute soute;
  final SouteStock stock;
  const SouteVue({required this.soute, required this.stock});
}

final soutesAvecStockProvider = Provider<List<SouteVue>>((ref) {
  final soutes = ref.watch(soutesProvider);
  final stocks = ref.watch(souteStocksProvider);
  return [
    for (final soute in soutes)
      for (final stock in stocks.where((s) => s.souteId == soute.id))
        SouteVue(soute: soute, stock: stock),
  ];
});

/// Regroupe les répartitions par soute, avec le total (somme des répartitions).
class SouteAvecRepartitions {
  final Soute soute;
  final List<SouteStock> repartitions;
  const SouteAvecRepartitions({
    required this.soute,
    required this.repartitions,
  });

  int get quantiteTotale =>
      repartitions.fold(0, (s, r) => s + r.quantiteTotale);
  int get seuilCritiqueTotal =>
      repartitions.fold(0, (s, r) => s + r.seuilCritique);
  int get seuilNominalTotal =>
      repartitions.fold(0, (s, r) => s + r.seuilNominal);
}

final soutesRegroupeesProvider = Provider<List<SouteAvecRepartitions>>((ref) {
  final soutes = ref.watch(soutesProvider);
  final stocks = ref.watch(souteStocksProvider);
  return [
    for (final soute in soutes)
      SouteAvecRepartitions(
        soute: soute,
        repartitions: stocks.where((s) => s.souteId == soute.id).toList(),
      ),
  ];
});

final soutesEnAlerteProvider = Provider<List<SouteVue>>(
  (ref) => ref
      .watch(soutesAvecStockProvider)
      .where((v) => v.stock.seuilAtteint)
      .toList(),
);

/// Regroupe les lignes de stock par RÉPARTITION plutôt que par soute — pour
/// la page "Répartitions" : voir dans quelles soutes une répartition a du
/// carburant, et en quelle quantité.
class RepartitionAvecSoutes {
  final Repartition repartition;
  final List<SouteVue>
  lignes; // une entrée par soute où cette répartition a du stock
  const RepartitionAvecSoutes({
    required this.repartition,
    required this.lignes,
  });

  int get quantiteTotale =>
      lignes.fold(0, (s, l) => s + l.stock.quantiteTotale);
}

final repartitionsAvecSoutesProvider = Provider<List<RepartitionAvecSoutes>>((
  ref,
) {
  final repartitions = ref.watch(repartitionsProvider);
  final vues = ref.watch(soutesAvecStockProvider);
  return [
    for (final r in repartitions)
      RepartitionAvecSoutes(
        repartition: r,
        lignes: vues.where((v) => v.stock.repartitionId == r.id).toList(),
      ),
  ];
});

/// Résout soute + répartition d'un SOUTE_STOCK, pour affichage dans les listes.
({String souteLibelle, String repartitionLibelle}) _resoudreSouteStock(
  List<SouteVue> vues,
  String souteStockId,
) {
  final vue = vues.where((v) => v.stock.id == souteStockId);
  if (vue.isEmpty) return (souteLibelle: '—', repartitionLibelle: '—');
  return (
    souteLibelle: vue.first.soute.libelle,
    repartitionLibelle: vue.first.stock.repartitionLibelle,
  );
}

class DepotageVue {
  final Depotage depotage;
  final String souteLibelle;
  final String repartitionLibelle;
  const DepotageVue({
    required this.depotage,
    required this.souteLibelle,
    required this.repartitionLibelle,
  });
}

final depotagesAvecLibellesProvider = Provider<List<DepotageVue>>((ref) {
  final depotages = ref.watch(depotagesProvider);
  final vues = ref.watch(soutesAvecStockProvider);
  return [
    for (final d in depotages)
      DepotageVue(
        depotage: d,
        souteLibelle: _resoudreSouteStock(vues, d.souteStockId).souteLibelle,
        repartitionLibelle: _resoudreSouteStock(
          vues,
          d.souteStockId,
        ).repartitionLibelle,
      ),
  ];
});

class DistributionVue {
  final Distribution distribution;
  final String souteLibelle;
  final String repartitionLibelle;
  const DistributionVue({
    required this.distribution,
    required this.souteLibelle,
    required this.repartitionLibelle,
  });
}

final distributionsAvecLibellesProvider = Provider<List<DistributionVue>>((
  ref,
) {
  final distributions = ref.watch(distributionsProvider);
  final vues = ref.watch(soutesAvecStockProvider);
  return [
    for (final d in distributions)
      DistributionVue(
        distribution: d,
        souteLibelle: _resoudreSouteStock(vues, d.souteStockId).souteLibelle,
        repartitionLibelle: _resoudreSouteStock(
          vues,
          d.souteStockId,
        ).repartitionLibelle,
      ),
  ];
});

Depotage _depotageFromRow(Map<String, dynamic> row) => Depotage(
  id: row['id'].toString(),
  date: DateTime.parse(row['date'] as String),
  quantiteRecue: row['qte_carburant_recue'] as int,
  typeCarburant: row['type_carburant'] as String,
  utilisateurId: row['utilisateur_id'] as String,
  souteStockId: row['soute_stock_id'].toString(),
);

class DepotagesNotifier extends Notifier<List<Depotage>> {
  @override
  List<Depotage> build() {
    Future.microtask(refresh);
    return [];
  }

  Future<void> refresh() async {
    final rows = await logistique
        .from('depotage')
        .select()
        .order('date', ascending: false);
    state = (rows as List)
        .map((r) => _depotageFromRow(r as Map<String, dynamic>))
        .toList();
    ref.read(chargementProvider.notifier).marquerCharge('depotages');
  }

  Future<void> add(Depotage d) async {
    await logistique.from('depotage').insert({
      'qte_carburant_recue': d.quantiteRecue,
      'type_carburant': d.typeCarburant,
      'utilisateur_id': d.utilisateurId,
      'soute_stock_id': int.parse(d.souteStockId),
    });
    await ref
        .read(souteStocksProvider.notifier)
        .ajusterQuantite(d.souteStockId, d.typeCarburant, d.quantiteRecue);
    await refresh();
  }

  /// Corrige un dépotage déjà enregistré — une quantité mal saisie, un
  /// carburant confondu, une soute erronée.
  ///
  /// Le stock suit la correction : on retire d'abord ce que l'ancien dépotage
  /// avait ajouté, puis on ajoute le nouveau. En deux temps plutôt qu'en
  /// calculant un écart, parce que la soute, la répartition ou le type de
  /// carburant peuvent avoir changé en même temps que la quantité — l'écart
  /// n'irait alors pas au bon endroit.
  Future<void> modifier(Depotage ancien, Depotage nouveau) async {
    await logistique
        .from('depotage')
        .update({
          'qte_carburant_recue': nouveau.quantiteRecue,
          'type_carburant': nouveau.typeCarburant,
          'soute_stock_id': int.parse(nouveau.souteStockId),
        })
        .eq('id', int.parse(ancien.id));

    final stocks = ref.read(souteStocksProvider.notifier);
    await stocks.ajusterQuantite(
      ancien.souteStockId,
      ancien.typeCarburant,
      -ancien.quantiteRecue,
    );
    await stocks.ajusterQuantite(
      nouveau.souteStockId,
      nouveau.typeCarburant,
      nouveau.quantiteRecue,
    );
    await refresh();
  }

  /// Annule un dépotage : la ligne disparaît du journal et le carburant
  /// qu'elle avait fait entrer ressort du stock.
  ///
  /// Rien n'empêche le stock de devenir négatif si le carburant a déjà été
  /// distribué. C'est voulu : un stock négatif se voit et se corrige, tandis
  /// qu'un refus silencieux laisserait le journal mentir.
  Future<void> supprimer(Depotage d) async {
    await logistique.from('depotage').delete().eq('id', int.parse(d.id));
    await ref
        .read(souteStocksProvider.notifier)
        .ajusterQuantite(d.souteStockId, d.typeCarburant, -d.quantiteRecue);
    await refresh();
  }
}

final depotagesProvider = NotifierProvider<DepotagesNotifier, List<Depotage>>(
  DepotagesNotifier.new,
);

Distribution _distributionFromRow(Map<String, dynamic> row) => Distribution(
  id: row['id'].toString(),
  souteStockId: row['soute_stock_id'].toString(),
  personnelId: row['personnel_id']?.toString(),
  utilisateurId: row['utilisateur_id'] as String,
  quantitePercue: row['qte_percue'] as int,
  date: DateTime.parse(row['date'] as String),
  typeCarburant: row['type_carburant'] as String,
  contact: row['contact'] as String?,
  gradeDestinataire: row['grade_destinataire'] as String?,
  destinataire: row['destinataire'] as String,
  vehicule: row['vehicule'] as String?,
  vhlImmatriculation: row['vhl_immatriculation'] as String?,
  kilometrage: row['kilometrage'] as int?,
  motif: row['motif'] as String?,
);

class DistributionsNotifier extends Notifier<List<Distribution>> {
  @override
  List<Distribution> build() {
    Future.microtask(refresh);
    return [];
  }

  Future<void> refresh() async {
    final rows = await logistique
        .from('distribution')
        .select()
        .order('date', ascending: false);
    state = (rows as List)
        .map((r) => _distributionFromRow(r as Map<String, dynamic>))
        .toList();
    ref.read(chargementProvider.notifier).marquerCharge('distributions');
  }

  Future<void> add(Distribution d) async {
    await logistique.from('distribution').insert({
      'soute_stock_id': int.parse(d.souteStockId),
      'utilisateur_id': d.utilisateurId,
      'qte_percue': d.quantitePercue,
      'type_carburant': d.typeCarburant,
      'contact': d.contact,
      'grade_destinataire': d.gradeDestinataire,
      'destinataire': d.destinataire,
      // Le bénéficiaire choisi dans le référentiel, quand il y figure. Le
      // nom reste écrit dans la ligne : une distribution nomme celui qui a
      // perçu, même si sa fiche est modifiée ou supprimée plus tard.
      'personnel_id': d.personnelId == null ? null : int.parse(d.personnelId!),
      'vehicule': d.vehicule,
      'vhl_immatriculation': d.vhlImmatriculation,
      'kilometrage': d.kilometrage,
      'motif': d.motif,
    });
    await ref
        .read(souteStocksProvider.notifier)
        .ajusterQuantite(d.souteStockId, d.typeCarburant, -d.quantitePercue);
    await refresh();
  }
}

final distributionsProvider =
    NotifierProvider<DistributionsNotifier, List<Distribution>>(
      DistributionsNotifier.new,
    );

/// Entrée du journal carburant — dérivée de DEPOTAGE + DISTRIBUTION
/// (il n'existe pas de table "mouvement de carburant" dédiée dans l'analyse ;
/// la journalisation qui/quand/combien est portée par ces deux tables).
class JournalCarburantEntry {
  final DateTime date;
  final String description;
  final int quantite;
  final bool entree;
  final String auteurId;

  const JournalCarburantEntry({
    required this.date,
    required this.description,
    required this.quantite,
    required this.entree,
    required this.auteurId,
  });
}

final journalCarburantProvider = Provider<List<JournalCarburantEntry>>((ref) {
  final depotages = ref.watch(depotagesProvider);
  final distributions = ref.watch(distributionsProvider);
  final entries = [
    for (final d in depotages)
      JournalCarburantEntry(
        date: d.date,
        description: 'Dépotage — ${d.typeCarburant}',
        quantite: d.quantiteRecue,
        entree: true,
        auteurId: d.utilisateurId,
      ),
    for (final d in distributions)
      JournalCarburantEntry(
        date: d.date,
        description:
            'Distribution — ${d.destinataire}${d.motif != null ? ' (${d.motif})' : ''}',
        quantite: d.quantitePercue,
        entree: false,
        auteurId: d.utilisateurId,
      ),
  ];
  entries.sort((a, b) => b.date.compareTo(a.date));
  return entries;
});
