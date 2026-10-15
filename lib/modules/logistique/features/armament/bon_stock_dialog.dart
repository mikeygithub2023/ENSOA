import 'package:sig_ensoa/core/formulaire.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sig_ensoa/modules/logistique/compat.dart';
import '../../data/models/armement.dart';
import '../../data/repositories/armament_providers.dart';
import '../../shared/widgets/widgets.dart';

/// Bon d'entrée ou de sortie — pour les munitions comme pour les
/// équipements de protection.
///
/// Ce dialogue a remplacé un simple ajustement de quantité. La différence
/// n'est pas cosmétique : un stock qui baisse sans dire à qui, quand et
/// pourquoi n'est pas un registre d'armurerie. Chaque passage ici écrit un
/// bon, et c'est le bon qui meut le stock.
class BonStockDialog extends ConsumerStatefulWidget {
  const BonStockDialog({
    super.key,
    required this.famille,
    required this.articleId,
    required this.libelleArticle,
    required this.quantiteActuelle,
  });

  final FamilleArticle famille;
  final String articleId;
  final String libelleArticle;
  final int quantiteActuelle;

  @override
  ConsumerState<BonStockDialog> createState() => _BonStockDialogState();
}

class _BonStockDialogState extends ConsumerState<BonStockDialog> {
  final _formKey = GlobalKey<FormState>();
  final _qteCtrl = TextEditingController();
  final _matriculeCtrl = TextEditingController();
  final _nomCtrl = TextEditingController();
  final _motifCtrl = TextEditingController();
  SensMouvement _sens = SensMouvement.sortie;
  bool _envoi = false;

  @override
  void dispose() {
    _qteCtrl.dispose();
    _matriculeCtrl.dispose();
    _nomCtrl.dispose();
    _motifCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sortie = _sens == SensMouvement.sortie;
    return AlertDialog(
      scrollable: true,
      title: Text(_sens.libelleBon),
      content: SizedBox(
        width: 380,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.libelleArticle} — stock actuel : '
                '${widget.quantiteActuelle}',
              ),
              const SizedBox(height: 16),
              SegmentedButton<SensMouvement>(
                segments: const [
                  ButtonSegment(
                    value: SensMouvement.sortie,
                    label: Text('Sortie'),
                    icon: Icon(Icons.arrow_upward),
                  ),
                  ButtonSegment(
                    value: SensMouvement.entree,
                    label: Text('Entrée'),
                    icon: Icon(Icons.arrow_downward),
                  ),
                ],
                selected: {_sens},
                onSelectionChanged: (s) => setState(() => _sens = s.first),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _qteCtrl,
                decoration: const InputDecoration(labelText: 'Quantité'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  final n = int.tryParse((v ?? '').trim()) ?? 0;
                  if (n <= 0) return 'Quantité invalide';
                  // La base refuserait de toute façon, mais autant le dire
                  // avant la saisie du bénéficiaire que dans un message
                  // d'erreur une fois le bon rempli.
                  if (sortie && n > widget.quantiteActuelle) {
                    return 'Il ne reste que ${widget.quantiteActuelle}';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _matriculeCtrl,
                decoration: InputDecoration(
                  labelText: sortie
                      ? 'Matricule du bénéficiaire'
                      : 'Matricule (facultatif)',
                ),
                validator: (v) => sortie && (v == null || v.trim().isEmpty)
                    ? 'Un bon de sortie nomme celui qui perçoit'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nomCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nom et prénoms (facultatif)',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _motifCtrl,
                decoration: InputDecoration(
                  labelText: sortie
                      ? 'Motif (séance de tir, garde, mission...)'
                      : 'Provenance (dotation, réintégration...)',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _envoi ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _envoi ? null : _submit,
          child: Text(_envoi ? 'Enregistrement...' : 'Enregistrer le bon'),
        ),
      ],
    );
  }

  String? _net(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _submit() async {
    if (!validerFormulaire(context, _formKey)) return;
    setState(() => _envoi = true);
    final qte = int.parse(_qteCtrl.text.trim());
    try {
      await ref
          .read(mouvementsArticleProvider.notifier)
          .enregistrer(
            famille: widget.famille,
            articleId: widget.articleId,
            sens: _sens,
            quantite: qte,
            beneficiaireMatricule: _net(_matriculeCtrl),
            beneficiaireNom: _net(_nomCtrl),
            motif: _net(_motifCtrl),
            auteurId: ref.read(sessionProvider)?.user.id,
          );
      if (mounted) {
        showSuccessSnackBar(
          context,
          '${_sens.libelleBon} enregistré : $qte '
          '${widget.libelleArticle}.',
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _envoi = false);
        showErrorSnackBar(context, e);
      }
    }
  }
}

/// Ouvre un bon depuis la sous-rubrique « Bons », où aucun article n'est
/// encore désigné : on choisit d'abord l'article, puis on remplit le bon.
///
/// Depuis la sous-rubrique « Stock », l'article est déjà connu — on y
/// ouvre [BonStockDialog] directement.
Future<void> afficherNouveauBon(
  BuildContext context,
  WidgetRef ref,
  FamilleArticle famille,
) async {
  final munitions = famille == FamilleArticle.munition;
  final articles = munitions
      ? [
          for (final m in ref.read(munitionsProvider))
            (id: m.id, nom: 'calibre ${m.calibre}', qte: m.quantiteDisponible),
        ]
      : [
          for (final e in ref.read(equipementsProvider))
            (id: e.id, nom: e.libelle, qte: e.quantiteDisponible),
        ];

  if (articles.isEmpty) {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rien à mouvementer'),
        content: Text(
          munitions
              ? 'Aucun calibre n\'est enregistré. Créez-en un depuis la '
                    'sous-rubrique « Stock » avant d\'établir un bon.'
              : 'Aucun équipement n\'est enregistré. Créez-en un depuis la '
                    'sous-rubrique « Stock » avant d\'établir un bon.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('J\'ai compris'),
          ),
        ],
      ),
    );
    return;
  }

  final choix = await showDialog<int>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(munitions ? 'Quel calibre ?' : 'Quel équipement ?'),
      children: [
        for (var i = 0; i < articles.length; i++)
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(i),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(articles[i].nom),
              subtitle: Text('${articles[i].qte} en stock'),
            ),
          ),
      ],
    ),
  );
  if (choix == null || !context.mounted) return;

  final article = articles[choix];
  await showDialog<void>(
    context: context,
    builder: (_) => BonStockDialog(
      famille: famille,
      articleId: article.id,
      libelleArticle: article.nom,
      quantiteActuelle: article.qte,
    ),
  );
}
