import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sig_ensoa/core/roles.dart';
import 'package:sig_ensoa/modules/logistique/compat.dart';
import 'package:sig_ensoa/core/theme.dart';
import 'package:sig_ensoa/core/chargement.dart';
import 'package:sig_ensoa/core/format.dart';
import '../../data/models/carburant.dart';
import '../../data/repositories/fuel_providers.dart';
import '../../shared/widgets/skeleton.dart';
import '../../shared/widgets/widgets.dart';
import 'soute_form_dialog.dart';

/// Contenu de l'onglet "Soute" — grille des soutes avec, pour chacune, le
/// détail de ses répartitions (soute = somme de ses répartitions).
class SoutesTabContent extends ConsumerWidget {
  const SoutesTabContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final charge = estCharge(ref, ['soutes', 'soute_stocks']);
    final soutesRegroupees = ref.watch(soutesRegroupeesProvider);
    // L'administrateur de l'école a la même main que le chef du service
    // depuis la migration qui lui a ouvert l'écriture : il doit voir les
    // mêmes boutons, sans quoi il a le droit sans le moyen.
    final role = ref.watch(sessionProvider)?.user.role;
    final estChef =
        role == RoleLogistique.chefSoutienTechnique ||
        role == RoleLogistique.administrateur;

    if (!charge) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(4, 4, 4, 100),
        child: SkeletonGrid(
          itemCount: 4,
          maxCrossAxisExtent: 360,
          mainAxisExtent: 270,
        ),
      );
    }

    // Hors de la grille : logé dedans, le message tenait dans une case de
    // 360 × 270 en haut à gauche, comme une soute fantôme. Il occupe
    // maintenant la largeur de l'écran, centré.
    if (soutesRegroupees.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(4, 4, 4, 100),
        child: EmptyState(
          message: 'Aucune soute enregistrée',
          icon: Icons.local_gas_station_outlined,
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 100),
      itemCount: soutesRegroupees.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 360,
        mainAxisExtent: 270,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemBuilder: (context, i) {
        final s = soutesRegroupees[i];
        final enAlerte = s.repartitions.any((r) => r.seuilAtteint);
        final color = enAlerte ? AppColors.danger : AppColors.ivoryOrange;
        final taux = s.seuilNominalTotal == 0
            ? 0.0
            : (s.quantiteTotale / s.seuilNominalTotal).clamp(0, 1).toDouble();
        return Card(
          // Clé d'identité : sans elle, Flutter réassocie les états par
          // position, et le sablier d'une soute supprimée retomberait sur
          // celle qui prend sa place.
          key: ValueKey(s.soute.id),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        s.soute.libelle,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${formatMilliers(s.quantiteTotale)} L',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    if (estChef)
                      _MenuSoute(
                        soute: s.soute,
                        quantiteRestante: s.quantiteTotale,
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: taux,
                    minHeight: 8,
                    backgroundColor: color.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: s.repartitions.isEmpty
                      ? const Text(
                          'Aucune répartition',
                          style: TextStyle(
                            color: AppColors.inkMuted,
                            fontSize: 12,
                          ),
                        )
                      : ListView(
                          padding: EdgeInsets.zero,
                          children: [
                            for (final r in s.repartitions)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 3,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            r.repartitionLibelle,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.ink,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            _detailGasoilSuper(
                                              r.qteGasoil,
                                              r.qteSuper,
                                            ),
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.inkMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '${formatMilliers(r.quantiteTotale)} L',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    if (r.seuilAtteint) ...[
                                      const SizedBox(width: 6),
                                      const Icon(
                                        Icons.warning_amber_rounded,
                                        size: 14,
                                        color: AppColors.danger,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Modifier ou supprimer une soute, depuis sa propre carte.
///
/// Un menu plutôt que deux boutons : la carte est déjà dense, et ces deux
/// gestes sont rares au regard de la consultation quotidienne.
class _MenuSoute extends ConsumerStatefulWidget {
  const _MenuSoute({required this.soute, required this.quantiteRestante});

  final Soute soute;

  /// Sert à avertir avant de retirer une soute qui contient encore du
  /// carburant : ce volume disparaîtrait des totaux sans être distribué.
  final int quantiteRestante;

  @override
  ConsumerState<_MenuSoute> createState() => _MenuSouteState();
}

class _MenuSouteState extends ConsumerState<_MenuSoute> {
  bool _envoi = false;

  Future<void> _confirmerSuppression() async {
    final reste = widget.quantiteRestante;
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Supprimer la soute'),
        content: Text(
          reste > 0
              ? '${widget.soute.libelle} contient encore '
                    '${formatMilliers(reste)} L. La retirer fera sortir ce volume '
                    'des totaux sans qu\'il ait été distribué : videz-la d\'abord '
                    'si le carburant est réellement là.\n\n'
                    'Son historique (dépotages, distributions) reste conservé.'
              : '${widget.soute.libelle} sera retirée des soutes actives. '
                    'Son historique (dépotages, distributions) reste conservé.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: reste > 0
                ? FilledButton.styleFrom(backgroundColor: AppColors.danger)
                : null,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirme != true || !mounted) return;

    setState(() => _envoi = true);
    try {
      await ref.read(soutesProvider.notifier).supprimer(widget.soute.id);
      if (mounted) showSuccessSnackBar(context, 'Soute supprimée avec succès.');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur Supabase : $e')));
      }
    } finally {
      // Remis à zéro même après un succès : si l'état venait à être réutilisé
      // pour une autre carte, il ne doit pas lui transmettre ce sablier.
      if (mounted) setState(() => _envoi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_envoi) {
      return const Padding(
        padding: EdgeInsets.only(left: 8),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return PopupMenuButton<String>(
      tooltip: 'Modifier ou supprimer',
      padding: EdgeInsets.zero,
      icon: const Icon(Icons.more_vert, size: 20, color: AppColors.inkMuted),
      onSelected: (choix) {
        if (choix == 'modifier') {
          showDialog(
            context: context,
            builder: (_) => SouteFormDialog(soute: widget.soute),
          );
        } else {
          _confirmerSuppression();
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 'modifier',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.edit_outlined, size: 20),
            title: Text('Modifier'),
          ),
        ),
        PopupMenuItem(
          value: 'supprimer',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.delete_outline,
              size: 20,
              color: AppColors.danger,
            ),
            title: Text('Supprimer', style: TextStyle(color: AppColors.danger)),
          ),
        ),
      ],
    );
  }
}

/// "1000 L Gasoil + 1500 L Super" — n'affiche que les types réellement présents.
String _detailGasoilSuper(int qteGasoil, int qteSuper) {
  final parts = [
    if (qteGasoil > 0) '${formatMilliers(qteGasoil)} L Gasoil',
    if (qteSuper > 0) '${formatMilliers(qteSuper)} L Super',
  ];
  return parts.isEmpty ? '—' : parts.join(' + ');
}
