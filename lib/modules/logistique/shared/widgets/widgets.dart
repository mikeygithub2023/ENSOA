import 'package:flutter/material.dart';

import 'package:sig_ensoa/core/erreurs.dart';
import 'package:sig_ensoa/core/theme.dart';

/// Notification de confirmation après un enregistrement réussi (créer,
/// modifier, clôturer...) — cohérente sur tout l'app. À appeler avec le
/// [context] du formulaire, avant ou juste après avoir fermé le dialogue
/// (ScaffoldMessenger remonte jusqu'au Scaffold racine, donc ça reste valide
/// même une fois le dialogue fermé).
void showSuccessSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
      backgroundColor: AppColors.success,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    ),
  );
}

/// Le pendant de [showSuccessSnackBar] : ce qui n'a pas abouti.
///
/// Deux échecs très différents se ressemblaient jusqu'ici — « Erreur
/// Supabase : ClientException... » disait la même chose pour une coupure de
/// réseau et pour un refus du serveur. Le premier n'est pas une faute de
/// l'agent et ne demande rien : il passe en message furtif, sans détail
/// technique. Le second nomme ce que le serveur a refusé, et reste affiché
/// plus longtemps parce qu'il y a quelque chose à corriger.
void showErrorSnackBar(BuildContext context, Object erreur, {String? action}) {
  final reseau = estProblemeReseau(erreur);
  final texte = reseau
      ? 'Serveur injoignable. Vérifiez la connexion, puis réessayez.'
      : action == null
      ? messageErreur(erreur)
      : '$action : ${messageErreur(erreur)}';

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(
            reseau ? Icons.cloud_off_rounded : Icons.error_outline_rounded,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(texte)),
        ],
      ),
      backgroundColor: reseau ? AppColors.inkMuted : AppColors.danger,
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: reseau ? 4 : 6),
    ),
  );
}

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final Widget? iconWidget;
  final Color? color;
  final String? sublabel;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.iconWidget,
    this.color,
    this.sublabel,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.blueDeep;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: c.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: iconWidget ?? Icon(icon, color: c, size: 22),
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: AppColors.inkMuted, fontSize: 13),
            ),
            if (sublabel != null) ...[
              const SizedBox(height: 2),
              Text(
                sublabel!,
                style: TextStyle(
                  color: c,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? action;
  const SectionHeader({super.key, required this.title, this.action});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ConstrainedBox(
        // La hauteur d'un bouton du thème (20 de texte + 2 × 16 de marge).
        //
        // Sans ce plancher, la ligne de titre se règle sur son contenu : haute
        // quand la rubrique porte une action, basse quand elle n'en porte pas.
        // Tout ce qui suit sautait alors au changement d'onglet.
        constraints: const BoxConstraints(minHeight: 52),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            ?action,
          ],
        ),
      ),
    );
  }
}

/// Puce de filtre — volontairement distincte des cartes de contenu (fond
/// blanc + bordure à l'état inactif, plein bleu marine à l'état actif) pour
/// que la ligne de filtres ne se confonde pas avec la liste en dessous.
class FilterChipPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const FilterChipPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

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
          border: selected ? null : Border.all(color: const Color(0xFFDCE3F0)),
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

class StatusChip extends StatelessWidget {
  final String label;
  final AlertLevel level;
  const StatusChip({
    super.key,
    required this.label,
    this.level = AlertLevel.info,
  });

  @override
  Widget build(BuildContext context) {
    final c = level.color(context);
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

class AlertTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final AlertLevel level;
  final VoidCallback? onTap;

  const AlertTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.level = AlertLevel.warning,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = level.color(context);
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      leading: CircleAvatar(
        backgroundColor: c.withValues(alpha: 0.12),
        child: Icon(icon, color: c, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
    );
  }
}

class EmptyState extends StatelessWidget {
  final String message;
  final IconData icon;
  const EmptyState({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 40, color: AppColors.inkMuted),
            const SizedBox(height: 12),
            const Text('', style: TextStyle(height: 0)),
            Text(message, style: const TextStyle(color: AppColors.inkMuted)),
          ],
        ),
      ),
    );
  }
}

/// Contenu d'une page — s'insère directement dans la grande carte fournie par
/// [AppShell] (qui gère déjà l'arrondi/fond/en-tête). Ne crée plus son propre
/// Scaffold : juste un titre de page + un contenu défilant.
class ScreenScaffold extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Widget? floatingActionButton;

  const ScreenScaffold({
    super.key,
    required this.title,
    required this.children,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 20),
              ...children,
            ],
          ),
        ),
        if (floatingActionButton != null)
          Positioned(right: 4, bottom: 12, child: floatingActionButton!),
      ],
    );
  }
}
