import 'package:flutter/material.dart';

import '../../models/classe.dart';
import '../../models/promotion.dart';
import 'common.dart';

/// Ce qu'on a retenu sur la ligne « promotions / stages » : une promotion,
/// un stage, ou rien — auquel cas la division entière est dans la portée.
///
/// Les deux ne peuvent pas être retenus ensemble : une promotion groupe des
/// phases, un stage n'en a pas, et ils ne se croisent jamais.
class ChoixScolarite {
  const ChoixScolarite({this.promotionId, this.stageId});

  const ChoixScolarite.tout() : promotionId = null, stageId = null;
  const ChoixScolarite.promotion(String id) : promotionId = id, stageId = null;
  const ChoixScolarite.stage(String id) : promotionId = null, stageId = id;

  final String? promotionId;
  final String? stageId;

  bool get estTout => promotionId == null && stageId == null;
}

/// Les promotions et les stages d'une division, sur une même ligne.
///
/// La Division de Formation des Spécialistes a les deux : ses promotions
/// mènent à des phases, ses stages se suffisent à eux-mêmes. Les ranger sur
/// deux lignes séparées laissait croire à une hiérarchie entre eux qui
/// n'existe pas — ils sont côte à côte, au même niveau sous la division.
/// Les divisions qui n'ont que l'un ou l'autre affichent simplement moins
/// de puces.
class PromotionsEtStagesFilters extends StatelessWidget {
  const PromotionsEtStagesFilters({
    super.key,
    required this.promotions,
    required this.stages,
    required this.choix,
    required this.onChoix,
    this.avecToutes = true,
  });

  final List<Promotion> promotions;
  final List<Classe> stages;
  final ChoixScolarite choix;
  final ValueChanged<ChoixScolarite> onChoix;

  /// La puce « tout » n'a de sens que là où la division entière est une
  /// portée valable. On n'imprime pas le bulletin de « toutes les
  /// promotions » : il faut en désigner une.
  final bool avecToutes;

  /// L'intitulé de la puce « tout » se règle sur ce que la division
  /// contient réellement : annoncer des stages là où il n'y en a pas
  /// laisserait croire qu'il en manque.
  String get _labelTout {
    if (promotions.isEmpty) return 'Tous les stages';
    if (stages.isEmpty) return 'Toutes les promotions';
    return 'Toutes les promotions / stages';
  }

  @override
  Widget build(BuildContext context) {
    if (promotions.isEmpty && stages.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (avecToutes)
          FilterChipPill(
            label: _labelTout,
            selected: choix.estTout,
            onTap: () => onChoix(const ChoixScolarite.tout()),
          ),
        for (final promotion in promotions)
          FilterChipPill(
            label: promotion.intitule,
            selected: choix.promotionId == promotion.id,
            onTap: () => onChoix(ChoixScolarite.promotion(promotion.id)),
          ),
        for (final stage in stages)
          FilterChipPill(
            label: '${stage.nom} (stage)',
            selected: choix.stageId == stage.id,
            onTap: () => onChoix(ChoixScolarite.stage(stage.id)),
          ),
      ],
    );
  }
}
