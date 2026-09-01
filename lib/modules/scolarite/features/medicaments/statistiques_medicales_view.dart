import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:sig_ensoa/core/erreurs.dart';
import 'package:sig_ensoa/core/theme.dart' hide AlertLevel, AlertLevelColor;
import '../../models/medicament.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/graphe_barres.dart';
import '../../shared/widgets/ligne_cartes.dart';
import 'providers/medicaments_providers.dart';

final _dateFmt = DateFormat('dd/MM/yyyy');

/// Nombre de médicaments détaillés dans le second graphe. Au-delà, la queue
/// de distribution n'apprend plus rien et écrase visuellement les têtes.
const _maxMedicaments = 15;

/// Rubrique « Statistiques médicales » de la pharmacie : ce que les
/// apprenants ont réellement consommé pendant leur formation, par classe
/// pharmacologique puis médicament par médicament.
///
/// La consommation est lue dans le journal des mouvements de stock, limitée
/// aux sorties rattachées à une consultation : un réapprovisionnement ou une
/// correction d'inventaire n'est pas de la consommation. Les prescriptions
/// annulées sont déduites.
///
/// Les graphes ne servent pas à décorer : ils répondent à « de quoi la
/// troupe a-t-elle eu besoin ? », de quoi réorienter les objectifs de
/// formation et les commandes.
class StatistiquesMedicalesView extends ConsumerStatefulWidget {
  const StatistiquesMedicalesView({super.key});

  @override
  ConsumerState<StatistiquesMedicalesView> createState() =>
      _StatistiquesMedicalesViewState();
}

class _StatistiquesMedicalesViewState
    extends ConsumerState<StatistiquesMedicalesView> {
  late DateTime _debut;
  late DateTime _fin;

  @override
  void initState() {
    super.initState();
    // Douze mois glissants : une formation entière, saisons comprises.
    final now = DateTime.now();
    _fin = DateTime(now.year, now.month, now.day);
    _debut = DateTime(now.year - 1, now.month, now.day);
  }

  PeriodeConsommation get _periode => (debut: _debut, fin: _fin);

  Future<void> _choisirDate({required bool debut}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: debut ? _debut : _fin,
      firstDate: DateTime(now.year - 10),
      lastDate: now,
    );
    if (picked == null) return;
    setState(() {
      if (debut) {
        _debut = picked;
        if (_fin.isBefore(_debut)) _fin = _debut;
      } else {
        _fin = picked;
        if (_debut.isAfter(_fin)) _debut = _fin;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final consommationAsync = ref.watch(consommationProvider(_periode));
    final now = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: () => _choisirDate(debut: true),
              icon: const Icon(Icons.calendar_today_outlined, size: 16),
              label: Text('Du ${_dateFmt.format(_debut)}'),
            ),
            OutlinedButton.icon(
              onPressed: () => _choisirDate(debut: false),
              icon: const Icon(Icons.calendar_today_outlined, size: 16),
              label: Text('Au ${_dateFmt.format(_fin)}'),
            ),
            const SizedBox(width: 4),
            FilterChipPill(
              label: '12 derniers mois',
              selected:
                  _debut == DateTime(now.year - 1, now.month, now.day) &&
                  _fin == DateTime(now.year, now.month, now.day),
              onTap: () => setState(() {
                _debut = DateTime(now.year - 1, now.month, now.day);
                _fin = DateTime(now.year, now.month, now.day);
              }),
            ),
            FilterChipPill(
              label: 'Année ${now.year}',
              selected:
                  _debut == DateTime(now.year, 1, 1) &&
                  _fin == DateTime(now.year, 12, 31),
              onTap: () => setState(() {
                _debut = DateTime(now.year, 1, 1);
                _fin = DateTime(now.year, 12, 31);
              }),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: consommationAsync.when(
            data: (consommations) {
              if (consommations.isEmpty) {
                return const EmptyState(
                  message:
                      'Aucun médicament dispensé sur cette période.\n'
                      'La consommation se remplit à mesure que les '
                      'consultations donnent lieu à des prescriptions.',
                  icon: Icons.insights_outlined,
                );
              }
              return _Contenu(consommations: consommations);
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => EmptyState(
              message: 'Erreur de chargement : ${messageErreur(error)}',
              icon: Icons.error_outline,
            ),
          ),
        ),
      ],
    );
  }
}

class _Contenu extends StatelessWidget {
  const _Contenu({required this.consommations});

  final List<ConsommationMedicament> consommations;

  @override
  Widget build(BuildContext context) {
    final total = consommations.fold<int>(0, (s, c) => s + c.quantite);

    final parType = <TypeMedicament, int>{};
    for (final consommation in consommations) {
      parType[consommation.type] =
          (parType[consommation.type] ?? 0) + consommation.quantite;
    }
    final types = parType.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final tete = consommations.take(_maxMedicaments).toList();

    return ListView(
      children: [
        LigneCartes(
          cartes: [
            _Kpi(valeur: '$total', label: 'Unités dispensées', principal: true),
            _Kpi(
              valeur: '${consommations.length}',
              label: 'Médicaments différents',
            ),
            _Kpi(valeur: '${types.length}', label: 'Classes pharmacologiques'),
          ],
        ),
        const SizedBox(height: 24),
        GrapheBarres(
          titre: 'Consommation par classe pharmacologique',
          sousTitre:
              'Ce dont la troupe a eu besoin, par grande famille de soins.',
          couleur: AppColors.blueDeep,
          barres: [
            for (final entree in types)
              BarreDonnee(
                label: entree.key.label,
                valeur: entree.value,
                detail: _part(entree.value, total),
              ),
          ],
        ),
        const SizedBox(height: 24),
        GrapheBarres(
          titre: 'Consommation par médicament',
          sousTitre: consommations.length > _maxMedicaments
              ? 'Les $_maxMedicaments médicaments les plus dispensés sur '
                    '${consommations.length}.'
              : 'Tous les médicaments dispensés sur la période.',
          couleur: AppColors.blue,
          barres: [
            for (final consommation in tete)
              BarreDonnee(
                label: consommation.nom,
                valeur: consommation.quantite,
                detail: _part(consommation.quantite, total),
              ),
          ],
        ),
      ],
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({
    required this.valeur,
    required this.label,
    this.principal = false,
  });

  final String valeur;
  final String label;
  final bool principal;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: principal ? AppColors.navy : AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: principal ? null : Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            valeur,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: principal ? Colors.white : AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: principal ? AppColors.blueSoft : AppColors.inkMuted,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

/// Part d'une quantité dans le total dispensé, arrondie au point de
/// pourcentage.
String _part(int quantite, int total) {
  if (total == 0) return '0 %';
  return '${(quantite * 100 / total).round()} %';
}
