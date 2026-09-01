import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sig_ensoa/core/supabase_client.dart';
import 'package:sig_ensoa/core/chargement.dart';
import '../models/armement.dart';

EtatArme _etatArmeFromDb(String value) {
  switch (value) {
    case 'en_dotation':
      return EtatArme.enDotation;
    case 'en_maintenance':
      return EtatArme.enMaintenance;
    case 'reforme':
      return EtatArme.reforme;
    default:
      return EtatArme.enArmurerie;
  }
}

String _etatArmeToDb(EtatArme etat) {
  switch (etat) {
    case EtatArme.enDotation:
      return 'en_dotation';
    case EtatArme.enArmurerie:
      return 'en_armurerie';
    case EtatArme.enMaintenance:
      return 'en_maintenance';
    case EtatArme.reforme:
      return 'reforme';
  }
}

Arme _armeFromRow(Map<String, dynamic> row) => Arme(
  id: row['id'].toString(),
  numeroSerie: row['numero_serie'] as String,
  type: row['type'] as String,
  modele: row['modele'] as String,
  etat: _etatArmeFromDb(row['etat'] as String),
  dateAcquisition: DateTime.parse(row['date_acquisition'] as String),
  derniereInspection: row['derniere_inspection'] != null
      ? DateTime.parse(row['derniere_inspection'] as String)
      : null,
  prochaineInspection: DateTime.parse(row['prochaine_inspection'] as String),
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
      'etat': _etatArmeToDb(a.etat),
      'date_acquisition': a.dateAcquisition.toIso8601String(),
      'prochaine_inspection': a.prochaineInspection.toIso8601String(),
    });
    await refresh();
  }

  Future<void> update({
    required String id,
    required String numeroSerie,
    required String type,
    required String modele,
  }) async {
    await logistique
        .from('arme')
        .update({'numero_serie': numeroSerie, 'type': type, 'modele': modele})
        .eq('id', int.parse(id));
    await refresh();
  }

  Future<void> updateEtat(String id, EtatArme etat) async {
    await logistique
        .from('arme')
        .update({'etat': _etatArmeToDb(etat)})
        .eq('id', int.parse(id));
    await refresh();
  }

  /// Suppression douce : l'arme quitte le registre actif mais reste en
  /// base, car les bons de sortie passés s'y rattachent — et un registre
  /// d'armurerie se relit des années après.
  Future<void> supprimer(String id) async {
    await logistique
        .from('arme')
        .update({'supprime': true})
        .eq('id', int.parse(id));
    await refresh();
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
        .updateEtat(d.armeId, EtatArme.enDotation);
    await refresh();
  }

  Future<void> enregistrerRetour(String dotationId, String armeId) async {
    await logistique
        .from('dotation_arme')
        .update({'date_retour_effective': DateTime.now().toIso8601String()})
        .eq('id', int.parse(dotationId));
    await ref
        .read(armesProvider.notifier)
        .updateEtat(armeId, EtatArme.enArmurerie);
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

  Future<void> ajusterStock(String id, int delta) async {
    final actuel = state.firstWhere(
      (m) => m.id == id,
      orElse: () => state.first,
    );
    await logistique
        .from('stock_munition')
        .update({
          'quantite_disponible': (actuel.quantiteDisponible + delta).clamp(
            0,
            1 << 30,
          ),
        })
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

  Future<void> ajusterStock(String id, int delta) async {
    final actuel = state.firstWhere(
      (e) => e.id == id,
      orElse: () => state.first,
    );
    await logistique
        .from('equipement_protection')
        .update({
          'quantite_disponible': (actuel.quantiteDisponible + delta).clamp(
            0,
            1 << 30,
          ),
        })
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
