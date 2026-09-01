import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sig_ensoa/core/theme.dart';
import '../../shared/widgets/widgets.dart';

/// Menu de suppression commun aux articles de l'armement — armes, calibres,
/// équipements, types d'arme.
///
/// Un seul widget pour les quatre : la confirmation, la garde et le
/// traitement de l'erreur sont identiques, seul le texte change. Les répéter
/// dans chaque onglet finirait par les faire diverger.
///
/// [empechement] renseigné interdit la suppression et en donne la raison :
/// une arme sortie ne quitte pas le registre tant qu'elle n'est pas rentrée.
/// [avertissement] laisse passer mais prévient — un stock encore garni, par
/// exemple.
class MenuSuppressionArticle extends ConsumerStatefulWidget {
  const MenuSuppressionArticle({
    super.key,
    required this.titre,
    required this.designation,
    required this.onSupprimer,
    this.empechement,
    this.avertissement,
  });

  /// Titre de la boîte de confirmation : « Supprimer l'arme ».
  final String titre;

  /// Ce qui est supprimé, tel qu'on le nomme : « SIG 543 n° 123456 ».
  final String designation;

  final Future<void> Function() onSupprimer;

  /// Raison pour laquelle la suppression est refusée, ou `null` si elle est
  /// permise.
  final String? empechement;

  /// Mise en garde à afficher avant de confirmer, sans bloquer.
  final String? avertissement;

  @override
  ConsumerState<MenuSuppressionArticle> createState() =>
      _MenuSuppressionArticleState();
}

class _MenuSuppressionArticleState
    extends ConsumerState<MenuSuppressionArticle> {
  bool _envoi = false;

  Future<void> _confirmer() async {
    final empechement = widget.empechement;
    if (empechement != null) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          title: Text('Suppression impossible'),
          content: Text(empechement),
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

    final avertissement = widget.avertissement;
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(widget.titre),
        content: Text(
          avertissement == null
              ? '${widget.designation} sera retiré des listes actives. '
                    'L\'historique le concernant reste conservé.'
              : '$avertissement\n\n'
                    '${widget.designation} sera retiré des listes actives. '
                    'L\'historique le concernant reste conservé.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: avertissement == null
                ? null
                : FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirme != true || !mounted) return;

    setState(() => _envoi = true);
    try {
      await widget.onSupprimer();
      if (mounted) showSuccessSnackBar(context, 'Suppression effectuée.');
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, e);
      }
    } finally {
      // Remis à zéro même après un succès. En principe le widget a disparu
      // avec sa ligne ; mais si l'état venait à être réutilisé pour une
      // autre ligne, il ne doit pas lui transmettre ce sablier.
      if (mounted) setState(() => _envoi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_envoi) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return IconButton(
      tooltip: 'Supprimer',
      visualDensity: VisualDensity.compact,
      icon: const Icon(
        Icons.delete_outline,
        size: 20,
        color: AppColors.inkMuted,
      ),
      onPressed: _confirmer,
    );
  }
}
