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
  final parc = await logistique.from('vehicule').select('etat');
  final stocks = await logistique
      .from('soute_type_stock')
      .select('qte_gasoil, qte_super');
  final armes = await logistique.from('arme').count();
  // Une dotation sans date de retour effective est une arme encore sortie.
  final enDotation = await logistique
      .from('dotation_arme')
      .select('id')
      .isFilter('date_retour_effective', null)
      .count();

  var litres = 0;
  for (final ligne in stocks) {
    litres +=
        ((ligne['qte_gasoil'] as int?) ?? 0) + ((ligne['qte_super'] as int?) ?? 0);
  }

  return ApercuLogistique(
    vehicules: parc.length,
    vehiculesDisponibles: parc
        .where((v) => v['etat'] == 'disponible')
        .length,
    litresEnSoute: litres,
    armes: armes,
    // Comptée après un filtre, la valeur arrive dans la réponse plutôt qu'en
    // retour direct.
    armesEnDotation: enDotation.count,
  );
});
