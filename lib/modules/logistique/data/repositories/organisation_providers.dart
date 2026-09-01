import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sig_ensoa/core/chargement.dart';
import 'package:sig_ensoa/core/supabase_client.dart';

import '../models/organisation.dart';
import '../models/personnel.dart';

/// Le personnel militaire, les services et les cellules — le référentiel de
/// l'organisation.
///
/// Ces trois listes vivaient en dur dans le code : un service, quatre
/// cellules et un militaire de démonstration, les mêmes pour tout le monde et
/// impossibles à corriger sans recompiler. Elles viennent désormais de la
/// base, comme le reste.
///
/// Le personnel n'est pas la liste des comptes : un bénéficiaire de carburant
/// n'a pas forcément de compte dans l'application, et un compte n'est pas
/// forcément un militaire de l'école.

// --- Personnel ---------------------------------------------------------------

Personnel _personnelDepuisLigne(Map<String, dynamic> row) => Personnel(
  id: row['id'].toString(),
  nom: row['nom'] as String,
  prenom: (row['prenom'] as String?) ?? '',
  grade: row['grade'] as String?,
  matricule: row['matricule'] as String,
  contact: row['contact'] as String?,
  mecano: row['mecano'] as String?,
  statutActuel: (row['statut_actuel'] as String?) ?? 'Actif',
);

class PersonnelNotifier extends Notifier<List<Personnel>> {
  @override
  List<Personnel> build() {
    Future.microtask(refresh);
    return const [];
  }

  Future<void> refresh() async {
    final lignes = await logistique
        .from('personnel')
        .select()
        .order('nom', ascending: true);
    state = lignes.map(_personnelDepuisLigne).toList();
    ref.read(chargementProvider.notifier).marquerCharge('personnel');
  }

  Future<void> creer({
    required String nom,
    required String prenom,
    required String matricule,
    String? grade,
    String? contact,
    String? mecano,
    String statutActuel = 'Actif',
  }) async {
    await logistique.from('personnel').insert({
      'nom': nom,
      'prenom': prenom,
      'matricule': matricule,
      'grade': grade,
      'contact': contact,
      'mecano': mecano,
      'statut_actuel': statutActuel,
    });
    await refresh();
  }

  Future<void> modifier({
    required String id,
    required String nom,
    required String prenom,
    required String matricule,
    String? grade,
    String? contact,
    String? mecano,
    required String statutActuel,
  }) async {
    await logistique
        .from('personnel')
        .update({
          'nom': nom,
          'prenom': prenom,
          'matricule': matricule,
          'grade': grade,
          'contact': contact,
          'mecano': mecano,
          'statut_actuel': statutActuel,
        })
        .eq('id', int.parse(id));
    await refresh();
  }

  /// La suppression échouera si une distribution le désigne — et c'est bien :
  /// une distribution nomme celui qui a perçu, on ne réécrit pas l'histoire.
  /// Pour un militaire qui a quitté l'école, changer son statut suffit.
  Future<void> supprimer(String id) async {
    await logistique.from('personnel').delete().eq('id', int.parse(id));
    await refresh();
  }
}

final personnelProvider = NotifierProvider<PersonnelNotifier, List<Personnel>>(
  PersonnelNotifier.new,
);

// --- Services ----------------------------------------------------------------

class ServicesNotifier extends Notifier<List<Service>> {
  @override
  List<Service> build() {
    Future.microtask(refresh);
    return const [];
  }

  Future<void> refresh() async {
    final lignes = await socle
        .from('service')
        .select()
        .order('libelle', ascending: true);
    state = lignes
        .map(
          (r) => Service(id: r['id'].toString(), libelle: r['libelle'] as String),
        )
        .toList();
    ref.read(chargementProvider.notifier).marquerCharge('services');
  }

  Future<void> creer(String libelle) async {
    await socle.from('service').insert({'libelle': libelle});
    await refresh();
  }

  Future<void> renommer(String id, String libelle) async {
    await socle
        .from('service')
        .update({'libelle': libelle})
        .eq('id', int.parse(id));
    await refresh();
  }

  Future<void> supprimer(String id) async {
    await socle.from('service').delete().eq('id', int.parse(id));
    await refresh();
    await ref.read(cellulesProvider.notifier).refresh();
  }
}

final servicesProvider = NotifierProvider<ServicesNotifier, List<Service>>(
  ServicesNotifier.new,
);

// --- Cellules ----------------------------------------------------------------

class CellulesNotifier extends Notifier<List<Cellule>> {
  @override
  List<Cellule> build() {
    Future.microtask(refresh);
    return const [];
  }

  Future<void> refresh() async {
    final lignes = await socle
        .from('cellule')
        .select()
        .order('libelle', ascending: true);
    state = lignes
        .map(
          (r) => Cellule(
            id: r['id'].toString(),
            libelle: r['libelle'] as String,
            serviceId: r['service_id']?.toString() ?? '',
          ),
        )
        .toList();
    ref.read(chargementProvider.notifier).marquerCharge('cellules');
  }

  Future<void> creer({
    required String libelle,
    required String serviceId,
  }) async {
    await socle.from('cellule').insert({
      'libelle': libelle,
      'service_id': int.parse(serviceId),
    });
    await refresh();
  }

  Future<void> modifier({
    required String id,
    required String libelle,
    required String serviceId,
  }) async {
    await socle
        .from('cellule')
        .update({'libelle': libelle, 'service_id': int.parse(serviceId)})
        .eq('id', int.parse(id));
    await refresh();
  }

  Future<void> supprimer(String id) async {
    await socle.from('cellule').delete().eq('id', int.parse(id));
    await refresh();
  }
}

final cellulesProvider = NotifierProvider<CellulesNotifier, List<Cellule>>(
  CellulesNotifier.new,
);

/// Retrouve un militaire dans une liste déjà chargée.
Personnel? trouverPersonnel(List<Personnel> personnel, String? id) {
  if (id == null) return null;
  for (final p in personnel) {
    if (p.id == id) return p;
  }
  return null;
}
