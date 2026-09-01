import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sig_ensoa/core/supabase_client.dart';
import 'package:sig_ensoa/core/theme.dart';
import '../../data/models/ia.dart';
import '../../shared/widgets/mini_charts.dart';
import '../../shared/widgets/widgets.dart';

/// L'assistant — l'administrateur pose une question en langage naturel sur
/// l'état de l'école ; la fonction serveur `assistant-ia` rassemble un
/// instantané des données, interroge DeepSeek, et renvoie une réponse
/// structurée (texte + graphique éventuel) affichée ici.
class AssistantIa extends ConsumerStatefulWidget {
  const AssistantIa({super.key});

  @override
  ConsumerState<AssistantIa> createState() => _AssistantIaState();
}

class _AssistantIaState extends ConsumerState<AssistantIa> {
  final _questionCtrl = TextEditingController();
  final _scrollController = ScrollController();
  final List<AiReponse> _historique = [];
  bool _enCours = false;
  String? _erreur;

  @override
  void dispose() {
    _questionCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _poserQuestion() async {
    final question = _questionCtrl.text.trim();
    if (question.isEmpty || _enCours) return;
    setState(() {
      _enCours = true;
      _erreur = null;
    });
    _questionCtrl.clear();
    try {
      final reponse = await supabase.functions.invoke(
        'assistant-ia',
        body: {'question': question},
      );
      final data = reponse.data;
      if (data is Map && data['error'] != null) throw Exception(data['error']);
      setState(
        () => _historique.add(
          AiReponse.fromJson(question, Map<String, dynamic>.from(data as Map)),
        ),
      );
    } catch (e) {
      setState(() => _erreur = 'Erreur : $e');
    } finally {
      if (mounted) setState(() => _enCours = false);
      await Future.delayed(const Duration(milliseconds: 100));
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _historique.isEmpty && !_enCours && _erreur == null
              ? const EmptyState(
                  icon: Icons.auto_awesome_outlined,
                  message:
                      'Posez une question sur les données de l\'ERP — ex. "Quel est l\'état du parc automobile ?", '
                      '"Répartis les munitions par calibre", "Y a-t-il des tâches en retard ?"',
                )
              : ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
                  children: [
                    for (final r in _historique) ...[
                      _bulleQuestion(r.question),
                      const SizedBox(height: 10),
                      _carteReponse(r),
                      const SizedBox(height: 20),
                    ],
                    if (_enCours)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Analyse en cours...',
                              style: TextStyle(color: AppColors.inkMuted),
                            ),
                          ],
                        ),
                      ),
                    if (_erreur != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _erreur!,
                          style: const TextStyle(color: AppColors.danger),
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _questionCtrl,
                decoration: const InputDecoration(
                  hintText: 'Poser une question sur les données de l\'ERP...',
                ),
                onSubmitted: (_) => _poserQuestion(),
              ),
            ),
            const SizedBox(width: 12),
            IconButton.filled(
              onPressed: _enCours ? null : _poserQuestion,
              icon: const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ],
    );
  }

  Widget _bulleQuestion(String question) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.navy,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          question,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _carteReponse(AiReponse r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome_outlined,
                      size: 18,
                      color: AppColors.blueDeep,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Analyse',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: AppColors.blueDeep,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(r.reponse, style: const TextStyle(color: AppColors.ink)),
                if (r.pointsCles.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  for (final p in r.pointsCles)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Icon(
                              Icons.circle,
                              size: 5,
                              color: AppColors.inkMuted,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              p,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.inkMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
        if (r.graphique != null) ...[
          const SizedBox(height: 12),
          AiGraphiqueWidget(graphique: r.graphique!),
        ],
      ],
    );
  }
}
