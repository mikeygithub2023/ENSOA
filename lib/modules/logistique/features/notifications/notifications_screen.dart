import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:sig_ensoa/core/theme.dart';
import '../../data/models/notification_item.dart';
import '../../data/repositories/misc_providers.dart';
import '../../shared/widgets/widgets.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);
    final df = DateFormat('dd/MM/yyyy HH:mm');

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
              onTap: () =>
                  ref.read(notificationsProvider.notifier).markRead(n.id),
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
