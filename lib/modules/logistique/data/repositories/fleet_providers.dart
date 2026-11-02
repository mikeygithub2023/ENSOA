import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sig_ensoa/core/supabase_client.dart';
import 'package:sig_ensoa/core/chargement.dart';
import 'package:sig_ensoa/core/erreurs.dart';
import '../models/maintenance.dart';
import '../models/mouvement_vehicule.dart';
import '../models/vehicule.dart';
import '../../features/fleet/import_vehicules.dart';

EtatVehicule _etatFromDb(String value) {
  switch (value) {
    case 'disponible':
      return EtatVehicule.disponible;
    case 'en_mission':
      return EtatVehicule.enMission;
    case 'en_reparation':
      return EtatVehicule.enReparation;
    case 'hors_service':
      return EtatVehicule.horsService;
    default:
      return EtatVehicule.disponible;
  }
}

String _etatToDb(EtatVehicule etat) {
  switch (etat) {
    case EtatVehicule.disponible:
      return 'disponible';
    case EtatVehicule.enMission:
      return 'en_mission';
    case EtatVehicule.enReparation:
      return 'en_reparation';
    case EtatVehicule.horsService:
      return 'hors_service';
  }
}

Vehicule _vehiculeFromRow(Map<String, dynamic> row) {
  final typeVhl = row['type_vhl'] as Map<String, dynamic>?;
  final modeleVhl = typeVhl?['modele_vhl'] as Map<String, dynamic>?;
  final marqueVhl = modeleVhl?['marque_vhl'] as Map<String, dynamic>?;
  return Vehicule(
    id: row['id'].toString(),
    chassis: row['chassis'] as String,
    immatriculation: row['immatriculation'] as String,
    kilometrage: row['kilometrage'] as int,
    etat: _etatFromDb(row['etat'] as String),
    positionActuelle: row['position_actuelle'] as String?,
    nbrePlaces: (row['nbre_places'] as int?) ?? 5,
    observations: row['observations'] as String?,
    typeVehiculeId: row['type_vhl_id']?.toString() ?? '',
    kilometrageVidangeProchaine: row['kilometrage_vidange_prochaine'] as int,
    kilometrageVidangePrecedente: row['kilometrage_vidange_precedente'] as int?,
    kilometrageCorrigeLe: row['kilometrage_corrige_le'] != null
        ? DateTime.parse(row['kilometrage_corrige_le'] as String)
        : null,
    marque: (marqueVhl?['marque'] as String?) ?? '—',
    modele: (modeleVhl?['modele'] as String?) ?? '—',
    typeVehicule: (typeVhl?['type'] as String?) ?? '—',
  );
}

const _selectVehiculeAvecReferentiel =
    '*, type_vhl(type, modele_vhl(modele, marque_vhl(marque)))';

class VehiculesNotifier extends Notifier<List<Vehicule>> {
  @override
  List<Vehicule> build() {
    Future.microtask(refresh);
    return [];
  }

  Future<void> refresh() async {
    final rows = await logistique
        .from('vehicule')
        .select(_selectVehiculeAvecReferentiel)
        .eq('supprime', false);
    state = (rows as List)
        .map((r) => _vehiculeFromRow(r as Map<String, dynamic>))
        .toList();
    ref.read(chargementProvider.notifier).marquerCharge('vehicules');
  }

  Future<void> add({
    required String chassis,
    required String immatriculation,
    required int kilometrage,
    required int nbrePlaces,
    String? positionActuelle,
    required String typeVehiculeId,
    required int kilometrageVidangeProchaine,
  }) async {
    await logistique.from('vehicule').insert({
      'chassis': chassis,
      'immatriculation': immatriculation,
      'kilometrage': kilometrage,
      'etat': 'disponible',
      'position_actuelle': positionActuelle,
      'nbre_places': nbrePlaces,
      'type_vhl_id': int.parse(typeVehiculeId),
      'kilometrage_vidange_prochaine': kilometrageVidangeProchaine,
    });
    await refresh();
  }

  Future<void> update({
    required String id,
    required String chassis,
    required String immatriculation,
    required int nbrePlaces,
    String? positionActuelle,
    required String typeVehiculeId,
    required int kilometrageVidangeProchaine,

    /// Le kilométrage corrigé, quand la fiche use de son unique correction ;
    /// la base refuse une seconde correction.
    int? kilometrageCorrige,
  }) async {
    await logistique
        .from('vehicule')
        .update({
          'chassis': chassis,
          'immatriculation': immatriculation,
          'position_actuelle': positionActuelle,
          'nbre_places': nbrePlaces,
          'type_vhl_id': int.parse(typeVehiculeId),
          'kilometrage_vidange_prochaine': kilometrageVidangeProchaine,
          if (kilometrageCorrige != null) ...{
            'kilometrage': kilometrageCorrige,
            'kilometrage_corrige_le': DateTime.now().toIso8601String(),
          },
        })
        .eq('id', int.parse(id));
    await refresh();
  }

  /// Les véhicules retirés du parc.
  ///
  /// Ils ne paraissent nulle part — `refresh()` les écarte —, mais ils
  /// existent toujours et gardent leur immatriculation : l'index unique la
  /// leur réserve. L'import doit donc les connaître, sinon il annonce
  /// « à créer » une plaque que la base refusera.
  Future<List<Vehicule>> retiresDuParc() async {
    final rows = await logistique
        .from('vehicule')
        .select(_selectVehiculeAvecReferentiel)
        .eq('supprime', true);
    return (rows as List)
        .map((r) => _vehiculeFromRow(r as Map<String, dynamic>))
        .toList();
  }

  /// Verse en une fois un parc existant, lu depuis un fichier.
  ///
  /// Une seule insertion pour tout le lot, et non une par véhicule : cent
  /// allers-retours sur une liaison d'école, c'est une minute d'attente et
  /// autant d'occasions de couper au milieu. Ici, ou tout entre, ou rien
  /// n'entre — et l'on sait lequel des deux.
  ///
  /// Le référentiel marque → modèle → type est résolu une fois par triplet
  /// distinct, puis mémorisé : un parc de cinquante véhicules ne compte
  /// souvent que cinq modèles.
  /// [retablis] associe l'identifiant d'un véhicule retiré du parc aux
  /// données du fichier qui le concernent : il revient au parc avec son
  /// historique, au lieu d'être recréé à côté — ce que l'index unique
  /// refuserait de toute façon.
  Future<void> importer(
    List<VehiculeAImporter> vehicules, {
    Map<String, VehiculeAImporter> retablis = const {},
  }) async {
    if (vehicules.isEmpty && retablis.isEmpty) return;

    final typesResolus = <String, String>{};
    final reference = ref.read(typesVehiculeRefProvider.notifier);
    for (final v in [...vehicules, ...retablis.values]) {
      final cle = '${v.marque}|${v.modele}|${v.type}'.toLowerCase();
      if (typesResolus.containsKey(cle)) continue;
      try {
        typesResolus[cle] = await reference.creerTypeComplet(
          marque: v.marque,
          modele: v.modele,
          type: v.type,
        );
      } catch (e) {
        // Sans ce rattachement, l'échec remontait nu : l'utilisateur voyait
        // un refus de la base sans savoir lequel de ses quarante véhicules
        // l'avait provoqué, ni que c'était le catalogue et non le parc qui
        // avait résisté.
        throw Exception(
          'Le catalogue n\'a pas pu être complété pour '
          '${v.marque} ${v.modele} — ${v.type} : ${messageErreur(e)}',
        );
      }
    }

    // Le catalogue répond avoir créé ces types ; on vérifie qu'ils y sont
    // réellement avant d'y accrocher quarante véhicules. Un identifiant qui
    // ne correspond à rien ferait refuser le lot entier par une clé
    // étrangère — un message qui ne désigne ni la ligne ni la cause.
    final attendus = typesResolus.values.map(int.parse).toSet();
    final presents = await logistique
        .from('type_vhl')
        .select('id')
        .inFilter('id', attendus.toList());
    final trouves = {
      for (final r in (presents as List).cast<Map<String, dynamic>>())
        r['id'] as int,
    };
    if (trouves.length != attendus.length) {
      final manquants = typesResolus.entries
          .where((e) => !trouves.contains(int.parse(e.value)))
          .map((e) => e.key.split('|').join(' '))
          .join(', ');
      throw Exception(
        'Le catalogue des types de véhicule n\'a pas enregistré : '
        '$manquants. Vérifiez vos droits sur le catalogue, puis réessayez.',
      );
    }

    int typeDe(VehiculeAImporter v) => int.parse(
      typesResolus['${v.marque}|${v.modele}|${v.type}'.toLowerCase()]!,
    );

    // Les rétablissements d'abord : ils libèrent les immatriculations que
    // l'insertion suivante pourrait croire disponibles.
    for (final entree in retablis.entries) {
      final v = entree.value;
      await logistique
          .from('vehicule')
          .update({
            'supprime': false,
            'chassis': v.chassis,
            'immatriculation': v.immatriculation,
            'kilometrage': v.kilometrage,
            'etat': _etatToDb(v.etat),
            'position_actuelle': v.positionActuelle,
            'nbre_places': v.nbrePlaces,
            'observations': v.observations,
            'type_vhl_id': typeDe(v),
            'kilometrage_vidange_prochaine': v.kilometrageVidangeProchaine,
          })
          .eq('id', int.parse(entree.key))
          .select('id');
    }

    if (vehicules.isEmpty) {
      await refresh();
      return;
    }

    await logistique.from('vehicule').insert([
      for (final v in vehicules)
        {
          'chassis': v.chassis,
          'immatriculation': v.immatriculation,
          'kilometrage': v.kilometrage,
          'etat': _etatToDb(v.etat),
          'position_actuelle': v.positionActuelle,
          'nbre_places': v.nbrePlaces,
          'observations': v.observations,
          'type_vhl_id': typeDe(v),
          'kilometrage_vidange_prochaine': v.kilometrageVidangeProchaine,
        },
    ]);
    await refresh();
  }

  Future<void> updateEtat(String vehiculeId, EtatVehicule etat) async {
    await logistique
        .from('vehicule')
        .update({'etat': _etatToDb(etat)})
        .eq('id', int.parse(vehiculeId));
    await refresh();
  }

  /// Suppression douce : la ligne reste en base (l'historique — réparations,
  /// vidanges, mouvements — y reste rattaché), seule sa visibilité dans les
  /// listes actives disparaît.
  Future<void> supprimer(String vehiculeId) => supprimerPlusieurs([vehiculeId]);

  /// Retire plusieurs véhicules d'un coup.
  ///
  /// Une seule écriture pour tout le lot : vingt suppressions, c'est vingt
  /// allers-retours, et autant de chances qu'un échoue au milieu en laissant
  /// la liste à moitié vidée sans qu'on sache où elle s'est arrêtée.
  ///
  /// Le `select('id')` final n'est pas décoratif. Sans lui, un refus de la
  /// sécurité par ligne reviendrait sans erreur : l'écran annoncerait vingt
  /// véhicules retirés, et le rafraîchissement suivant les ferait tous
  /// réapparaître sans que personne comprenne. Le nombre rendu est celui que
  /// la base a réellement retiré.
  Future<int> supprimerPlusieurs(List<String> vehiculeIds) async {
    if (vehiculeIds.isEmpty) return 0;
    final touches = await logistique
        .from('vehicule')
        .update({'supprime': true})
        .inFilter('id', vehiculeIds.map(int.parse).toList())
        .select('id');
    await refresh();
    return (touches as List).length;
  }

  /// Le franchissement du seuil de vidange prévient CST + Garage — mais
  /// c'est le déclencheur `notifier_seuil_vidange` qui s'en charge, et non
  /// plus cette méthode.
  ///
  /// Deux raisons. La base voit le franchissement même quand le kilométrage
  /// est corrigé ailleurs qu'ici. Et elle écrit une notification par
  /// personne, là où l'application n'en écrivait qu'une pour tout un rôle —
  /// que le premier lecteur éteignait pour ses collègues.
  Future<void> updateKilometrage(String vehiculeId, int kilometrage) async {
    await logistique
        .from('vehicule')
        .update({'kilometrage': kilometrage})
        .eq('id', int.parse(vehiculeId));
    await refresh();
  }

  Future<void> updateApresVidange(
    String vehiculeId,
    int nouveauSeuil,
    int kilometrageActuel,
  ) async {
    await logistique
        .from('vehicule')
        .update({
          'kilometrage_vidange_prochaine': nouveauSeuil,
          'kilometrage_vidange_precedente': kilometrageActuel,
        })
        .eq('id', int.parse(vehiculeId));
    await refresh();
  }
}

final vehiculesProvider = NotifierProvider<VehiculesNotifier, List<Vehicule>>(
  VehiculesNotifier.new,
);

/// Référentiel Type de véhicule (avec marque/modèle résolus), pour les menus
/// déroulants — évite de dupliquer la logique de jointure côté client.
class TypeVehiculeRef {
  final String id;
  final String label;
  const TypeVehiculeRef({required this.id, required this.label});
}

class TypesVehiculeRefNotifier extends Notifier<List<TypeVehiculeRef>> {
  @override
  List<TypeVehiculeRef> build() {
    Future.microtask(_charger);
    return [];
  }

  Future<void> _charger() async {
    final rows = await logistique
        .from('type_vhl')
        .select('id, type, modele_vhl(modele, marque_vhl(marque))');
    state = (rows as List).map((r) {
      final row = r as Map<String, dynamic>;
      final modeleVhl = row['modele_vhl'] as Map<String, dynamic>?;
      final marqueVhl = modeleVhl?['marque_vhl'] as Map<String, dynamic>?;
      final marque = marqueVhl?['marque'] as String? ?? '';
      final modele = modeleVhl?['modele'] as String? ?? '';
      return TypeVehiculeRef(
        id: row['id'].toString(),
        label: '$marque $modele — ${row['type']}',
      );
    }).toList();
  }

  /// Crée (ou réutilise s'ils existent déjà) la chaîne marque → modèle →
  /// type, et renvoie l'id du type — prêt à être sélectionné dans le
  /// formulaire véhicule sans quitter le dialogue de création.
  Future<String> creerTypeComplet({
    required String marque,
    required String modele,
    required String type,
  }) async {
    final marqueRow = await logistique
        .from('marque_vhl')
        .select('id')
        .ilike('marque', marque)
        .maybeSingle();
    final marqueId = marqueRow != null
        ? marqueRow['id']
        : (await logistique
              .from('marque_vhl')
              .insert({'marque': marque})
              .select('id')
              .single())['id'];

    final modeleRow = await logistique
        .from('modele_vhl')
        .select('id')
        .eq('marque_id', marqueId)
        .ilike('modele', modele)
        .maybeSingle();
    final modeleId = modeleRow != null
        ? modeleRow['id']
        : (await logistique
              .from('modele_vhl')
              .insert({'modele': modele, 'marque_id': marqueId})
              .select('id')
              .single())['id'];

    final typeRow = await logistique
        .from('type_vhl')
        .select('id')
        .eq('modele_id', modeleId)
        .ilike('type', type)
        .maybeSingle();
    final typeId = typeRow != null
        ? typeRow['id']
        : (await logistique
              .from('type_vhl')
              .insert({'type': type, 'modele_id': modeleId})
              .select('id')
              .single())['id'];

    await _charger();
    return typeId.toString();
  }
}

final typesVehiculeRefProvider =
    NotifierProvider<TypesVehiculeRefNotifier, List<TypeVehiculeRef>>(
      TypesVehiculeRefNotifier.new,
    );

Reparation _reparationFromRow(Map<String, dynamic> row) => Reparation(
  id: row['id'].toString(),
  dateEntree: DateTime.parse(row['date_entree'] as String),
  dateSortie: row['date_sortie'] != null
      ? DateTime.parse(row['date_sortie'] as String)
      : null,
  pannesConstatees: row['pannes_constatees'] as String,
  solutionsApportees: row['solutions_apportees'] as String?,
  chefEquipe: row['chef_equipe'] as String?,
  aideMecano: row['aide_mecano'] as String?,
  lieu: row['lieu'] as String?,
  vehiculeId: row['vehicule_id'].toString(),
  utilisateurId: row['utilisateur_id'] as String,
);

class ReparationsNotifier extends Notifier<List<Reparation>> {
  @override
  List<Reparation> build() {
    Future.microtask(refresh);
    return [];
  }

  Future<void> refresh() async {
    final rows = await logistique
        .from('reparation')
        .select()
        .order('date_entree', ascending: false);
    state = (rows as List)
        .map((r) => _reparationFromRow(r as Map<String, dynamic>))
        .toList();
    ref.read(chargementProvider.notifier).marquerCharge('reparations');
  }

  Future<void> add(Reparation r) async {
    await logistique.from('reparation').insert({
      'pannes_constatees': r.pannesConstatees,
      'chef_equipe': r.chefEquipe,
      'aide_mecano': r.aideMecano,
      'lieu': r.lieu,
      'vehicule_id': int.parse(r.vehiculeId),
      'utilisateur_id': r.utilisateurId,
    });
    await refresh();
  }

  Future<void> cloturer(String id, {String? solutionsApportees}) async {
    await logistique
        .from('reparation')
        .update({
          'date_sortie': DateTime.now().toIso8601String(),
          'solutions_apportees': solutionsApportees,
        })
        .eq('id', int.parse(id));
    await refresh();
  }
}

final reparationsProvider =
    NotifierProvider<ReparationsNotifier, List<Reparation>>(
      ReparationsNotifier.new,
    );

Vidange _vidangeFromRow(Map<String, dynamic> row) => Vidange(
  id: row['id'].toString(),
  date: DateTime.parse(row['date'] as String),
  filtreVidange: row['filtre_vidange'] as String?,
  typeHuile: row['type_huile'] as String,
  qteHuile: row['qte_huile'] as int,
  ingredient: row['ingredient'] as String?,
  vehiculeId: row['vehicule_id'].toString(),
  utilisateurId: row['utilisateur_id'] as String,
);

class VidangesNotifier extends Notifier<List<Vidange>> {
  @override
  List<Vidange> build() {
    Future.microtask(refresh);
    return [];
  }

  Future<void> refresh() async {
    final rows = await logistique
        .from('vidange')
        .select()
        .order('date', ascending: false);
    state = (rows as List)
        .map((r) => _vidangeFromRow(r as Map<String, dynamic>))
        .toList();
    ref.read(chargementProvider.notifier).marquerCharge('vidanges');
  }

  Future<void> add(Vidange v) async {
    await logistique.from('vidange').insert({
      'filtre_vidange': v.filtreVidange,
      'type_huile': v.typeHuile,
      'qte_huile': v.qteHuile,
      'ingredient': v.ingredient,
      'vehicule_id': int.parse(v.vehiculeId),
      'utilisateur_id': v.utilisateurId,
    });
    await refresh();
  }
}

final vidangesProvider = NotifierProvider<VidangesNotifier, List<Vidange>>(
  VidangesNotifier.new,
);

EtatMouvement _etatMouvementFromDb(String value) {
  switch (value) {
    case 'en_cours':
      return EtatMouvement.enCours;
    case 'termine':
      return EtatMouvement.termine;
    case 'annule':
      return EtatMouvement.annule;
    default:
      return EtatMouvement.enCours;
  }
}

MouvementVehicule _mouvementFromRow(Map<String, dynamic> row) =>
    MouvementVehicule(
      id: row['id'].toString(),
      objet: row['objet'] as String,
      dateDepart: DateTime.parse(row['date_depart'] as String),
      dateFin: row['date_fin'] != null
          ? DateTime.parse(row['date_fin'] as String)
          : null,
      etat: _etatMouvementFromDb(row['etat'] as String),
      vehiculeId: row['vehicule_id'].toString(),
      utilisateurId: row['utilisateur_id'] as String,
      kmDepart: row['km_depart'] as int,
      kmArrivee: row['km_arrivee'] as int?,
      destination: row['destination'] as String,
      gradeChefBord: (row['grade_chef_bord'] as String?) ?? '',
      nomChefBord: row['nom_chef_bord'] as String,
      contactChefBord: (row['contact_chef_bord'] as String?) ?? '',
      gradeChefDeBord: (row['grade_chef_de_bord'] as String?) ?? '',
      nomChefDeBord: (row['nom_chef_de_bord'] as String?) ?? '',
    );

class MouvementsVehiculeNotifier extends Notifier<List<MouvementVehicule>> {
  @override
  List<MouvementVehicule> build() {
    Future.microtask(refresh);
    return [];
  }

  Future<void> refresh() async {
    final rows = await logistique
        .from('mouvement')
        .select()
        .order('date_depart', ascending: false);
    state = (rows as List)
        .map((r) => _mouvementFromRow(r as Map<String, dynamic>))
        .toList();
    ref.read(chargementProvider.notifier).marquerCharge('mouvements');
  }

  Future<void> add(MouvementVehicule m) async {
    await logistique.from('mouvement').insert({
      'objet': m.objet,
      'vehicule_id': int.parse(m.vehiculeId),
      'utilisateur_id': m.utilisateurId,
      'km_depart': m.kmDepart,
      'destination': m.destination,
      'grade_chef_bord': m.gradeChefBord,
      'nom_chef_bord': m.nomChefBord,
      'contact_chef_bord': m.contactChefBord,
      'grade_chef_de_bord': m.gradeChefDeBord,
      'nom_chef_de_bord': m.nomChefDeBord,
    });
    await refresh();
  }

  Future<void> cloturer(String id, {required int kmArrivee}) async {
    await logistique
        .from('mouvement')
        .update({
          'date_fin': DateTime.now().toIso8601String(),
          'etat': 'termine',
          'km_arrivee': kmArrivee,
        })
        .eq('id', int.parse(id));
    await refresh();
  }

  /// Corrige un ordre de mission : son objet, sa destination et son chef de
  /// bord. On ne touche ni au véhicule, ni aux dates, ni au kilométrage —
  /// ceux-là suivent le départ et la clôture, non une correction de saisie.
  Future<void> modifier(MouvementVehicule m) async {
    await logistique
        .from('mouvement')
        .update({
          'objet': m.objet,
          'destination': m.destination,
          'grade_chef_bord': m.gradeChefBord,
          'nom_chef_bord': m.nomChefBord,
          'contact_chef_bord': m.contactChefBord,
          'grade_chef_de_bord': m.gradeChefDeBord,
          'nom_chef_de_bord': m.nomChefDeBord,
        })
        .eq('id', int.parse(m.id));
    await refresh();
  }

  /// Supprime un ordre de mission. Rendre le véhicule à sa disponibilité, s'il
  /// y a lieu, revient à l'appelant : lui seul sait s'il faut le libérer.
  Future<void> supprimer(String id) async {
    await logistique.from('mouvement').delete().eq('id', int.parse(id));
    await refresh();
  }
}

final mouvementsVehiculeProvider =
    NotifierProvider<MouvementsVehiculeNotifier, List<MouvementVehicule>>(
      MouvementsVehiculeNotifier.new,
    );

/// Véhicules dont le kilométrage a atteint (ou dépasse) le seuil de vidange.
final vehiculesEnAlerteVidangeProvider = Provider<List<Vehicule>>((ref) {
  final vehicules = ref.watch(vehiculesProvider);
  return vehicules.where((v) => v.vidangeRequise).toList();
});
