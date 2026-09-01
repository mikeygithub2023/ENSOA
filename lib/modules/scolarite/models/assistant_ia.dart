/// Réponse de l'assistant, telle que la fonction serveur `assistant-ia` la
/// rend : toujours un texte, parfois des points clés, et un graphique
/// lorsque la question appelle une lecture visuelle.
///
/// Le modèle est tenu de répondre dans cette forme exacte ; on se garde tout
/// de même de faire confiance à chaque champ, un modèle de langage pouvant
/// toujours livrer une réponse mal formée.
class ReponseIa {
  const ReponseIa({
    required this.question,
    required this.reponse,
    this.graphique,
    this.pointsCles = const [],
  });

  final String question;
  final String reponse;
  final GraphiqueIa? graphique;
  final List<String> pointsCles;

  factory ReponseIa.fromJson(String question, Map<String, dynamic> json) {
    final graphique = json['graphique'];
    return ReponseIa(
      question: question,
      reponse: (json['reponse'] as String?)?.trim().isNotEmpty == true
          ? json['reponse'] as String
          : 'L\'assistant n\'a pas su répondre à cette question.',
      graphique:
          graphique is Map<String, dynamic> && graphique['type'] != 'aucun'
          ? GraphiqueIa.fromJson(graphique)
          : null,
      pointsCles:
          (json['points_cles'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
    );
  }
}

enum TypeGraphiqueIa { barres, camembert }

class GraphiqueIa {
  const GraphiqueIa({
    required this.type,
    required this.titre,
    required this.series,
  });

  final TypeGraphiqueIa type;
  final String titre;
  final List<SerieIa> series;

  /// Un graphique sans série n'a rien à montrer : autant ne pas l'afficher.
  bool get exploitable => series.isNotEmpty;

  factory GraphiqueIa.fromJson(Map<String, dynamic> json) {
    return GraphiqueIa(
      type: json['type'] == 'camembert'
          ? TypeGraphiqueIa.camembert
          : TypeGraphiqueIa.barres,
      titre: (json['titre'] as String?) ?? '',
      series: (json['series'] as List? ?? [])
          .whereType<Map>()
          .map(
            (e) => SerieIa(
              label: (e['label'] ?? '').toString(),
              valeur: (e['valeur'] as num?)?.toDouble() ?? 0,
            ),
          )
          .toList(),
    );
  }
}

class SerieIa {
  const SerieIa({required this.label, required this.valeur});

  final String label;
  final double valeur;
}
