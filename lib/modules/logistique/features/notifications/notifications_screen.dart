import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:sig_ensoa/core/roles.dart';
import 'package:sig_ensoa/core/theme.dart';
import 'package:sig_ensoa/features/auth/providers/auth_providers.dart';
import 'package:sig_ensoa/modules/scolarite/features/apprenants/providers/controles_providers.dart';
import '../../data/models/notification_item.dart';
import '../../data/repositories/misc_providers.dart';
import '../../shared/widgets/widgets.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);
    final df = DateFormat('dd/MM/yyyy HH:mm');

    // Seul l'administrateur de la scolarité tranche une demande de
    // suppression de note : c'est ce que dit la RLS, et l'écran ne propose
    // donc le choix qu'à lui. Un bouton qui se ferait refuser par le serveur
    // ne vaut pas mieux qu'une absence de bouton.
    final peutTrancher =
        ref.watch(profilCourantProvider).value?.roleScolarite ==
        RoleScolarite.admin;

    return ScreenScaffold(
      title: 'Notifications',
      children: [
        if (notifications.isEmpty)
          const EmptyState(message: 'Aucune notification'),
        for (final n in notifications) ...[
          Card(
            color: n.lue
                ? null
                : Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
            child: ListTile(
              onTap: () => _marquerLue(context, ref, n),
              leading: CircleAvatar(
                backgroundColor: _color(n.categorie).withValues(alpha: 0.12),
                child: Icon(
                  Icons.notifications_rounded,
                  color: _color(n.categorie),
                ),
              ),
              title: Text(
                n.titre,
                style: TextStyle(
                  fontWeight: n.lue ? FontWeight.normal : FontWeight.bold,
                ),
              ),
              subtitle: Text('${n.message}\n${df.format(n.date)}'),
              isThreeLine: true,
              trailing: n.lue
                  ? null
                  : Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.ivoryOrange,
                        shape: BoxShape.circle,
                      ),
                    ),
            ),
          ),
          // Une demande de suppression se tranche là où on la lit. Elle
          // n'attendait jusqu'ici aucune réponse : l'administrateur
          // apprenait qu'on lui demandait quelque chose, et devait retrouver
          // la note à la main, dans le contrôle d'où elle venait, pour y
          // répondre.
          if (n.estDemandeDeSuppression && peutTrancher)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => _rejeter(context, ref, n),
                    child: const Text('Rejeter la demande'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => _confirmer(context, ref, n),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Supprimer la note'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.danger,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Color _color(NotificationCategory c) {
    switch (c) {
      case NotificationCategory.carburant:
        return AppColors.ivoryOrange;
      case NotificationCategory.maintenance:
        return AppColors.warning;
      case NotificationCategory.armement:
        return AppColors.militaryGreen;
      case NotificationCategory.systeme:
        return AppColors.danger;
      case NotificationCategory.activite:
        return AppColors.blueDeep;
    }
  }
}

/// Un clic éteint la notification. Si le serveur refuse — le réseau est
/// tombé, la ligne ne m'appartient pas —, elle se rallume et l'on dit
/// pourquoi : sans cela elle se rallumait seule au rafraîchissement
/// suivant, sans que personne comprenne.
Future<void> _marquerLue(
  BuildContext context,
  WidgetRef ref,
  AppNotification n,
) async {
  if (n.lue) return;
  final messager = ScaffoldMessenger.of(context);
  try {
    await ref.read(notificationsProvider.notifier).markRead(n.id);
  } catch (e) {
    messager
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: AppColors.danger,
          content: Text('Notification non marquée comme lue : $e'),
        ),
      );
  }
}

/// Rejeter la demande : la note reste, la marque « suppression demandée »
/// s'efface, et la notification disparaît de la liste de tous les
/// administrateurs — elle n'attend plus de réponse.
Future<void> _rejeter(
  BuildContext context,
  WidgetRef ref,
  AppNotification n,
) async {
  final messager = ScaffoldMessenger.of(context);
  final confirme = await _demanderConfirmation(
    context,
    titre: 'Rejeter la demande',
    texte:
        'La note sera conservée et la demande annulée. '
        'Celui qui l\'a formulée pourra la refaire.',
    action: 'Rejeter',
  );
  if (confirme != true) return;

  try {
    await ref.read(controlesRepositoryProvider).rejectNoteDeletion(n.noteId!);
    await ref.read(notificationsProvider.notifier).refresh();
    messager.showSnackBar(
      const SnackBar(
        content: Text('Demande rejetée. La note est conservée.'),
        backgroundColor: AppColors.success,
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    showErrorSnackBar(context, e, action: 'Rejet impossible');
  }
}

/// Confirmer la demande : la note est supprimée pour de bon. La notification
/// part avec elle — `notifications.note_id` est en `on delete cascade`.
Future<void> _confirmer(
  BuildContext context,
  WidgetRef ref,
  AppNotification n,
) async {
  final messager = ScaffoldMessenger.of(context);
  final confirme = await _demanderConfirmation(
    context,
    titre: 'Supprimer la note',
    texte:
        'La note sera supprimée définitivement. Le journal d\'audit en '
        'garde la trace, mais la valeur, elle, ne se retrouve pas.',
    action: 'Supprimer',
  );
  if (confirme != true) return;

  try {
    await ref.read(controlesRepositoryProvider).deleteNote(n.noteId!);
    await ref.read(notificationsProvider.notifier).refresh();
    messager.showSnackBar(
      const SnackBar(
        content: Text('Note supprimée.'),
        backgroundColor: AppColors.success,
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    showErrorSnackBar(context, e, action: 'Suppression impossible');
  }
}

Future<bool?> _demanderConfirmation(
  BuildContext context, {
  required String titre,
  required String texte,
  required String action,
}) => showDialog<bool>(
  context: context,
  builder: (context) => AlertDialog(
    scrollable: true,
    title: Text(titre),
    content: Text(texte),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(false),
        child: const Text('Annuler'),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(true),
        child: Text(action),
      ),
    ],
  ),
);
