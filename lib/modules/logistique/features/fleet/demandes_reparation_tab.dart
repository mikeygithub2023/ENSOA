import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:sig_ensoa/core/chargement.dart';
import 'package:sig_ensoa/core/roles.dart';
import 'package:sig_ensoa/core/theme.dart';
import 'package:sig_ensoa/modules/logistique/compat.dart';
import '../../data/models/pannes.dart';
import '../../data/models/vehicule.dart';
import '../../data/repositories/fleet_providers.dart';
import '../../data/repositories/pannes_providers.dart';
import '../../shared/widgets/widgets.dart';

/// L'onglet des demandes de mise en réparation.
///
/// Une demande naît au vu des pannes d'un véhicule ; elle attend ici la
/// décision d'un supérieur. L'administrateur la valide — le véhicule passe
/// alors « En réparation » et la réparation s'ouvre — ou la refuse. Les
/// demandes en attente passent devant.
class DemandesReparationTab extends ConsumerWidget {
  const DemandesReparationTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final charge = estCharge(ref, [
      'demandes_reparation',
      'pannes',
      'vehicules',
    ]);
    final demandes = ref.watch(demandesReparationProvider);
    final vehicules = ref.watch(vehiculesProvider);
    final pannes = ref.watch(pannesProvider);
    final parId = {for (final v in vehicules) v.id: v};
    final estAdmin =
        ref.watch(sessionProvider)?.user.role == RoleLogistique.administrateur;

    final tries = [...demandes]
      ..sort((a, b) {
        final ad = a.statut == StatutDemandeReparation.demandee;
        final bd = b.statut == StatutDemandeReparation.demandee;
        if (ad != bd) return ad ? -1 : 1;
        return b.dateDemande.compareTo(a.dateDemande);
      });

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!charge)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (tries.isEmpty)
            const EmptyState(
              message:
                  'Aucune demande de mise en réparation. Elles se créent '
                  'depuis la fiche d\'un véhicule, au vu de ses pannes.',
              icon: Icons.build_outlined,
            )
          else
            for (final d in tries)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _CarteDemande(
                  demande: d,
                  vehicule: parId[d.vehiculeId],
                  pannes: pannes.where((p) => p.demandeId == d.id).toList(),
                  estAdmin: estAdmin,
                ),
              ),
        ],
      ),
    );
  }
}

class _CarteDemande extends ConsumerWidget {
  const _CarteDemande({
    required this.demande,
    required this.vehicule,
    required this.pannes,
    required this.estAdmin,
  });

  final DemandeReparation demande;
  final Vehicule? vehicule;
  final List<Panne> pannes;
  final bool estAdmin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jour = DateFormat('dd/MM/yyyy');
    final v = vehicule;
    final titre = v == null
        ? 'Véhicule retiré du parc'
        : '${v.marque} ${v.modele} — ${v.immatriculation}';
    final enAttente = demande.statut == StatutDemandeReparation.demandee;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    titre,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _PastilleStatut(statut: demande.statut),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Demandée le ${jour.format(demande.dateDemande)}',
              style: const TextStyle(fontSize: 12, color: AppColors.inkMuted),
            ),
            const SizedBox(height: 10),
            if (pannes.isEmpty)
              const Text(
                'Aucune panne rattachée.',
                style: TextStyle(fontSize: 13, color: AppColors.inkMuted),
              )
            else
              for (final p in pannes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '•  [${p.gravite.label}] ${p.description}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
            if (demande.commentaire != null &&
                demande.commentaire!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Observations : ${demande.commentaire}',
                style: const TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            if (enAttente && estAdmin) ...[
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => _refuser(context, ref),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(color: AppColors.danger),
                    ),
                    child: const Text('Refuser'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: () => _valider(context, ref),
                    child: const Text('Valider la mise en réparation'),
                  ),
                ],
              ),
            ],
            if (enAttente && !estAdmin)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'En attente de la validation de l\'administrateur.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.inkMuted,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _valider(BuildContext context, WidgetRef ref) async {
    final user = ref.read(sessionProvider)!.user;
    // La réparation reprend les pannes et l'observation de la demande.
    final texte = [
      for (final p in pannes) '[${p.gravite.label}] ${p.description}',
      if (demande.commentaire != null && demande.commentaire!.trim().isNotEmpty)
        'Observations : ${demande.commentaire!.trim()}',
    ].join('\n');

    try {
      await ref
          .read(demandesReparationProvider.notifier)
          .valider(demande, validateurId: user.id, pannesTexte: texte);
      if (context.mounted) {
        showSuccessSnackBar(
          context,
          'Demande validée — véhicule mis en réparation.',
        );
      }
    } catch (e) {
      if (context.mounted) showErrorSnackBar(context, e);
    }
  }

  Future<void> _refuser(BuildContext context, WidgetRef ref) async {
    final user = ref.read(sessionProvider)!.user;
    try {
      await ref
          .read(demandesReparationProvider.notifier)
          .refuser(demande, validateurId: user.id);
      if (context.mounted) {
        showSuccessSnackBar(context, 'Demande refusée.');
      }
    } catch (e) {
      if (context.mounted) showErrorSnackBar(context, e);
    }
  }
}

class _PastilleStatut extends StatelessWidget {
  const _PastilleStatut({required this.statut});

  final StatutDemandeReparation statut;

  @override
  Widget build(BuildContext context) {
    final couleur = switch (statut) {
      StatutDemandeReparation.demandee => AppColors.warning,
      StatutDemandeReparation.validee => AppColors.success,
      StatutDemandeReparation.refusee => AppColors.inkMuted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        statut.label,
        style: TextStyle(
          color: couleur,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}
