import 'package:flutter/material.dart';

import 'package:sig_ensoa/core/theme.dart' hide AlertLevel, AlertLevelColor;
import '../../models/apprenant.dart';
import '../../models/visite_medicale.dart';
import '../../shared/widgets/common.dart';

/// Détails de l'examen d'un apprenant lors d'une visite — lecture seule,
/// dans l'ordre du cachet apposé au dossier médical. Les rubriques non
/// renseignées affichent « — » plutôt que de disparaître, pour que le
/// médecin voie d'un coup d'œil ce qui reste à compléter.
Future<void> showVisiteApprenantDetailsDialog(
  BuildContext context, {
  required VisiteMedicaleApprenant examen,
  required Apprenant? apprenant,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.all(24),
      child: _VisiteApprenantDetails(examen: examen, apprenant: apprenant),
    ),
  );
}

class _VisiteApprenantDetails extends StatelessWidget {
  const _VisiteApprenantDetails({
    required this.examen,
    required this.apprenant,
  });

  final VisiteMedicaleApprenant examen;
  final Apprenant? apprenant;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final width = screenSize.width - 48 < 560 ? screenSize.width - 48 : 560.0;
    final level = switch (examen.resultat) {
      VisiteResultat.apte => AlertLevel.success,
      VisiteResultat.aRevoir => AlertLevel.info,
      VisiteResultat.inapteTemporaire => AlertLevel.warning,
      VisiteResultat.inapteDefinitif => AlertLevel.critical,
    };

    return SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    apprenant?.nomComplet ?? 'Apprenant inconnu',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                StatusChip(label: examen.resultat.label, level: level),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Titre('Mensurations'),
                  _Ligne('Taille', _mesure(examen.tailleCm, 'cm')),
                  _Ligne('Poids', _mesure(examen.poidsKg, 'kg')),
                  _Ligne('PTM', _mesure(examen.ptmCm, 'cm')),
                  _Ligne('PIGNET', _mesure(examen.pignet, '')),
                  const _Titre('Constantes'),
                  _Ligne('T.A', examen.tensionArterielle ?? '—'),
                  _Ligne('Pouls', _mesure(examen.pouls, 'bpm')),
                  const _Titre('Vision et audition'),
                  _Ligne('VOD', examen.vod ?? '—'),
                  _Ligne('VOG', examen.vog ?? '—'),
                  _Ligne('AOD', examen.aod ?? '—'),
                  _Ligne('AOG', examen.aog ?? '—'),
                  const _Titre('Urines'),
                  _Ligne('Sucre (S)', examen.urineSucre ?? '—'),
                  _Ligne('Albumine (A)', examen.urineAlbumine ?? '—'),
                  const _Titre('Clinique'),
                  Text(
                    examen.clinique ?? '—',
                    style: const TextStyle(fontSize: 13),
                  ),
                  const _Titre('SIGYCOP'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final lettre in SigycopLettre.values)
                        _SigycopPastille(
                          lettre: lettre,
                          cote: examen.sigycop[lettre],
                        ),
                    ],
                  ),
                  const _Titre('Observations'),
                  Text(
                    examen.observations ?? '—',
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _mesure(num? valeur, String unite) {
    if (valeur == null) return '—';
    return unite.isEmpty ? '$valeur' : '$valeur $unite';
  }
}

class _Titre extends StatelessWidget {
  const _Titre(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          color: AppColors.ink,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _Ligne extends StatelessWidget {
  const _Ligne(this.label, this.valeur);

  final String label;
  final String valeur;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.inkMuted, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              valeur,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _SigycopPastille extends StatelessWidget {
  const _SigycopPastille({required this.lettre, required this.cote});

  final SigycopLettre lettre;
  final int? cote;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: lettre.description,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.blueMist,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          '${lettre.lettre} ${cote ?? '—'}',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
      ),
    );
  }
}
