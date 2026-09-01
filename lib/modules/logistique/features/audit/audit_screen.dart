import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:sig_ensoa/core/chargement.dart';
import '../../data/models/user.dart';
import '../../data/repositories/misc_providers.dart';
import '../../shared/widgets/skeleton.dart';
import '../../shared/widgets/widgets.dart';

class AuditScreen extends ConsumerWidget {
  const AuditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Le journal remonte cinq cents lignes et les noms de leurs auteurs :
    // l'attente se voit. Sans rien pour la signaler, l'écran s'ouvrait vide
    // et donnait à croire qu'il n'y avait rien à lire.
    final charge = estCharge(ref, ['journal', 'utilisateurs']);
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
        if (!charge)
          const SkeletonList(itemCount: 6)
        else if (entries.isEmpty)
          const EmptyState(message: 'Aucune entrée')
        else
          Card(
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: entries.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final e = entries[i];
                return ListTile(
                  leading: const Icon(Icons.receipt_long_outlined),
                  title: Text('${e.action} — ${e.cible}'),
                  subtitle: Text(
                    '${_auteur(users, e.auteurId)} · ${df.format(e.date)}'
                    '${e.detail != null ? ' · ${e.detail}' : ''}',
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

/// Qui a fait l'action, nommé comme on le nomme dans la maison.
///
/// La ligne portait jusqu'ici l'identifiant technique du compte —
/// « 59978b52-9277-40c9… » — qui ne dit rien à personne. Un journal d'audit
/// sert à savoir qui a agi ; s'il faut aller chercher ailleurs à qui
/// appartient l'identifiant, il ne remplit pas son office.
String _auteur(List<AppUser> users, String auteurId) {
  final auteur = findUser(users, auteurId);
  if (auteur == null) return 'Auteur inconnu';

  final nom = auteur.nomComplet.trim();
  if (nom.isEmpty) {
    return auteur.matricule.isEmpty ? 'Auteur inconnu' : auteur.matricule;
  }

  final grade = auteur.grade.trim();
  final nomme = grade.isEmpty ? nom : '$grade $nom';
  return auteur.matricule.isEmpty ? nomme : '$nomme (${auteur.matricule})';
}
