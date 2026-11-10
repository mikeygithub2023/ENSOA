import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase_client.dart';

/// Les chiffres de l'école, tels que la RLS les laisse voir à celui qui
/// regarde. Un commandant de division ne compte que ses apprenants, un armurier ne
/// voit que ce qui le regarde : les compteurs ci-dessous n'ajoutent aucun
/// filtre, ils héritent de celui du serveur.
///
/// Chaque bloc a son propre provider plutôt qu'un seul gros : un module en
/// panne ou interdit laisse l'autre s'afficher.

class ApercuScolarite {
  const ApercuScolarite({
    required this.apprenants,
    required this.promotions,
    required this.classes,
    required this.cours,
  });

  final int apprenants;
  final int promotions;
  final int classes;
  final int cours;

  bool get vide => apprenants == 0 && promotions == 0 && classes == 0;
}

final apercuScolariteProvider = FutureProvider<ApercuScolarite>((ref) async {
  final resultats = await Future.wait([
    scolarite.from('apprenants').count(),
    scolarite.from('promotions').count(),
    scolarite.from('classes').count(),
    scolarite.from('cours').count(),
  ]);
  return ApercuScolarite(
    apprenants: resultats[0],
    promotions: resultats[1],
    classes: resultats[2],
    cours: resultats[3],
  );
});

class ApercuLogistique {
  const ApercuLogistique({
    required this.vehicules,
    required this.vehiculesDisponibles,
    required this.litresEnSoute,
    required this.armes,
    required this.armesEnDotation,
  });

  final int vehicules;
  final int vehiculesDisponibles;
  final int litresEnSoute;
  final int armes;
  final int armesEnDotation;

  bool get vide => vehicules == 0 && litresEnSoute == 0 && armes == 0;
}

final apercuLogistiqueProvider = FutureProvider<ApercuLogistique>((ref) async {
  // Ce qui a été retiré du parc ou de l'inventaire reste en base mais ne compte
  // plus : sans ce filtre, l'accueil annonçait 16/27 véhicules là où le tableau
  // de bord, qui les écarte, en lisait 12/22.
  final parc = await logistique
      .from('vehicule')
      .select('etat')
      .eq('supprime', false);
  final stocks = await logistique
      .from('soute_type_stock')
      .select('qte_gasoil, qte_super');
  final armes = await logistique
      .from('arme')
      .select('id')
      .eq('supprime', false)
      .count();
  // Une dotation sans date de retour effective est une arme encore sortie.
  final enDotation = await logistique
      .from('dotation_arme')
      .select('id')
      .isFilter('date_retour_effective', null)
      .count();

  var litres = 0;
  for (final ligne in stocks) {
    litres +=
        ((ligne['qte_gasoil'] as int?) ?? 0) +
        ((ligne['qte_super'] as int?) ?? 0);
  }

  return ApercuLogistique(
    vehicules: parc.length,
    vehiculesDisponibles: parc.where((v) => v['etat'] == 'disponible').length,
    litresEnSoute: litres,
    armes: armes.count,
    // Comptée après un filtre, la valeur arrive dans la réponse plutôt qu'en
    // retour direct.
    armesEnDotation: enDotation.count,
  );
});

/// Ce que l'Officier Adjoint a sous les yeux : ses activités et l'état de
/// leurs tâches.
///
/// Il relève du soutien technique, et voyait donc jusqu'ici les compteurs de
/// ce module — véhicules disponibles, litres en soute, armes inventoriées.
/// Rien de tout cela ne le concerne : il monte les activités de l'école et
/// valide les tâches que les services déclarent terminées.
class ApercuActivites {
  const ApercuActivites({
    required this.enCours,
    required this.aValider,
    required this.tachesEnCours,
    required this.terminees,
  });

  /// Planifiées ou déjà commencées — ce qui est encore devant lui.
  final int enCours;

  /// Les tâches qu'un service déclare finies et qui attendent son visa.
  /// C'est le seul chiffre sur lequel il doit agir.
  final int aValider;

  final int tachesEnCours;
  final int terminees;

  bool get vide => enCours == 0 && terminees == 0 && tachesEnCours == 0;
}

final apercuActivitesProvider = FutureProvider<ApercuActivites>((ref) async {
  final activites = await logistique.from('activite').select('statut');
  final taches = await logistique.from('tache_activite').select('statut');

  int compter(List<dynamic> lignes, Set<String> statuts) => lignes
      .where((l) => statuts.contains((l as Map)['statut'] as String?))
      .length;

  return ApercuActivites(
    enCours: compter(activites, {'planifiee', 'en_cours'}),
    terminees: compter(activites, {'terminee'}),
    aValider: compter(taches, {'terminee'}),
    tachesEnCours: compter(taches, {'a_faire'}),
  );
});

/// Ce que chaque service du soutien technique a sous les yeux.
///
/// Un seul aperçu servait aux quatre postes : véhicules, litres en soute,
/// armes, dotations. Trois tuiles sur quatre étaient hors sujet pour chacun
/// d'eux, et l'armurier apprenait l'état du parc plutôt que celui de ses
/// munitions. Le chef du service, lui, garde la vue d'ensemble : c'est la
/// sienne.
class ApercuArmurerie {
  const ApercuArmurerie({
    required this.armes,
    required this.enDotation,
    required this.cartouches,
    required this.inspectionsEchues,
  });

  final int armes;
  final int enDotation;
  final int cartouches;
  final int inspectionsEchues;

  bool get vide => armes == 0 && cartouches == 0;
}

final apercuArmurerieProvider = FutureProvider<ApercuArmurerie>((ref) async {
  final armes = await logistique
      .from('arme')
      .select('etat')
      .eq('supprime', false);
  final munitions = await logistique
      .from('stock_munition')
      .select('quantite_disponible')
      .eq('supprime', false);
  final enDotation = await logistique
      .from('dotation_arme')
      .select('id')
      .isFilter('date_retour_effective', null)
      .count();
  // Une inspection échue se lit sur la date : la comparaison est faite par le
  // serveur, qui a l'heure de référence.
  final echues = await logistique
      .from('arme')
      .select('id')
      .eq('supprime', false)
      .lt('prochaine_inspection', DateTime.now().toIso8601String())
      .count();

  var cartouches = 0;
  for (final m in munitions) {
    cartouches += (m['quantite_disponible'] as int?) ?? 0;
  }

  return ApercuArmurerie(
    armes: armes.length,
    enDotation: enDotation.count,
    cartouches: cartouches,
    inspectionsEchues: echues.count,
  );
});

class ApercuGarage {
  const ApercuGarage({
    required this.vehicules,
    required this.disponibles,
    required this.enReparation,
    required this.vidangesAPrevoir,
  });

  final int vehicules;
  final int disponibles;
  final int enReparation;
  final int vidangesAPrevoir;

  bool get vide => vehicules == 0;
}

final apercuGarageProvider = FutureProvider<ApercuGarage>((ref) async {
  final parc = await logistique
      .from('vehicule')
      .select('etat, kilometrage, kilometrage_vidange_prochaine')
      .eq('supprime', false);

  var disponibles = 0;
  var enReparation = 0;
  var vidanges = 0;
  for (final v in parc) {
    switch (v['etat']) {
      case 'disponible':
        disponibles++;
      case 'en_reparation':
        enReparation++;
    }
    final km = (v['kilometrage'] as int?) ?? 0;
    final prochaine = (v['kilometrage_vidange_prochaine'] as int?) ?? 0;
    if (prochaine > 0 && km >= prochaine) vidanges++;
  }

  return ApercuGarage(
    vehicules: parc.length,
    disponibles: disponibles,
    enReparation: enReparation,
    vidangesAPrevoir: vidanges,
  );
});

class ApercuCarburant {
  const ApercuCarburant({
    required this.litres,
    required this.soutes,
    required this.soutesEnAlerte,
    required this.sortiesDuJour,
  });

  final int litres;
  final int soutes;
  final int soutesEnAlerte;
  final int sortiesDuJour;

  bool get vide => litres == 0 && soutes == 0;
}

final apercuCarburantProvider = FutureProvider<ApercuCarburant>((ref) async {
  final stocks = await logistique
      .from('soute_type_stock')
      .select('soute_id, qte_gasoil, qte_super, seuil_critique');

  // La journée commence à minuit, heure de la tablette : c'est celle que
  // l'utilisateur lit sur sa montre.
  final maintenant = DateTime.now();
  final minuit = DateTime(maintenant.year, maintenant.month, maintenant.day);
  final sorties = await logistique
      .from('distribution')
      .select('qte_percue')
      .gte('date', minuit.toIso8601String());

  var litres = 0;
  var enAlerte = 0;
  final soutes = <String>{};
  for (final s in stocks) {
    final quantite =
        ((s['qte_gasoil'] as int?) ?? 0) + ((s['qte_super'] as int?) ?? 0);
    litres += quantite;
    soutes.add(s['soute_id'].toString());
    if (quantite <= ((s['seuil_critique'] as int?) ?? 0)) enAlerte++;
  }

  var sortiesDuJour = 0;
  for (final d in sorties) {
    sortiesDuJour += (d['qte_percue'] as int?) ?? 0;
  }

  return ApercuCarburant(
    litres: litres,
    soutes: soutes.length,
    soutesEnAlerte: enAlerte,
    sortiesDuJour: sortiesDuJour,
  );
});

/// Ce que le Service de santé a sous les yeux.
///
/// Il voyait les compteurs du soutien technique — véhicules, litres en soute,
/// armes. Aucun des quatre ne le concerne : il reçoit des consultants, tient
/// une pharmacie et convoque des visites.
class ApercuSante {
  const ApercuSante({
    required this.consultationsOuvertes,
    required this.urgences,
    required this.medicamentsSousSeuil,
    required this.visitesAVenir,
  });

  /// En attente ou en cours : ce qui n'est pas encore réglé.
  final int consultationsOuvertes;

  final int urgences;
  final int medicamentsSousSeuil;
  final int visitesAVenir;

  bool get vide =>
      consultationsOuvertes == 0 &&
      medicamentsSousSeuil == 0 &&
      visitesAVenir == 0 &&
      urgences == 0;
}

final apercuSanteProvider = FutureProvider<ApercuSante>((ref) async {
  final consultations = await scolarite
      .from('consultations_medicales')
      .select('statut, type');
  final medicaments = await scolarite
      .from('medicaments')
      .select('stock, seuil_alerte');
  // Une visite passée ne demande plus rien : seules celles à venir comptent.
  final maintenant = DateTime.now();
  final minuit = DateTime(maintenant.year, maintenant.month, maintenant.day);
  final visites = await scolarite
      .from('visites_medicales')
      .select('id')
      .gte('date_visite', minuit.toIso8601String())
      .count();

  var ouvertes = 0;
  var urgences = 0;
  for (final c in consultations) {
    if (c['statut'] != 'terminee') ouvertes++;
    if (c['type'] == 'urgence' && c['statut'] != 'terminee') urgences++;
  }

  var sousSeuil = 0;
  for (final m in medicaments) {
    final stock = (m['stock'] as int?) ?? 0;
    final seuil = (m['seuil_alerte'] as int?) ?? 0;
    if (stock <= seuil) sousSeuil++;
  }

  return ApercuSante(
    consultationsOuvertes: ouvertes,
    urgences: urgences,
    medicamentsSousSeuil: sousSeuil,
    visitesAVenir: visites.count,
  );
});

/// Ce que le Poste de police a sous les yeux.
///
/// Des quatre compteurs du soutien technique, seul l'état du parc l'effleurait
/// — et encore, il ne le gère pas : il contrôle ce qui entre et ce qui sort.
class ApercuPolice {
  const ApercuPolice({
    required this.visiteursPresents,
    required this.visiteursDuJour,
    required this.vehiculesSortis,
    required this.mouvementsDuJour,
  });

  /// Entrés et pas encore ressortis : ceux qui sont dans l'enceinte.
  final int visiteursPresents;

  final int visiteursDuJour;

  /// Sortis et pas encore rentrés.
  final int vehiculesSortis;

  final int mouvementsDuJour;

  bool get vide =>
      visiteursDuJour == 0 &&
      mouvementsDuJour == 0 &&
      visiteursPresents == 0 &&
      vehiculesSortis == 0;
}

final apercuPoliceProvider = FutureProvider<ApercuPolice>((ref) async {
  final maintenant = DateTime.now();
  final minuit = DateTime(maintenant.year, maintenant.month, maintenant.day);
  final debut = minuit.toIso8601String();

  final visiteurs = await logistique
      .from('passage_visiteur')
      .select('date_arrivee, date_sortie');
  final vehicules = await logistique
      .from('passage_vehicule')
      .select('date_sortie, date_retour');

  var presents = 0;
  var duJour = 0;
  for (final v in visiteurs) {
    if (v['date_sortie'] == null) presents++;
    if ((v['date_arrivee'] as String?)?.compareTo(debut) != -1) duJour++;
  }

  var sortis = 0;
  var mouvements = 0;
  for (final v in vehicules) {
    if (v['date_retour'] == null) sortis++;
    if ((v['date_sortie'] as String?)?.compareTo(debut) != -1) mouvements++;
  }

  return ApercuPolice(
    visiteursPresents: presents,
    visiteursDuJour: duJour,
    vehiculesSortis: sortis,
    mouvementsDuJour: mouvements,
  );
});
