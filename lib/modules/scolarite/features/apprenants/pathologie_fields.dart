import 'package:flutter/material.dart';

import 'package:sig_ensoa/core/theme.dart' hide AlertLevel, AlertLevelColor;
import '../../models/consultation_medicale.dart';

/// Saisie de la pathologie constatée : le grand groupe clinique dans une
/// liste fermée, et le diagnostic précis en clair juste en dessous.
///
/// Le groupe rend le volet santé exploitable en statistiques ; le texte
/// libre porte ce que la liste ne saurait couvrir sans devenir une
/// nomenclature médicale. Le champ de précision n'apparaît qu'une fois un
/// groupe choisi — sans constat, il n'y a rien à préciser.
///
/// Commun à la clôture d'une consultation de routine et à l'enregistrement
/// d'une urgence : c'est le même constat dans les deux cas.
class PathologieFields extends StatelessWidget {
  const PathologieFields({
    super.key,
    required this.pathologie,
    required this.detailsController,
    required this.onChanged,
  });

  final Pathologie? pathologie;
  final TextEditingController detailsController;
  final ValueChanged<Pathologie?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<Pathologie>(
          initialValue: pathologie,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Pathologie constatée',
            suffixIcon: pathologie == null
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    tooltip: 'Effacer',
                    onPressed: () => onChanged(null),
                  ),
          ),
          items: [
            for (final p in Pathologie.values)
              DropdownMenuItem(value: p, child: Text(p.label)),
          ],
          onChanged: onChanged,
        ),
        if (pathologie != null) ...[
          const SizedBox(height: 12),
          TextField(
            controller: detailsController,
            decoration: const InputDecoration(
              labelText: 'Diagnostic précis (facultatif)',
              hintText: 'Ex. paludisme simple à P. falciparum',
            ),
            maxLines: 2,
          ),
        ],
        const SizedBox(height: 4),
        const Text(
          'Facultatif — à renseigner dès qu\'une pathologie est constatée.',
          style: TextStyle(color: AppColors.inkMuted, fontSize: 12),
        ),
      ],
    );
  }
}
