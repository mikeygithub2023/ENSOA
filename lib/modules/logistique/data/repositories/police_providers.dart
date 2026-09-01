import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sig_ensoa/core/supabase_client.dart';
import 'package:sig_ensoa/core/chargement.dart';
import '../models/police.dart';
import 'fleet_providers.dart';

CouleurBadge _couleurBadgeFromDb(String value) {
  switch (value) {
    case 'jaune':
      return CouleurBadge.jaune;
    case 'vert':
      return CouleurBadge.vert;
    case 'bleu':
      return CouleurBadge.bleu;
    case 'blanc':
      return CouleurBadge.blanc;
    default:
      return CouleurBadge.rouge;
  }
}

String _couleurBadgeToDb(CouleurBadge c) => c.name;

PassageVisiteur _passageVisiteurFromRow(Map<String, dynamic> row) =>
    PassageVisiteur(
      id: row['id'].toString(),
      contactVisiteur: row['contact_visiteur'] as String,
      nomVisiteur: row['nom_visiteur'] as String,
      photoBase64: row['photo_base64'] as String?,
      couleurBadge: _couleurBadgeFromDb(row['couleur_badge'] as String),
      contactRecu: row['contact_recu'] as String,
      nomRecu: row['nom_recu'] as String,
      dateArrivee: DateTime.parse(row['date_arrivee'] as String),
      dateSortie: row['date_sortie'] != null
          ? DateTime.parse(row['date_sortie'] as String)
          : null,
      enregistrePar: row['enregistre_par'] as String,
      vehiculeImmatriculation: row['vehicule_immatriculation'] as String?,
      vehiculeDescription: row['vehicule_description'] as String?,
      nombreAccompagnants: (row['nombre_accompagnants'] as int?) ?? 0,
      accompagnants: row['accompagnants'] as String?,
    );

class PassagesVisiteursNotifier extends Notifier<List<PassageVisiteur>> {
  @override
  List<PassageVisiteur> build() {
    Future.microtask(refresh);
    return [];
  }

  Future<void> refresh() async {
    final rows = await logistique
        .from('passage_visiteur')
        .select()
        .order('date_arrivee', ascending: false);
    state = (rows as List)
        .map((r) => _passageVisiteurFromRow(r as Map<String, dynamic>))
        .toList();
    ref.read(chargementProvider.notifier).marquerCharge('passages_visiteurs');
  }

  /// Cherche le dernier passage enregistré pour ce [contact], côté visiteur ou
  /// côté personne visitée, pour pré-remplir le nom correspondant.
  Future<String?> rechercherNomParContact(
    String contact, {
    required bool visiteur,
  }) async {
    final colonneContact = visiteur ? 'contact_visiteur' : 'contact_recu';
    final colonneNom = visiteur ? 'nom_visiteur' : 'nom_recu';
    final row = await logistique
        .from('passage_visiteur')
        .select(colonneNom)
        .eq(colonneContact, contact)
        .order('date_arrivee', ascending: false)
        .limit(1)
        .maybeSingle();
    return row == null ? null : row[colonneNom] as String?;
  }

  Future<void> enregistrerArrivee(PassageVisiteur p) async {
    await logistique.from('passage_visiteur').insert({
      'contact_visiteur': p.contactVisiteur,
      'nom_visiteur': p.nomVisiteur,
      'photo_base64': p.photoBase64,
      'couleur_badge': _couleurBadgeToDb(p.couleurBadge),
      'contact_recu': p.contactRecu,
      'nom_recu': p.nomRecu,
      'enregistre_par': p.enregistrePar,
      'vehicule_immatriculation': p.vehiculeImmatriculation,
      'vehicule_description': p.vehiculeDescription,
      'nombre_accompagnants': p.nombreAccompagnants,
      'accompagnants': p.accompagnants,
    });
    await refresh();
  }

  Future<void> enregistrerSortie(String id) async {
    await logistique
        .from('passage_visiteur')
        .update({'date_sortie': DateTime.now().toIso8601String()})
        .eq('id', int.parse(id));
    await refresh();
  }
}

final passagesVisiteursProvider =
    NotifierProvider<PassagesVisiteursNotifier, List<PassageVisiteur>>(
      PassagesVisiteursNotifier.new,
    );

PassageVehicule _passageVehiculeFromRow(Map<String, dynamic> row) =>
    PassageVehicule(
      id: row['id'].toString(),
      vehiculeId: row['vehicule_id'].toString(),
      mouvementId: row['mouvement_id']?.toString(),
      dateSortie: DateTime.parse(row['date_sortie'] as String),
      dateRetour: row['date_retour'] != null
          ? DateTime.parse(row['date_retour'] as String)
          : null,
      kmRetour: row['km_retour'] as int?,
      enregistrePar: row['enregistre_par'] as String,
    );

class PassagesVehiculesNotifier extends Notifier<List<PassageVehicule>> {
  @override
  List<PassageVehicule> build() {
    Future.microtask(refresh);
    return [];
  }

  Future<void> refresh() async {
    final rows = await logistique
        .from('passage_vehicule')
        .select()
        .order('date_sortie', ascending: false);
    state = (rows as List)
        .map((r) => _passageVehiculeFromRow(r as Map<String, dynamic>))
        .toList();
    ref.read(chargementProvider.notifier).marquerCharge('passages_vehicules');
  }

  Future<void> enregistrerSortie({
    required String vehiculeId,
    required String mouvementId,
    required String enregistrePar,
  }) async {
    await logistique.from('passage_vehicule').insert({
      'vehicule_id': int.parse(vehiculeId),
      'mouvement_id': int.parse(mouvementId),
      'enregistre_par': enregistrePar,
    });
    await refresh();
  }

  Future<void> enregistrerRetour(
    String id, {
    required String vehiculeId,
    required int kmRetour,
  }) async {
    await logistique
        .from('passage_vehicule')
        .update({
          'date_retour': DateTime.now().toIso8601String(),
          'km_retour': kmRetour,
        })
        .eq('id', int.parse(id));
    await ref
        .read(vehiculesProvider.notifier)
        .updateKilometrage(vehiculeId, kmRetour);
    await refresh();
  }
}

final passagesVehiculesProvider =
    NotifierProvider<PassagesVehiculesNotifier, List<PassageVehicule>>(
      PassagesVehiculesNotifier.new,
    );
