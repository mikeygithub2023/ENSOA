import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:sig_ensoa/modules/logistique/compat.dart';
import 'package:sig_ensoa/core/theme.dart';
import 'package:sig_ensoa/core/chargement.dart';
import '../../data/models/oa.dart';
import '../../data/repositories/misc_providers.dart';
import '../../data/repositories/oa_providers.dart';
import '../../shared/widgets/skeleton.dart';
import '../../shared/widgets/widgets.dart';

/// Tâches marquées terminées par leur acteur, en attente de validation par
/// l'OA — la file de travail principale de cet onglet.
class ValidationsTabContent extends ConsumerStatefulWidget {
  const ValidationsTabContent({super.key});

  @override
  ConsumerState<ValidationsTabContent> createState() =>
      _ValidationsTabContentState();
}

class _ValidationsTabContentState extends ConsumerState<ValidationsTabContent> {
  final Set<String> _validationsEnCours = {};

  Future<void> _valider(TacheActivite t) async {
    setState(() => _validationsEnCours.add(t.id));
    final user = ref.read(sessionProvider)?.user;
    try {
      await ref.read(tachesProvider.notifier).valider(t.id);
      if (user != null) {
        ref
            .read(auditProvider.notifier)
            .log(
              auteurId: user.id,
              action: 'TACHE_VALIDEE',
              cible: t.description,
            );
      }
      if (mounted) showSuccessSnackBar(context, 'Tâche validée avec succès.');
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, e);
      }
    } finally {
      if (mounted) setState(() => _validationsEnCours.remove(t.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final charge = estCharge(ref, ['taches', 'activites']);
    final enAttente = List.of(ref.watch(tachesEnAttenteValidationProvider))
      ..sort(
        (a, b) => (a.termineeLe ?? DateTime(2000)).compareTo(
          b.termineeLe ?? DateTime(2000),
        ),
      );
    final activites = ref.watch(activitesProvider);
    final df = DateFormat('dd/MM/yyyy HH:mm');

    if (!charge) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(4, 4, 4, 100),
        child: SkeletonList(itemCount: 3),
      );
    }

    String activiteTitre(String id) {
      for (final a in activites) {
        if (a.id == id) return a.titre;
      }
      return 'Activité inconnue';
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 100),
      children: [
        SectionHeader(title: 'En attente de validation (${enAttente.length})'),
        if (enAttente.isEmpty)
          const EmptyState(message: 'Aucune tâche en attente de validation'),
        for (final t in enAttente) ...[
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.warning.withValues(alpha: 0.12),
                child: const Icon(
                  Icons.hourglass_top_outlined,
                  color: AppColors.warning,
                ),
              ),
              title: Text(t.description),
              subtitle: Text(
                '${activiteTitre(t.activiteId)} · ${t.destinataire}'
                '${t.termineeLe != null ? ' · terminée le ${df.format(t.termineeLe!)}' : ''}'
                '${t.commentaire != null ? '\n${t.commentaire}' : ''}',
              ),
              isThreeLine: t.commentaire != null,
              trailing: OutlinedButton(
                onPressed: _validationsEnCours.contains(t.id)
                    ? null
                    : () => _valider(t),
                child: _validationsEnCours.contains(t.id)
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Valider'),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}
