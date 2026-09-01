import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sig_ensoa/core/theme.dart' hide AlertLevel, AlertLevelColor;
import 'package:sig_ensoa/modules/scolarite/compat.dart';

/// N'affiche [child] que si le rôle de l'utilisateur connecté figure dans
/// [allowedRoles]. Sinon affiche un message d'accès refusé.
class RoleGate extends ConsumerWidget {
  const RoleGate({super.key, required this.allowedRoles, required this.child});

  final Set<AppRole> allowedRoles;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);

    return profileAsync.when(
      data: (profile) {
        if (profile != null && allowedRoles.contains(profile.role)) {
          return child;
        }
        return const _AccesRefuse();
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => const _AccesRefuse(),
    );
  }
}

class _AccesRefuse extends StatelessWidget {
  const _AccesRefuse();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline, size: 48, color: AppColors.textMuted),
          SizedBox(height: 12),
          Text(
            'Accès non autorisé pour votre rôle',
            style: TextStyle(color: AppColors.textMuted, fontSize: 15),
          ),
        ],
      ),
    );
  }
}
