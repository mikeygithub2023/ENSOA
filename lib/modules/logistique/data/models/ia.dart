/// Réponse structurée renvoyée par la fonction serveur `admin-ai-assistant` —
/// toujours un texte, éventuellement accompagné d'un graphique simple pour
/// faciliter la lecture des chiffres.
class AiReponse {
  final String question;
  final String reponse;
  final AiGraphique? graphique;
  final List<String> pointsCles;

  const AiReponse({
    required this.question,
    required this.reponse,
    this.graphique,
    this.pointsCles = const [],
  });

  factory AiReponse.fromJson(String question, Map<String, dynamic> json) {
    final graphiqueJson = json['graphique'] as Map<String, dynamic>?;
    return AiReponse(
      question: question,
      reponse: (json['reponse'] as String?) ?? '',
      graphique: graphiqueJson == null || graphiqueJson['type'] == 'aucun'
          ? null
          : AiGraphique.fromJson(graphiqueJson),
      pointsCles:
          (json['points_cles'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
    );
  }
}

enum AiGraphiqueType { barres, camembert }

class AiGraphique {
  final AiGraphiqueType type;
  final String titre;
  final List<AiSerie> series;

  const AiGraphique({
    required this.type,
    required this.titre,
    required this.series,
  });

  factory AiGraphique.fromJson(Map<String, dynamic> json) {
    return AiGraphique(
      type: json['type'] == 'camembert'
          ? AiGraphiqueType.camembert
          : AiGraphiqueType.barres,
      titre: (json['titre'] as String?) ?? '',
      series: (json['series'] as List? ?? [])
          .map(
            (e) => AiSerie(
              label: (e['label'] ?? '').toString(),
              valeur: (e['valeur'] as num?)?.toDouble() ?? 0,
            ),
          )
          .toList(),
    );
  }
}

class AiSerie {
  final String label;
  final double valeur;
  const AiSerie({required this.label, required this.valeur});
}
