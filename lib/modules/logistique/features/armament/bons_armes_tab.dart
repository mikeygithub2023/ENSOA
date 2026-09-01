import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:sig_ensoa/modules/logistique/compat.dart';
import 'package:sig_ensoa/core/theme.dart';
import 'package:sig_ensoa/core/chargement.dart';
import '../../data/models/armement.dart';
import '../../data/repositories/armament_providers.dart';
import '../../data/repositories/misc_providers.dart';
import '../../shared/widgets/skeleton.dart';
import '../../shared/widgets/widgets.dart';

/// Contenu de l'onglet "Bons" — journal de toutes les remises (bons de
/// sortie) et de tous les retours (bons d'entrée) d'armes, tous armements
/// confondus. Complète la fiche par-arme avec une vue transverse.
class BonsArmesTabContent extends ConsumerStatefulWidget {
  const BonsArmesTabContent({super.key});

  @override
  ConsumerState<BonsArmesTabContent> createState() =>
      _BonsArmesTabContentState();
}

enum _FiltreBon { tous, enCours, clotures }

class _BonsArmesTabContentState extends ConsumerState<BonsArmesTabContent> {
  _FiltreBon _filtre = _FiltreBon.tous;
  final Set<String> _retoursEnCours = {};
  final _rechercheCtrl = TextEditingController();
  String _recherche = '';

  @override
  void dispose() {
    _rechercheCtrl.dispose();
    super.dispose();
  }

  Future<void> _enregistrerRetour(DotationArme d, Arme arme) async {
    setState(() => _retoursEnCours.add(d.id));
    final user = ref.read(sessionProvider)?.user;
    try {
      await ref
          .read(dotationsProvider.notifier)
          .enregistrerRetour(d.id, arme.id);
      if (user != null) {
        ref
            .read(auditProvider.notifier)
            .log(
              auteurId: user.id,
              action: 'ARME_RETOURNEE',
              cible: arme.numeroSerie,
              detail: 'Retour de ${d.beneficiaireId}',
            );
      }
      if (mounted) showSuccessSnackBar(context, 'Arme réintégrée avec succès.');
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, e);
      }
    } finally {
      if (mounted) setState(() => _retoursEnCours.remove(d.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final charge = estCharge(ref, ['armes', 'dotations_armes']);
    final armes = ref.watch(armesProvider);
    final dotations = List.of(ref.watch(dotationsProvider))
      ..sort((a, b) => b.dateRemise.compareTo(a.dateRemise));
    final df = DateFormat('dd/MM/yyyy HH:mm');

    if (!charge) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(4, 4, 4, 100),
        child: SkeletonList(itemCount: 4),
      );
    }

    Arme? armeDe(DotationArme d) {
      for (final a in armes) {
        if (a.id == d.armeId) return a;
      }
      return null;
    }

    final recherche = _recherche.trim().toLowerCase();
    final filtrees = dotations.where((d) {
      final passeFiltre = switch (_filtre) {
        _FiltreBon.tous => true,
        _FiltreBon.enCours => d.enCours,
        _FiltreBon.clotures => !d.enCours,
      };
      if (!passeFiltre) return false;
      if (recherche.isEmpty) return true;
      final a = armeDe(d);
      final texte = [
        a?.numeroSerie,
        a?.type,
        a?.modele,
        d.beneficiaireId,
        d.beneficiaireNom,
      ].whereType<String>().join(' ').toLowerCase();
      return texte.contains(recherche);
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 100),
      children: [
        TextField(
          controller: _rechercheCtrl,
          decoration: InputDecoration(
            hintText:
                'Rechercher une arme (N° série, type, modèle) ou un bénéficiaire...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _recherche.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() {
                      _rechercheCtrl.clear();
                      _recherche = '';
                    }),
                  ),
          ),
          onChanged: (v) => setState(() => _recherche = v),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            FilterChipPill(
              label: 'Tous',
              selected: _filtre == _FiltreBon.tous,
              onTap: () => setState(() => _filtre = _FiltreBon.tous),
            ),
            FilterChipPill(
              label: 'Sorties en cours',
              selected: _filtre == _FiltreBon.enCours,
              onTap: () => setState(() => _filtre = _FiltreBon.enCours),
            ),
            FilterChipPill(
              label: 'Entrées clôturées',
              selected: _filtre == _FiltreBon.clotures,
              onTap: () => setState(() => _filtre = _FiltreBon.clotures),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SectionHeader(title: 'Bons (${filtrees.length})'),
        if (filtrees.isEmpty)
          const EmptyState(message: 'Aucun bon pour ce filtre'),
        for (final d in filtrees) ...[
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor:
                    (d.enCours ? AppColors.ivoryOrange : AppColors.success)
                        .withValues(alpha: 0.12),
                child: Icon(
                  d.enCours ? Icons.arrow_upward : Icons.arrow_downward,
                  color: d.enCours ? AppColors.ivoryOrange : AppColors.success,
                ),
              ),
              title: Text(
                armeDe(d) != null
                    ? '${armeDe(d)!.type} — ${armeDe(d)!.modele} (N° ${armeDe(d)!.numeroSerie})'
                    : 'Arme inconnue',
              ),
              subtitle: Text(
                'Bénéficiaire ${d.beneficiaireNom.isEmpty ? d.beneficiaireId : '${d.beneficiaireNom} (${d.beneficiaireId})'} · Sortie le ${df.format(d.dateRemise)}'
                '${d.dateRetourEffective != null ? ' · Entrée le ${df.format(d.dateRetourEffective!)}' : ''}'
                '${d.motif != null ? ' · ${d.motif}' : ''}',
              ),
              isThreeLine: true,
              trailing: d.enCours
                  ? OutlinedButton(
                      onPressed:
                          _retoursEnCours.contains(d.id) || armeDe(d) == null
                          ? null
                          : () => _enregistrerRetour(d, armeDe(d)!),
                      child: _retoursEnCours.contains(d.id)
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Réintégrer'),
                    )
                  : StatusChip(label: 'Clôturé', level: AlertLevel.info),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}
