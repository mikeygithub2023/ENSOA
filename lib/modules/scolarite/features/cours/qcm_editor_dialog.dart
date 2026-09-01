import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sig_ensoa/core/erreurs.dart';
import 'package:sig_ensoa/core/theme.dart' hide AlertLevel, AlertLevelColor;
import '../../models/cours.dart';
import '../../shared/widgets/common.dart';
import 'data/cours_repository.dart';
import 'providers/cours_providers.dart';

/// Composition du QCM d'un devoir : les questions, leurs propositions de
/// réponse, et les bonnes réponses désignées par son auteur.
///
/// Une question peut compter plusieurs bonnes réponses : l'auteur coche
/// toutes celles qui sont justes. Le barème s'applique alors à chaque
/// proposition cochée par l'élève (+1 si elle est juste, −1 sinon, 0 si
/// elle est laissée de côté).
Future<void> showQcmEditorDialog(
  BuildContext context, {
  required Cours devoir,
  required bool modifiable,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.all(24),
      child: _QcmEditorDialog(devoir: devoir, modifiable: modifiable),
    ),
  );
}

/// Une question en cours d'édition — les contrôleurs de texte vivent ici,
/// pas dans le modèle, qui décrit ce qui est enregistré.
class _QuestionEnCours {
  /// Points maximum de la question : autant que de bonnes réponses.
  int get bareme => indexesBonnesReponses.length;

  _QuestionEnCours({
    required this.enonce,
    required this.propositions,
    Set<int>? indexesBonnesReponses,
  }) // Une copie modifiable : cocher une case ajoute à cet ensemble, et un
    // `const {}` par défaut le rendrait immuable — la case refuserait alors
    // de se cocher, sans rien dire.
    : indexesBonnesReponses = {...?indexesBonnesReponses};

  final TextEditingController enonce;
  final List<TextEditingController> propositions;
  Set<int> indexesBonnesReponses;

  factory _QuestionEnCours.vierge() => _QuestionEnCours(
    enonce: TextEditingController(),
    propositions: [TextEditingController(), TextEditingController()],
  );

  factory _QuestionEnCours.depuis(QcmQuestion question) {
    final propositions = question.propositions;
    return _QuestionEnCours(
      enonce: TextEditingController(text: question.enonce),
      propositions: [
        for (final proposition in propositions)
          TextEditingController(text: proposition.texte),
      ],
      indexesBonnesReponses: {
        for (var i = 0; i < propositions.length; i++)
          if (propositions[i].correcte) i,
      },
    );
  }

  void dispose() {
    enonce.dispose();
    for (final controller in propositions) {
      controller.dispose();
    }
  }
}

class _QcmEditorDialog extends ConsumerStatefulWidget {
  const _QcmEditorDialog({required this.devoir, required this.modifiable});

  final Cours devoir;
  final bool modifiable;

  @override
  ConsumerState<_QcmEditorDialog> createState() => _QcmEditorDialogState();
}

class _QcmEditorDialogState extends ConsumerState<_QcmEditorDialog> {
  final List<_QuestionEnCours> _questions = [];
  bool _initialise = false;
  bool _submitting = false;
  String? _error;

  /// Total des points du devoir : la somme des bonnes réponses de chaque
  /// question, puisque chacune en rapporte un.
  int get _bareme =>
      _questions.fold<int>(0, (somme, question) => somme + question.bareme);

  @override
  void dispose() {
    for (final question in _questions) {
      question.dispose();
    }
    super.dispose();
  }

  void _initialiser(List<QcmQuestion> questions) {
    _initialise = true;
    _questions.addAll(questions.map(_QuestionEnCours.depuis));
    if (_questions.isEmpty && widget.modifiable) {
      _questions.add(_QuestionEnCours.vierge());
    }
  }

  Future<void> _enregistrer() async {
    final drafts = <QcmQuestionDraft>[];
    for (var i = 0; i < _questions.length; i++) {
      final question = _questions[i];
      final enonce = question.enonce.text.trim();
      final propositions = [
        for (final controller in question.propositions)
          if (controller.text.trim().isNotEmpty) controller.text.trim(),
      ];

      if (enonce.isEmpty && propositions.isEmpty) continue;
      if (enonce.isEmpty) {
        setState(() => _error = 'Question ${i + 1} : l\'énoncé manque.');
        return;
      }
      if (propositions.length < 2) {
        setState(
          () => _error =
              'Question ${i + 1} : il faut au moins deux propositions.',
        );
        return;
      }
      // Une proposition cochée peut avoir été vidée entre-temps : on
      // recalcule les positions parmi celles réellement renseignées.
      final indexesRetenus = <int>{};
      for (final index in question.indexesBonnesReponses) {
        if (index >= question.propositions.length) continue;
        final texte = question.propositions[index].text.trim();
        if (texte.isEmpty) continue;
        final position = propositions.indexOf(texte);
        if (position >= 0) indexesRetenus.add(position);
      }
      if (indexesRetenus.isEmpty) {
        setState(
          () =>
              _error = 'Question ${i + 1} : cochez au moins une bonne réponse.',
        );
        return;
      }

      drafts.add(
        QcmQuestionDraft(
          enonce: enonce,
          propositions: propositions,
          indexesBonnesReponses: indexesRetenus,
        ),
      );
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(coursRepositoryProvider)
          .remplacerQuestions(widget.devoir.id, drafts);
      ref.invalidate(qcmQuestionsProvider(widget.devoir.id));
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            drafts.isEmpty
                ? 'QCM vidé.'
                : 'QCM enregistré : ${drafts.length} question(s), noté sur '
                      '$_bareme point(s).',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Échec de l\'enregistrement : ${messageErreur(e)}';
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final width = screenSize.width - 48 < 720 ? screenSize.width - 48 : 720.0;
    final height = screenSize.height - 48 < 800
        ? screenSize.height - 48
        : 800.0;
    final questionsAsync = ref.watch(qcmQuestionsProvider(widget.devoir.id));

    if (!_initialise && questionsAsync.hasValue) {
      _initialiser(questionsAsync.value!);
    }

    return SizedBox(
      width: width,
      height: height,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'QCM — ${widget.devoir.titre}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      Text(
                        '${_questions.length} question(s) — noté sur '
                        '$_bareme point(s). Chaque bonne réponse cochée +1, '
                        'chaque mauvaise −1, une proposition laissée de '
                        'côté 0.',
                        style: const TextStyle(
                          color: AppColors.inkMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Expanded(
            child: questionsAsync.when(
              data: (_) => _questions.isEmpty
                  ? const EmptyState(
                      message: 'Ce devoir ne comporte aucune question.',
                      icon: Icons.quiz_outlined,
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                      itemCount: _questions.length,
                      itemBuilder: (context, index) => _CarteQuestion(
                        numero: index + 1,
                        question: _questions[index],
                        modifiable: widget.modifiable,
                        onChanged: () => setState(() {}),
                        onSupprimer: () => setState(() {
                          _questions.removeAt(index).dispose();
                        }),
                      ),
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => EmptyState(
                message: 'Erreur de chargement : ${messageErreur(error)}',
                icon: Icons.error_outline,
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.danger),
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                if (widget.modifiable)
                  OutlinedButton.icon(
                    onPressed: _submitting
                        ? null
                        : () => setState(
                            () => _questions.add(_QuestionEnCours.vierge()),
                          ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Ajouter une question'),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: _submitting
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: Text(widget.modifiable ? 'Annuler' : 'Fermer'),
                ),
                if (widget.modifiable) ...[
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _submitting ? null : _enregistrer,
                    child: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Enregistrer le QCM'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CarteQuestion extends StatelessWidget {
  const _CarteQuestion({
    required this.numero,
    required this.question,
    required this.modifiable,
    required this.onChanged,
    required this.onSupprimer,
  });

  final int numero;
  final _QuestionEnCours question;
  final bool modifiable;
  final VoidCallback onChanged;
  final VoidCallback onSupprimer;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Question $numero',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              if (modifiable)
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: AppColors.danger,
                  ),
                  tooltip: 'Supprimer la question',
                  onPressed: onSupprimer,
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: question.enonce,
            enabled: modifiable,
            decoration: const InputDecoration(labelText: 'Énoncé'),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          const Text(
            'Propositions — cochez toutes les bonnes réponses',
            style: TextStyle(
              color: AppColors.inkMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          for (var i = 0; i < question.propositions.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Checkbox(
                    value: question.indexesBonnesReponses.contains(i),
                    // Les cases sont indépendantes : une question peut
                    // compter plusieurs bonnes réponses.
                    onChanged: modifiable
                        ? (coche) {
                            if (coche == true) {
                              question.indexesBonnesReponses.add(i);
                            } else {
                              question.indexesBonnesReponses.remove(i);
                            }
                            onChanged();
                          }
                        : null,
                  ),
                  Expanded(
                    child: TextField(
                      controller: question.propositions[i],
                      enabled: modifiable,
                      decoration: InputDecoration(
                        hintText: 'Proposition ${i + 1}',
                        isDense: true,
                      ),
                    ),
                  ),
                  if (modifiable && question.propositions.length > 2)
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: 'Retirer la proposition',
                      onPressed: () {
                        question.propositions.removeAt(i).dispose();
                        // Les cases cochées après celle retirée se décalent
                        // d'un cran ; celle qui la portait disparaît.
                        question.indexesBonnesReponses = {
                          for (final index in question.indexesBonnesReponses)
                            if (index < i) index else if (index > i) index - 1,
                        };
                        onChanged();
                      },
                    ),
                ],
              ),
            ),
          if (modifiable)
            TextButton.icon(
              onPressed: () {
                question.propositions.add(TextEditingController());
                onChanged();
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Ajouter une proposition'),
            ),
        ],
      ),
    );
  }
}
