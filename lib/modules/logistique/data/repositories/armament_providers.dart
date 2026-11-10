import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sig_ensoa/core/supabase_client.dart';
import 'package:sig_ensoa/core/chargement.dart';
import '../models/armement.dart';
import '../../features/armament/import_armes.dart';

/// L'état du registre, tel que la colonne `etat_general` le porte. Tout ce
/// qui n'est pas explicitement défectueux est bon : la colonne a 'bon' pour
/// défaut, et une valeur inattendue ne doit pas faire disparaître une arme
/// de la liste.
EtatArme _etatArmeFromDb(Object? value) =>
    value == 'defectueux' ? EtatArme.defectueux : EtatArme.bon;

String _etatArmeToDb(EtatArme etat) =>
    etat == EtatArme.defectueux ? 'defectueux' : 'bon';

/// La colonne `etat` (énumération `logistique.etat_arme`) n'est plus un état
/// au sens de l'application — elle n'est ni lue ni montrée. Les bons de
/// sortie continuent pourtant de l'écrire, pour qu'une lecture SQL directe
/// du registre reste cohérente avec ce qui est sorti.
const _situationEnDotation = 'en_dotation';
const _situationEnArmurerie = 'en_armurerie';

DateTime? _dateOuNull(Object? v) =>
    v == null ? null : DateTime.parse(v as String);

Arme _armeFromRow(Map<String, dynamic> row) => Arme(
  id: row['id'].toString(),
  numeroSerie: row['numero_serie'] as String,
  type: row['type'] as String,
  modele: row['modele'] as String,
  etat: _etatArmeFromDb(row['etat_general']),
  positionActuelle: row['position_actuelle'] as String?,
  observations: row['observations'] as String?,
  dateAcquisition: _dateOuNull(row['date_acquisition']),
  derniereInspection: _dateOuNull(row['derniere_inspection']),
  prochaineInspection: _dateOuNull(row['prochaine_inspection']),
);

class ArmesNotifier extends Notifier<List<Arme>> {
  @override
  List<Arme> build() {
    Future.microtask(refresh);
    return [];
  }

  Future<void> refresh() async {
    // Les armes supprimées restent au registre — les bons de sortie passés
    // s'y rattachent — mais ne remontent plus dans les listes.
    final rows = await logistique
        .from('arme')
        .select()
        .eq('supprime', false)
        .order('numero_serie');
    state = (rows as List)
        .map((r) => _armeFromRow(r as Map<String, dynamic>))
        .toList();
    ref.read(chargementProvider.notifier).marquerCharge('armes');
  }

  Future<void> add(Arme a) async {
    await logistique.from('arme').insert({
      'numero_serie': a.numeroSerie,
      'type': a.type,
      'modele': a.modele,
      'etat_general': _etatArmeToDb(a.etat),
      'position_actuelle': a.positionActuelle,
      'observations': a.observations,
      'date_acquisition': a.dateAcquisition?.toIso8601String(),
      'prochaine_inspection': a.prochaineInspection?.toIso8601String(),
    });
    await refresh();
  }

  Future<void> update({
    required String id,
    required String numeroSerie,
    required String type,
    required String modele,
    required EtatArme etat,
    String? positionActuelle,
    String? observations,
  }) async {
    await logistique
        .from('arme')
        .update({
          'numero_serie': numeroSerie,
          'type': type,
          'modele': modele,
          'etat_general': _etatArmeToDb(etat),
          'position_actuelle': positionActuelle,
          'observations': observations,
        })
        .eq('id', int.parse(id));
    await refresh();
  }

  /// Écrit la situation interne — pas l'état du registre. Appelée par les
  /// bons de sortie et de retour, et par eux seuls.
  Future<void> _marquerSituation(String id, String situation) async {
    await logistique
        .from('arme')
        .update({'etat': situation})
        .eq('id', int.parse(id));
    await refresh();
  }

  /// Suppression douce : l'arme quitte le registre actif mais reste en
  /// base, car les bons de sortie passés s'y rattachent — et un registre
  /// d'armurerie se relit des années après.
  Future<void> supprimer(String id) => supprimerPlusieurs([id]);

  /// Retire plusieurs armes en une écriture.
  ///
  /// `.select('id')` n'est pas décoratif : sans lui, PostgREST ne rend
  /// aucune erreur quand la sécurité par ligne refuse l'écriture, et
  /// l'écran annoncerait des suppressions qui n'ont pas eu lieu. Le compte
  /// rendu est celui des lignes que la base a réellement touchées.
  Future<int> supprimerPlusieurs(List<String> armeIds) async {
    if (armeIds.isEmpty) return 0;
    final touchees = await logistique
        .from('arme')
        .update({'supprime': true})
        .inFilter('id', armeIds.map(int.parse).toList())
        .select('id');
    await refresh();
    return (touchees as List).length;
  }

  Future<void> enregistrerInspection(
    String id, {
    required DateTime prochaineInspection,
  }) async {
    await logistique
        .from('arme')
        .update({
          'derniere_inspection': DateTime.now().toIso8601String(),
          'prochaine_inspection': prochaineInspection.toIso8601String(),
        })
        .eq('id', int.parse(id));
    await refresh();
  }

  /// Les armes retirées du registre.
  ///
  /// Elles ne paraissent nulle part — `refresh()` les écarte —, mais elles
  /// existent toujours et gardent leur numéro de série : la contrainte
  /// d'unicité le leur réserve. L'import doit donc les connaître, sinon il
  /// annonce « à créer » un numéro que la base refusera.
  Future<List<Arme>> retireesDuRegistre() async {
    final rows = await logistique.from('arme').select().eq('supprime', true);
    return (rows as List)
        .map((r) => _armeFromRow(r as Map<String, dynamic>))
        .toList();
  }

  /// Verse en une fois un registre existant, lu depuis un fichier.
  ///
  /// Une seule insertion pour tout le lot, et non une par arme : cent
  /// allers-retours sur une liaison d'école, c'est une minute d'attente et
  /// autant d'occasions de couper au milieu.
  ///
  /// [retablies] associe l'identifiant d'une arme retirée du registre aux
  /// données du fichier qui la concernent : elle y revient avec ses bons,
  /// au lieu d'être recréée à côté — ce que la contrainte d'unicité
  /// refuserait de toute façon.
  Future<void> importer(
    List<ArmeAImporter> armes, {
    Map<String, ArmeAImporter> retablies = const {},
  }) async {
    if (armes.isEmpty && retablies.isEmpty) return;

    // Le référentiel des désignations suit : sans cela, une arme importée
    // porterait une désignation absente de la liste déroulante du
    // formulaire, et la modifier obligerait à en choisir une autre.
    await ref.read(typesArmeProvider.notifier).completer([
      for (final a in [...armes, ...retablies.values]) a.designation,
    ]);

    // Les rétablissements d'abord : ils libèrent les numéros de série que
    // l'insertion suivante pourrait croire disponibles.
    for (final entree in retablies.entries) {
      final a = entree.value;
      await logistique
          .from('arme')
          .update({
            'supprime': false,
            'numero_serie': a.numeroSerie,
            'type': a.designation,
            'modele': a.marquage,
            'etat_general': _etatArmeToDb(a.etat),
            'position_actuelle': a.positionActuelle,
            'observations': a.observations,
          })
          .eq('id', int.parse(entree.key))
          .select('id');
    }

    if (armes.isEmpty) {
      await refresh();
      return;
    }

    await logistique.from('arme').insert([
      for (final a in armes)
        {
          'numero_serie': a.numeroSerie,
          'type': a.designation,
          'modele': a.marquage,
          'etat_general': _etatArmeToDb(a.etat),
          'position_actuelle': a.positionActuelle,
          'observations': a.observations,
        },
    ]);
    await refresh();
  }
}

final armesProvider = NotifierProvider<ArmesNotifier, List<Arme>>(
  ArmesNotifier.new,
);

final armesInspectionEnRetardProvider = Provider<List<Arme>>(
  (ref) => ref.watch(armesProvider).where((a) => a.inspectionEnRetard).toList(),
);

DotationArme _dotationFromRow(Map<String, dynamic> row) => DotationArme(
  id: row['id'].toString(),
  armeId: row['arme_id'].toString(),
  beneficiaireId: row['beneficiaire_matricule'] as String,
  beneficiaireNom: (row['beneficiaire_nom'] as String?) ?? '',
  dateRemise: DateTime.parse(row['date_remise'] as String),
  dateRetourPrevue: row['date_retour_prevue'] != null
      ? DateTime.parse(row['date_retour_prevue'] as String)
      : null,
  dateRetourEffective: row['date_retour_effective'] != null
      ? DateTime.parse(row['date_retour_effective'] as String)
      : null,
  remisePar: row['remise_par'] as String,
  motif: row['motif'] as String?,
);

class DotationsNotifier extends Notifier<List<DotationArme>> {
  @override
  List<DotationArme> build() {
    Future.microtask(refresh);
    return [];
  }

  Future<void> refresh() async {
    final rows = await logistique
        .from('dotation_arme')
        .select()
        .order('date_remise', ascending: false);
    state = (rows as List)
        .map((r) => _dotationFromRow(r as Map<String, dynamic>))
        .toList();
    ref.read(chargementProvider.notifier).marquerCharge('dotations_armes');
  }

  Future<void> remettre(DotationArme d) async {
    await logistique.from('dotation_arme').insert({
      'arme_id': int.parse(d.armeId),
      'beneficiaire_matricule': d.beneficiaireId,
      'beneficiaire_nom': d.beneficiaireNom,
      'date_retour_prevue': d.dateRetourPrevue?.toIso8601String(),
      'remise_par': d.remisePar,
      'motif': d.motif,
    });
    await ref
        .read(armesProvider.notifier)
        ._marquerSituation(d.armeId, _situationEnDotation);
    await refresh();
  }

  Future<void> enregistrerRetour(String dotationId, String armeId) async {
    await logistique
        .from('dotation_arme')
        .update({'date_retour_effective': DateTime.now().toIso8601String()})
        .eq('id', int.parse(dotationId));
    await ref
        .read(armesProvider.notifier)
        ._marquerSituation(armeId, _situationEnArmurerie);
    await refresh();
  }
}

final dotationsProvider =
    NotifierProvider<DotationsNotifier, List<DotationArme>>(
      DotationsNotifier.new,
    );

final dotationsEnRetardProvider = Provider<List<DotationArme>>(
  (ref) => ref.watch(dotationsProvider).where((d) => d.retourEnRetard).toList(),
);

StockMunition _munitionFromRow(Map<String, dynamic> row) => StockMunition(
  id: row['id'].toString(),
  calibre: row['calibre'] as String,
  quantiteDisponible: row['quantite_disponible'] as int,
  seuilCritique: row['seuil_critique'] as int,
  souteArmementId: (row['soute_armement'] as String?) ?? '',
);

class MunitionsNotifier extends Notifier<List<StockMunition>> {
  @override
  List<StockMunition> build() {
    Future.microtask(refresh);
    return [];
  }

  Future<void> refresh() async {
    final rows = await logistique
        .from('stock_munition')
        .select()
        .eq('supprime', false)
        .order('calibre');
    state = (rows as List)
        .map((r) => _munitionFromRow(r as Map<String, dynamic>))
        .toList();
    ref.read(chargementProvider.notifier).marquerCharge('munitions');
  }

  Future<void> creer({
    required String calibre,
    required int quantiteInitiale,
    required int seuilCritique,
  }) async {
    await logistique.from('stock_munition').insert({
      'calibre': calibre,
      'quantite_disponible': quantiteInitiale,
      'seuil_critique': seuilCritique,
    });
    await refresh();
  }

  Future<void> supprimer(String id) async {
    await logistique
        .from('stock_munition')
        .update({'supprime': true})
        .eq('id', int.parse(id));
    await refresh();
  }
}

final munitionsProvider =
    NotifierProvider<MunitionsNotifier, List<StockMunition>>(
      MunitionsNotifier.new,
    );

TypeArme _typeArmeFromRow(Map<String, dynamic> row) =>
    TypeArme(id: row['id'].toString(), libelle: row['libelle'] as String);

class TypesArmeNotifier extends Notifier<List<TypeArme>> {
  @override
  List<TypeArme> build() {
    Future.microtask(refresh);
    return [];
  }

  Future<void> refresh() async {
    final rows = await logistique
        .from('type_arme')
        .select()
        .eq('supprime', false)
        .order('libelle');
    state = (rows as List)
        .map((r) => _typeArmeFromRow(r as Map<String, dynamic>))
        .toList();
    ref.read(chargementProvider.notifier).marquerCharge('types_arme');
  }

  Future<void> creer(String libelle) async {
    await logistique.from('type_arme').insert({'libelle': libelle});
    await refresh();
  }

  /// Ajoute au référentiel les désignations qui en manquent, et elles
  /// seules. La comparaison ignore la casse et les espaces de bord : un
  /// fichier qui écrit « fusil d'assaut » ne doit pas créer un doublon de
  /// « Fusil d'assaut ».
  Future<void> completer(Iterable<String> designations) async {
    await refresh();
    final connues = {for (final t in state) t.libelle.trim().toLowerCase()};
    final aCreer = <String, String>{};
    for (final d in designations) {
      final net = d.trim();
      if (net.isEmpty) continue;
      final cle = net.toLowerCase();
      if (connues.contains(cle) || aCreer.containsKey(cle)) continue;
      aCreer[cle] = net;
    }
    if (aCreer.isEmpty) return;
    await logistique.from('type_arme').insert([
      for (final libelle in aCreer.values) {'libelle': libelle},
    ]);
    await refresh();
  }
}

final typesArmeProvider = NotifierProvider<TypesArmeNotifier, List<TypeArme>>(
  TypesArmeNotifier.new,
);

EquipementProtection _equipementFromRow(Map<String, dynamic> row) =>
    EquipementProtection(
      id: row['id'].toString(),
      libelle: row['libelle'] as String,
      quantiteDisponible: row['quantite_disponible'] as int,
      seuilCritique: row['seuil_critique'] as int,
    );

class EquipementsNotifier extends Notifier<List<EquipementProtection>> {
  @override
  List<EquipementProtection> build() {
    Future.microtask(refresh);
    return [];
  }

  Future<void> refresh() async {
    final rows = await logistique
        .from('equipement_protection')
        .select()
        .eq('supprime', false)
        .order('libelle');
    state = (rows as List)
        .map((r) => _equipementFromRow(r as Map<String, dynamic>))
        .toList();
    ref.read(chargementProvider.notifier).marquerCharge('equipements');
  }

  Future<void> creer({
    required String libelle,
    required int quantiteInitiale,
    required int seuilCritique,
  }) async {
    await logistique.from('equipement_protection').insert({
      'libelle': libelle,
      'quantite_disponible': quantiteInitiale,
      'seuil_critique': seuilCritique,
    });
    await refresh();
  }

  Future<void> supprimer(String id) async {
    await logistique
        .from('equipement_protection')
        .update({'supprime': true})
        .eq('id', int.parse(id));
    await refresh();
  }
}

final equipementsProvider =
    NotifierProvider<EquipementsNotifier, List<EquipementProtection>>(
      EquipementsNotifier.new,
    );

final equipementsEnAlerteProvider = Provider<List<EquipementProtection>>(
  (ref) => ref.watch(equipementsProvider).where((e) => e.seuilAtteint).toList(),
);

final munitionsEnAlerteProvider = Provider<List<StockMunition>>(
  (ref) => ref.watch(munitionsProvider).where((m) => m.seuilAtteint).toList(),
);

// --- Bons de munitions et d'équipements ------------------------------------

MouvementArticle _mouvementFromRow(Map<String, dynamic> row) {
  final munition = row['munition_id'];
  return MouvementArticle(
    id: row['id'].toString(),
    famille: munition != null
        ? FamilleArticle.munition
        : FamilleArticle.equipement,
    articleId: (munition ?? row['equipement_id']).toString(),
    sens: row['sens'] == 'entree' ? SensMouvement.entree : SensMouvement.sortie,
    quantite: row['quantite'] as int,
    beneficiaireMatricule: row['beneficiaire_matricule'] as String?,
    beneficiaireNom: row['beneficiaire_nom'] as String?,
    motif: row['motif'] as String?,
    date: DateTime.parse(row['date'] as String),
  );
}

/// Le journal des entrées et sorties de munitions et d'équipements.
///
/// C'est lui qui meut le stock, et non l'inverse : un déclencheur applique
/// chaque mouvement à la quantité disponible, dans la même transaction.
/// Une écriture, donc — jamais un stock modifié sans bon correspondant, ni
/// un bon sans effet.
class MouvementsArticleNotifier extends Notifier<List<MouvementArticle>> {
  @override
  List<MouvementArticle> build() {
    Future.microtask(refresh);
    return [];
  }

  Future<void> refresh() async {
    final rows = await logistique
        .from('mouvement_article')
        .select()
        .order('date', ascending: false);
    state = (rows as List)
        .map((r) => _mouvementFromRow(r as Map<String, dynamic>))
        .toList();
    ref.read(chargementProvider.notifier).marquerCharge('mouvements_articles');
  }

  Future<void> enregistrer({
    required FamilleArticle famille,
    required String articleId,
    required SensMouvement sens,
    required int quantite,
    String? beneficiaireMatricule,
    String? beneficiaireNom,
    String? motif,
    String? auteurId,
  }) async {
    await logistique.from('mouvement_article').insert({
      if (famille == FamilleArticle.munition)
        'munition_id': int.parse(articleId)
      else
        'equipement_id': int.parse(articleId),
      'sens': sens == SensMouvement.entree ? 'entree' : 'sortie',
      'quantite': quantite,
      'beneficiaire_matricule': beneficiaireMatricule,
      'beneficiaire_nom': beneficiaireNom,
      'motif': motif,
      'auteur_id': auteurId,
    });
    await refresh();
    // Le stock a bougé en base sous l'effet du déclencheur ; les listes
    // doivent le relire, sinon l'écran continue d'afficher l'ancien chiffre.
    if (famille == FamilleArticle.munition) {
      await ref.read(munitionsProvider.notifier).refresh();
    } else {
      await ref.read(equipementsProvider.notifier).refresh();
    }
  }
}

final mouvementsArticleProvider =
    NotifierProvider<MouvementsArticleNotifier, List<MouvementArticle>>(
      MouvementsArticleNotifier.new,
    );

/// Les mouvements d'une famille, les plus récents d'abord.
final mouvementsParFamilleProvider =
    Provider.family<List<MouvementArticle>, FamilleArticle>(
      (ref, famille) => ref
          .watch(mouvementsArticleProvider)
          .where((m) => m.famille == famille)
          .toList(),
    );
