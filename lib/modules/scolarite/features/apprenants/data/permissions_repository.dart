import 'package:intl/intl.dart';

import 'package:sig_ensoa/core/supabase_client.dart';
import '../../../models/permission.dart';

/// Données saisies pour l'enregistrement d'une permission.
class PermissionDraft {
  const PermissionDraft({
    required this.apprenantId,
    required this.divisionId,
    required this.classeId,
    required this.dateDepart,
    required this.dateRetour,
    this.localite,
    this.motif,
    this.personneContact,
  });

  final String apprenantId;
  final String divisionId;
  final String classeId;
  final DateTime dateDepart;
  final DateTime dateRetour;
  final String? localite;
  final String? motif;
  final String? personneContact;

  Map<String, dynamic> toInsertJson() {
    final fmt = DateFormat('yyyy-MM-dd');
    return {
      'apprenant_id': apprenantId,
      'division_id': divisionId,
      'classe_id': classeId,
      'date_depart': fmt.format(dateDepart),
      'date_retour': fmt.format(dateRetour),
      'localite': localite,
      'motif': motif,
      'personne_contact': personneContact,
    };
  }
}

class PermissionsRepository {
  Future<List<Permission>> fetchByClasse(String classeId) async {
    final rows = await scolarite
        .from('permissions')
        .select()
        .eq('classe_id', classeId)
        .order('date_depart', ascending: false);
    return rows.map(Permission.fromJson).toList();
  }

  /// Toutes les permissions d'une division, toutes phases et stages
  /// confondues — utilisé sous "Toutes phases / stages".
  Future<List<Permission>> fetchByDivision(String divisionId) async {
    final rows = await scolarite
        .from('permissions')
        .select()
        .eq('division_id', divisionId)
        .order('date_depart', ascending: false);
    return rows.map(Permission.fromJson).toList();
  }

  /// Toutes celles que l'utilisateur a le droit de voir, divisions
  /// confondues — la vue « Toutes ». La RLS borne le résultat.
  Future<List<Permission>> fetchToutes() async {
    final rows = await scolarite
        .from('permissions')
        .select()
        .order('date_depart', ascending: false);
    return rows.map(Permission.fromJson).toList();
  }

  /// Toutes les permissions d'un apprenant précis — utilisé dans sa fiche
  /// détaillée.
  Future<List<Permission>> fetchByApprenant(String apprenantId) async {
    final rows = await scolarite
        .from('permissions')
        .select()
        .eq('apprenant_id', apprenantId)
        .order('date_depart', ascending: false);
    return rows.map(Permission.fromJson).toList();
  }

  Future<void> createPermission(PermissionDraft draft) async {
    await scolarite.from('permissions').insert(draft.toInsertJson());
  }

  /// Corriger une permission déjà enregistrée — une date mal saisie, une
  /// localité oubliée. L'apprenant, lui, ne change pas : se tromper de
  /// bénéficiaire se répare en supprimant la permission et en la reprenant,
  /// car c'est une autre permission.
  Future<void> updatePermission(
    String permissionId,
    PermissionDraft draft,
  ) async {
    final modifiees = await scolarite
        .from('permissions')
        .update(draft.toInsertJson())
        .eq('id', permissionId)
        .select('id');

    // Sans ce `select`, une modification que la RLS refuse passerait pour un
    // succès : PostgREST répond « aucune ligne touchée », sans erreur.
    if (modifiees.isEmpty) {
      throw Exception(
        'Aucune permission n\'a été modifiée : votre rôle ne vous y autorise '
        'pas, ou elle ne relève pas de votre commandement.',
      );
    }
  }

  Future<void> deletePermission(String permissionId) async {
    await scolarite.from('permissions').delete().eq('id', permissionId);
  }
}
