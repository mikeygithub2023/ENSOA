import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:sig_ensoa/core/theme.dart';
import 'package:sig_ensoa/core/chargement.dart';
import 'package:sig_ensoa/core/format.dart';
import '../../data/models/armement.dart';
import '../../data/repositories/armament_providers.dart';
import '../../shared/widgets/skeleton.dart';
import '../../shared/widgets/widgets.dart';

/// Sous-rubrique « Bons » des munitions et des équipements — le journal des
/// entrées et des sorties.
///
/// Un seul widget pour les deux familles : la colonne qui change est le nom
/// de l'article, tout le reste est identique. Les écrire deux fois les
/// ferait diverger.
class BonsStockTabContent extends ConsumerStatefulWidget {
  const BonsStockTabContent({super.key, required this.famille});

  final FamilleArticle famille;

  @override
  ConsumerState<BonsStockTabContent> createState() =>
      _BonsStockTabContentState();
}

enum _FiltreSens { tous, sorties, entrees }

class _BonsStockTabContentState extends ConsumerState<BonsStockTabContent> {
  _FiltreSens _filtre = _FiltreSens.tous;
  final _rechercheCtrl = TextEditingController();
  String _recherche = '';

  @override
  void dispose() {
    _rechercheCtrl.dispose();
    super.dispose();
  }

  /// Le nom de l'article, retrouvé dans la liste du stock.
  ///
  /// Un article supprimé n'y figure plus, et son bon resterait anonyme :
  /// on le dit alors plutôt que d'afficher un vide.
  String _nomArticle(String id) {
    if (widget.famille == FamilleArticle.munition) {
      for (final m in ref.read(munitionsProvider)) {
        if (m.id == id) return 'Calibre ${m.calibre}';
      }
    } else {
      for (final e in ref.read(equipementsProvider)) {
        if (e.id == id) return e.libelle;
      }
    }
    return 'Article retiré du stock';
  }

  @override
  Widget build(BuildContext context) {
    final cle = widget.famille == FamilleArticle.munition
        ? 'munitions'
        : 'equipements';
    final charge = estCharge(ref, [cle, 'mouvements_articles']);
    final mouvements = ref.watch(
      mouvementsParFamilleProvider(widget.famille),
    );
    final df = DateFormat('dd/MM/yyyy HH:mm');

    if (!charge) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(4, 4, 4, 100),
        child: SkeletonList(itemCount: 4),
      );
    }

    final recherche = _recherche.trim().toLowerCase();
    final filtres = mouvements.where((m) {
      final passe = switch (_filtre) {
        _FiltreSens.tous => true,
        _FiltreSens.sorties => m.sens == SensMouvement.sortie,
        _FiltreSens.entrees => m.sens == SensMouvement.entree,
      };
      if (!passe) return false;
      if (recherche.isEmpty) return true;
      final texte = [
        _nomArticle(m.articleId),
        m.beneficiaire,
        m.motif ?? '',
      ].join(' ').toLowerCase();
      return texte.contains(recherche);
    }).toList();

    final sorties = filtres
        .where((m) => m.sens == SensMouvement.sortie)
        .fold<int>(0, (s, m) => s + m.quantite);
    final entrees = filtres
        .where((m) => m.sens == SensMouvement.entree)
        .fold<int>(0, (s, m) => s + m.quantite);

    return ListView(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 100),
      children: [
        TextField(
          controller: _rechercheCtrl,
          decoration: InputDecoration(
            hintText: widget.famille == FamilleArticle.munition
                ? 'Rechercher un calibre, un bénéficiaire, un motif...'
                : 'Rechercher un équipement, un bénéficiaire, un motif...',
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
              selected: _filtre == _FiltreSens.tous,
              onTap: () => setState(() => _filtre = _FiltreSens.tous),
            ),
            FilterChipPill(
              label: 'Bons de sortie',
              selected: _filtre == _FiltreSens.sorties,
              onTap: () => setState(() => _filtre = _FiltreSens.sorties),
            ),
            FilterChipPill(
              label: 'Bons d\'entrée',
              selected: _filtre == _FiltreSens.entrees,
              onTap: () => setState(() => _filtre = _FiltreSens.entrees),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SectionHeader(title: 'Bons (${filtres.length})'),
        if (filtres.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              '${formatMilliers(sorties)} sorti(s), '
              '${formatMilliers(entrees)} entré(s) sur ces bons.',
              style: const TextStyle(
                color: AppColors.inkMuted,
                fontSize: 13,
              ),
            ),
          ),
        if (filtres.isEmpty)
          const EmptyState(
            message: 'Aucun bon pour ce filtre',
            icon: Icons.receipt_long_outlined,
          ),
        for (final m in filtres) ...[
          Card(
            key: ValueKey(m.id),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor:
                    (m.sens == SensMouvement.sortie
                            ? AppColors.ivoryOrange
                            : AppColors.success)
                        .withValues(alpha: 0.12),
                child: Icon(
                  m.sens == SensMouvement.sortie
                      ? Icons.arrow_upward
                      : Icons.arrow_downward,
                  color: m.sens == SensMouvement.sortie
                      ? AppColors.ivoryOrange
                      : AppColors.success,
                ),
              ),
              title: Text(
                '${_nomArticle(m.articleId)} — '
                '${formatMilliers(m.quantite)}',
              ),
              subtitle: Text(
                'Bénéficiaire ${m.beneficiaire} · ${df.format(m.date)}'
                '${m.motif != null ? ' · ${m.motif}' : ''}',
              ),
              trailing: StatusChip(
                label: m.sens.label,
                level: m.sens == SensMouvement.sortie
                    ? AlertLevel.warning
                    : AlertLevel.info,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}
