import 'package:flutter/material.dart';

import 'package:sig_ensoa/core/theme.dart' hide AlertLevel, AlertLevelColor;

enum AlertLevel { info, warning, critical, success }

extension AlertLevelColor on AlertLevel {
  Color get color => switch (this) {
    AlertLevel.info => AppColors.blue,
    AlertLevel.warning => AppColors.warning,
    AlertLevel.critical => AppColors.danger,
    AlertLevel.success => AppColors.success,
  };
}

/// Titre de section — même style que le template ERP Flutter.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      // La hauteur d'un bouton du thème (20 de texte + 2 × 16 de marge).
      //
      // Sans ce plancher, la ligne de titre se règle sur son contenu : haute
      // quand l'onglet porte des actions, basse quand il n'en porte pas. Tout
      // ce qui suit — onglets, listes — sautait alors d'une vingtaine de
      // pixels au changement d'onglet.
      constraints: const BoxConstraints(minHeight: 52),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

/// Badge de statut coloré en pilule (fond teinté 12%, texte plein).
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    this.level = AlertLevel.info,
  });

  final String label;
  final AlertLevel level;

  @override
  Widget build(BuildContext context) {
    final c = level.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        label,
        style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Puce de filtre sélectionnable, en pilule.
class FilterChipPill extends StatelessWidget {
  const FilterChipPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.navy : AppColors.cardBg,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: selected ? null : Border.all(color: AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.ink,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

/// État vide — remplace les "Aucune donnée" épars.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
  });

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: AppColors.inkMuted),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(color: AppColors.inkMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
