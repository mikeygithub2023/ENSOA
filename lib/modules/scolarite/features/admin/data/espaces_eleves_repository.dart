import 'package:sig_ensoa/core/supabase_client.dart';

/// Sort de l'espace d'un apprenant après une demande d'ouverture ou de
/// fermeture : ce qui a été fait, et pour ceux qu'on a laissés de côté,
/// pourquoi.
class ResultatEspace {
  const ResultatEspace({
    required this.apprenantId,
    required this.nom,
    required this.statut,
    this.motif,
  });

  final String apprenantId;
  final String nom;

  /// `cree`, `supprime` ou `ignore`.
  final String statut;
  final String? motif;

  bool get traite => statut != 'ignore';

  factory ResultatEspace.fromJson(Map<String, dynamic> json) {
    return ResultatEspace(
      apprenantId: json['apprenantId'] as String,
      nom: json['nom'] as String? ?? 'Apprenant',
      statut: json['statut'] as String? ?? 'ignore',
      motif: json['motif'] as String?,
    );
  }
}

/// Ouverture et fermeture des espaces élèves.
///
/// Tout passe par une fonction serveur : créer ou supprimer un compte exige
/// la clé de service, qui n'est jamais embarquée dans l'application.
class EspacesElevesRepository {
  Future<List<ResultatEspace>> creer({
    String? classeId,
    List<String>? apprenantIds,
  }) {
    return _appeler('creer', classeId: classeId, apprenantIds: apprenantIds);
  }

  Future<List<ResultatEspace>> supprimer({
    String? classeId,
    List<String>? apprenantIds,
  }) {
    return _appeler(
      'supprimer',
      classeId: classeId,
      apprenantIds: apprenantIds,
    );
  }

  Future<List<ResultatEspace>> _appeler(
    String action, {
    String? classeId,
    List<String>? apprenantIds,
  }) async {
    final response = await supabase.functions.invoke(
      'espaces-eleves',
      body: {
        'action': action,
        'classeId': ?classeId,
        if (apprenantIds != null && apprenantIds.isNotEmpty)
          'apprenantIds': apprenantIds,
      },
    );
    final data = response.data;
    if (response.status != 200) {
      final message = data is Map && data['error'] != null
          ? data['error'].toString()
          : 'Opération impossible';
      throw Exception(message);
    }
    final resultats =
        (data is Map ? data['resultats'] : null) as List<dynamic>?;
    return (resultats ?? const [])
        .map((e) => ResultatEspace.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
