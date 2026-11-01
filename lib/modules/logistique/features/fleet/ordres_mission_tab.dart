import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:sig_ensoa/core/chargement.dart';
import 'package:sig_ensoa/core/theme.dart';
import '../../data/models/mouvement_vehicule.dart';
import '../../data/models/vehicule.dart';
import '../../data/repositories/fleet_providers.dart';
import '../../shared/widgets/widgets.dart';
import 'mouvement_form_dialog.dart';

/// L'onglet des ordres de mission.
///
/// C'est ce que le reste du code nomme encore « mouvement » : le déplacement
/// autorisé d'un véhicule. On ne les voyait qu'un à un, depuis la fiche d'un
/// véhicule ; ici ils se tiennent tous ensemble, les missions en cours en
/// tête. On en ouvre une nouvelle en choisissant d'abord le véhicule — seuls
/// les disponibles peuvent partir. Créer un ordre met le véhicule « En
/// mission » ; sa clôture (kilométrage de retour) revient au poste de police.
class OrdresMissionTab extends ConsumerWidget {
  const OrdresMissionTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final charge = estCharge(ref, ['vehicules', 'mouvements']);
    final mouvements = ref.watch(mouvementsVehiculeProvider);
    final vehicules = ref.watch(vehiculesProvider);
    final parId = {for (final v in vehicules) v.id: v};

    // Les missions en cours passent devant ; au sein de chaque groupe, la plus
    // récente d'abord.
    final tries = [...mouvements]..sort((a, b) {
      final ac = a.etat == EtatMouvement.enCours;
      final bc = b.etat == EtatMouvement.enCours;
      if (ac != bc) return ac ? -1 : 1;
      return b.dateDepart.compareTo(a.dateDepart);
    });

    final enCours = tries.where((m) => m.etat == EtatMouvement.enCours).length;

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (charge && tries.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    enCours == 0
                        ? '${tries.length} ordre(s) de mission'
                        : '$enCours en cours — ${tries.length} au total',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.inkMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              if (!charge)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (tries.isEmpty)
                const EmptyState(
                  message: 'Aucun ordre de mission. Appuyez sur « Nouvel ordre '
                      'de mission » pour en créer un.',
                  icon: Icons.assignment_outlined,
                )
              else
                for (final m in tries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _CarteOrdreMission(
                      mouvement: m,
                      vehicule: parId[m.vehiculeId],
                    ),
                  ),
            ],
          ),
        ),
        Positioned(
          right: 4,
          bottom: 12,
          child: FloatingActionButton.extended(
            onPressed: () => _nouvelOrdre(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Nouvel ordre de mission'),
          ),
        ),
      ],
    );
  }

  /// Ouvre un ordre de mission : on choisit d'abord le véhicule — un seul
  /// disponible peut partir —, puis on remplit la mission.
  Future<void> _nouvelOrdre(BuildContext context, WidgetRef ref) async {
    final disponibles = ref
        .read(vehiculesProvider)
        .where((v) => v.etat == EtatVehicule.disponible)
        .toList();

    if (disponibles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucun véhicule disponible pour une mission.'),
        ),
      );
      return;
    }

    final vehicule = await showDialog<Vehicule>(
      context: context,
      builder: (_) => _SelecteurVehicule(vehicules: disponibles),
    );
    if (vehicule == null || !context.mounted) return;

    await showDialog(
      context: context,
      builder: (_) => MouvementFormDialog(vehicule: vehicule),
    );
  }
}

/// Une carte d'ordre de mission : le véhicule, son état, et le détail de la
/// mission. On peut la corriger ou la supprimer — supprimer un ordre en cours
/// rend le véhicule à sa disponibilité.
class _CarteOrdreMission extends ConsumerWidget {
  const _CarteOrdreMission({required this.mouvement, this.vehicule});

  final MouvementVehicule mouvement;
  final Vehicule? vehicule;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final depart = DateFormat('dd/MM/yyyy à HH:mm', 'fr_FR');
    final v = vehicule;
    final titre = v == null
        ? 'Véhicule retiré du parc'
        : '${v.marque} ${v.modele} — ${v.immatriculation}';

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
                _PastilleStatut(etat: mouvement.etat),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  tooltip: 'Actions',
                  onSelected: (choix) {
                    if (choix == 'modifier') _modifier(context);
                    if (choix == 'supprimer') _supprimer(context, ref);
                  },
                  itemBuilder: (_) => [
                    if (v != null)
                      const PopupMenuItem(
                        value: 'modifier',
                        child: Text('Modifier'),
                      ),
                    const PopupMenuItem(
                      value: 'supprimer',
                      child: Text('Supprimer'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            _Ligne(
              icone: Icons.flag_outlined,
              texte: mouvement.objet,
            ),
            _Ligne(
              icone: Icons.place_outlined,
              texte: 'Destination : ${mouvement.destination}',
            ),
            _Ligne(
              icone: Icons.person_outline,
              texte:
                  'Conducteur : ${mouvement.gradeChefBord} ${mouvement.nomChefBord}'
                  .trim(),
            ),
            if (mouvement.nomChefDeBord.isNotEmpty)
              _Ligne(
                icone: Icons.military_tech_outlined,
                texte:
                    'Chef de bord : ${mouvement.gradeChefDeBord} ${mouvement.nomChefDeBord}'
                    .trim(),
              ),
            _Ligne(
              icone: Icons.schedule_rounded,
              texte: 'Départ : ${depart.format(mouvement.dateDepart)}',
            ),
            _Ligne(
              icone: Icons.speed_rounded,
              texte: mouvement.kmArrivee == null
                  ? 'Km départ : ${mouvement.kmDepart}'
                  : 'Km : ${mouvement.kmDepart} → ${mouvement.kmArrivee}',
            ),
            if (mouvement.dateFin != null)
              _Ligne(
                icone: Icons.flag_circle_outlined,
                texte: 'Retour : ${depart.format(mouvement.dateFin!)}',
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _modifier(BuildContext context) async {
    final v = vehicule;
    if (v == null) return;
    await showDialog(
      context: context,
      builder: (_) => MouvementFormDialog(vehicule: v, mouvement: mouvement),
    );
  }

  Future<void> _supprimer(BuildContext context, WidgetRef ref) async {
    final enCours = mouvement.etat == EtatMouvement.enCours;
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer l\'ordre de mission'),
        content: Text(
          enCours
              ? 'Cet ordre est en cours : le supprimer rendra le véhicule '
                    'disponible.'
              : 'Cet ordre de mission sera supprimé.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirme != true) return;

    try {
      // Un ordre en cours tient le véhicule « En mission » : en le supprimant,
      // on le rend à sa disponibilité, sans quoi il resterait immobilisé sans
      // mission pour le justifier.
      final v = vehicule;
      if (enCours && v != null) {
        await ref
            .read(vehiculesProvider.notifier)
            .updateEtat(v.id, EtatVehicule.disponible);
      }
      await ref.read(mouvementsVehiculeProvider.notifier).supprimer(mouvement.id);
      if (context.mounted) {
        showSuccessSnackBar(context, 'Ordre de mission supprimé.');
      }
    } catch (e) {
      if (context.mounted) showErrorSnackBar(context, e);
    }
  }
}

class _Ligne extends StatelessWidget {
  const _Ligne({required this.icone, required this.texte});

  final IconData icone;
  final String texte;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 16, color: AppColors.inkMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(texte, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

/// La pastille d'état, aux couleurs de l'application : en cours (bleu),
/// clôturé (vert), annulé (gris).
class _PastilleStatut extends StatelessWidget {
  const _PastilleStatut({required this.etat});

  final EtatMouvement etat;

  @override
  Widget build(BuildContext context) {
    final (libelle, couleur) = switch (etat) {
      EtatMouvement.enCours => ('En cours', AppColors.blue),
      EtatMouvement.termine => ('Clôturé', AppColors.success),
      EtatMouvement.annule => ('Annulé', AppColors.inkMuted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        libelle,
        style: TextStyle(
          color: couleur,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

/// Le choix du véhicule à l'ouverture d'un ordre de mission : seuls les
/// disponibles sont proposés — un véhicule en mission, en réparation ou hors
/// service ne part pas.
class _SelecteurVehicule extends StatelessWidget {
  const _SelecteurVehicule({required this.vehicules});

  final List<Vehicule> vehicules;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Choisir le véhicule'),
      content: SizedBox(
        width: 420,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: vehicules.length,
          itemBuilder: (context, i) {
            final v = vehicules[i];
            return ListTile(
              leading: const Icon(Icons.directions_car_rounded),
              title: Text('${v.marque} ${v.modele}'),
              subtitle: Text('${v.immatriculation} — ${v.kilometrage} km'),
              onTap: () => Navigator.of(context).pop(v),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
      ],
    );
  }
}
