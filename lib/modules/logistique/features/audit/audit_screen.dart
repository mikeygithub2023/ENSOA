import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/repositories/misc_providers.dart';
import '../../shared/widgets/widgets.dart';

class AuditScreen extends ConsumerWidget {
  const AuditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(auditProvider);
    final users = ref.watch(usersProvider);
    final df = DateFormat('dd/MM/yyyy HH:mm:ss');

    return ScreenScaffold(
      title: "Journal d'audit",
      children: [
        Text(
          'Toutes les actions sensibles (connexions, mouvements de carburant, remises d\'armes...) sont journalisées et non modifiables.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        if (entries.isEmpty) const EmptyState(message: 'Aucune entrée'),
        Card(
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: entries.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final e = entries[i];
              final auteur = findUser(users, e.auteurId);
              return ListTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: Text('${e.action} — ${e.cible}'),
                subtitle: Text(
                  '${auteur?.nomComplet ?? e.auteurId} · ${df.format(e.date)}${e.detail != null ? ' · ${e.detail}' : ''}',
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
