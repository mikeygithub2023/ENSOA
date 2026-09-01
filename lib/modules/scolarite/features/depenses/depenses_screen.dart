import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:sig_ensoa/core/erreurs.dart';
import 'package:sig_ensoa/core/theme.dart' hide AlertLevel, AlertLevelColor;
import '../../models/depense.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/ligne_cartes.dart';
import '../../shared/widgets/pdf_preview_dialog.dart';
import '../apprenants/pdf_fonts.dart';
import 'depenses_pdf.dart';
import 'providers/depenses_providers.dart';
import 'register_depense_dialog.dart';

final _dateFmt = DateFormat('dd/MM/yyyy');

/// Dépenses du volet médical : celles du service (besoins courants) et
/// celles engagées pour un patient à la suite d'une consultation. L'écran
/// travaille toujours sur une période — c'est elle qui définit ce qui est
/// listé, totalisé et imprimé.
class DepensesScreen extends ConsumerStatefulWidget {
  const DepensesScreen({super.key});

  @override
  ConsumerState<DepensesScreen> createState() => _DepensesScreenState();
}

class _DepensesScreenState extends ConsumerState<DepensesScreen> {
  late DateTime _debut;
  late DateTime _fin;
  TypeDepense? _filtre;
  bool _printing = false;

  @override
  void initState() {
    super.initState();
    // Le mois en cours : la maille sur laquelle un état de dépenses se
    // rend habituellement.
    final now = DateTime.now();
    _debut = DateTime(now.year, now.month, 1);
    _fin = DateTime(now.year, now.month + 1, 0);
  }

  PeriodeDepenses get _periode => (debut: _debut, fin: _fin);

  /// N'applique le filtre de nature qu'à l'affichage et à l'impression —
  /// les dépenses chargées restent celles de toute la période, pour que
  /// changer de filtre ne relance pas une requête.
  List<Depense> _filtrees(List<Depense> depenses) {
    if (_filtre == null) return depenses;
    return depenses.where((d) => d.type == _filtre).toList();
  }

  Future<void> _print(List<Depense> depenses) async {
    if (_printing) return;
    setState(() => _printing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final armoiries = (await rootBundle.load(
        'assets/images/armoiries_ci.png',
      )).buffer.asUint8List();
      final doc = buildDepensesPdf(
        depenses,
        armoiries: armoiries,
        debut: _debut,
        fin: _fin,
        filtre: _filtre,
        theme: await chargerThemePdf(),
      );
      final bytes = await doc.save();
      if (!mounted) return;
      await showPdfPreviewDialog(context, bytes);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Erreur : ${messageErreur(e)}'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  Future<void> _choisirDate({required bool debut}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: debut ? _debut : _fin,
      firstDate: DateTime(now.year - 5),
      lastDate: now.add(const Duration(days: 365)),
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
    final depensesAsync = ref.watch(depensesProvider(_periode));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Dépenses',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                onPressed: depensesAsync.maybeWhen(
                  data: (depenses) {
                    final filtrees = _filtrees(depenses);
                    return filtrees.isEmpty || _printing
                        ? null
                        : () => _print(filtrees);
                  },
                  orElse: () => null,
                ),
                icon: const Icon(Icons.print_outlined, size: 18),
                label: Text(_printing ? 'Préparation...' : 'Imprimer'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () =>
                    showRegisterDepenseDialog(context, periode: _periode),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Ajouter une dépense'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _BarreFiltres(
          debut: _debut,
          fin: _fin,
          filtre: _filtre,
          onChoisirDate: (debut) => _choisirDate(debut: debut),
          onPeriode: (debut, fin) => setState(() {
            _debut = debut;
            _fin = fin;
          }),
          onFiltre: (filtre) => setState(() => _filtre = filtre),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: depensesAsync.when(
            data: (depenses) {
              final filtrees = _filtrees(depenses);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Totaux(depenses: filtrees, filtre: _filtre),
                  const SizedBox(height: 16),
                  Expanded(
                    child: filtrees.isEmpty
                        ? const EmptyState(
                            message:
                                'Aucune dépense enregistrée sur cette période.',
                            icon: Icons.receipt_long_outlined,
                          )
                        : _ListeParDate(depenses: filtrees, periode: _periode),
                  ),
                ],
              );
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

class _BarreFiltres extends StatelessWidget {
  const _BarreFiltres({
    required this.debut,
    required this.fin,
    required this.filtre,
    required this.onChoisirDate,
    required this.onPeriode,
    required this.onFiltre,
  });

  final DateTime debut;
  final DateTime fin;
  final TypeDepense? filtre;
  final ValueChanged<bool> onChoisirDate;
  final void Function(DateTime debut, DateTime fin) onPeriode;
  final ValueChanged<TypeDepense?> onFiltre;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final aujourdhui = DateTime(now.year, now.month, now.day);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _BoutonDate(
              label: 'Du',
              value: debut,
              onTap: () => onChoisirDate(true),
            ),
            _BoutonDate(
              label: 'Au',
              value: fin,
              onTap: () => onChoisirDate(false),
            ),
            const SizedBox(width: 4),
            FilterChipPill(
              label: 'Aujourd\'hui',
              selected: debut == aujourdhui && fin == aujourdhui,
              onTap: () => onPeriode(aujourdhui, aujourdhui),
            ),
            FilterChipPill(
              label: 'Ce mois-ci',
              selected:
                  debut == DateTime(now.year, now.month, 1) &&
                  fin == DateTime(now.year, now.month + 1, 0),
              onTap: () => onPeriode(
                DateTime(now.year, now.month, 1),
                DateTime(now.year, now.month + 1, 0),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilterChipPill(
              label: 'Toutes',
              selected: filtre == null,
              onTap: () => onFiltre(null),
            ),
            for (final type in TypeDepense.values)
              FilterChipPill(
                label: type.label,
                selected: filtre == type,
                onTap: () => onFiltre(type),
              ),
          ],
        ),
      ],
    );
  }
}

class _BoutonDate extends StatelessWidget {
  const _BoutonDate({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.calendar_today_outlined, size: 16),
      label: Text('$label ${_dateFmt.format(value)}'),
    );
  }
}

/// Total de la période — la question posée en premier devant un état de
/// dépenses.
///
/// La ventilation entre les deux natures n'a de sens que sur l'ensemble des
/// dépenses : une fois la liste restreinte à une nature, les cartes de
/// l'autre afficheraient zéro et laisseraient croire qu'il n'y a rien à cet
/// endroit. Sous un filtre, seul le total de la nature retenue est donc
/// affiché.
class _Totaux extends StatelessWidget {
  const _Totaux({required this.depenses, required this.filtre});

  final List<Depense> depenses;
  final TypeDepense? filtre;

  @override
  Widget build(BuildContext context) {
    int totalPour(TypeDepense? type) => depenses
        .where((d) => type == null || d.type == type)
        .fold<int>(0, (somme, d) => somme + d.montant);

    final filtre = this.filtre;
    if (filtre != null) {
      return _TotalCard(
        label: 'Total — ${filtre.label}',
        montant: totalPour(null),
        nombre: depenses.length,
        principal: true,
      );
    }

    return LigneCartes(
      cartes: [
        _TotalCard(
          label: 'Total des dépenses',
          montant: totalPour(null),
          nombre: depenses.length,
          principal: true,
        ),
        _TotalCard(
          label: TypeDepense.service.label,
          montant: totalPour(TypeDepense.service),
          nombre: depenses.where((d) => d.type == TypeDepense.service).length,
        ),
        _TotalCard(
          label: TypeDepense.consultation.label,
          montant: totalPour(TypeDepense.consultation),
          nombre: depenses
              .where((d) => d.type == TypeDepense.consultation)
              .length,
        ),
      ],
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({
    required this.label,
    required this.montant,
    required this.nombre,
    this.principal = false,
  });

  final String label;
  final int montant;
  final int nombre;
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
            '${formatMontant(montant)} FCFA',
            style: TextStyle(
              fontSize: 20,
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
          const SizedBox(height: 2),
          Text(
            nombre <= 1 ? '$nombre dépense' : '$nombre dépenses',
            style: TextStyle(
              color: principal ? AppColors.blueSoft : AppColors.inkMuted,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Les dépenses groupées par journée, les plus récentes en tête — même
/// découpage qu'à l'impression, avec le sous-total de chaque journée.
class _ListeParDate extends StatelessWidget {
  const _ListeParDate({required this.depenses, required this.periode});

  final List<Depense> depenses;
  final PeriodeDepenses periode;

  @override
  Widget build(BuildContext context) {
    final parJour = <DateTime, List<Depense>>{};
    for (final depense in depenses) {
      final jour = DateTime(
        depense.dateDepense.year,
        depense.dateDepense.month,
        depense.dateDepense.day,
      );
      parJour.putIfAbsent(jour, () => []).add(depense);
    }
    final jours = parJour.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView(
      children: [
        for (final jour in jours) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Text(
                  _dateFmt.format(jour),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                Text(
                  '${formatMontant(parJour[jour]!.fold<int>(0, (s, d) => s + d.montant))} FCFA',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkMuted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          for (final depense in parJour[jour]!) ...[
            _DepenseTile(depense: depense, periode: periode),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _DepenseTile extends ConsumerWidget {
  const _DepenseTile({required this.depense, required this.periode});

  final Depense depense;
  final PeriodeDepenses periode;

  Future<void> _confirmerSuppression(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Supprimer la dépense'),
        content: Text(
          'Voulez-vous vraiment supprimer « ${depense.libelle} » '
          '(${formatMontant(depense.montant)} FCFA) ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirme != true) return;
    try {
      await ref.read(depensesRepositoryProvider).deleteDepense(depense.id);
      ref.invalidate(depensesProvider(periode));
      final consultationId = depense.consultationId;
      if (consultationId != null) {
        ref.invalidate(depensesByConsultationProvider(consultationId));
      }
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Dépense supprimée.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Erreur : ${messageErreur(e)}'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final details = [
      if (depense.type == TypeDepense.consultation)
        [
          depense.patient ?? 'Patient inconnu',
          if (depense.dateConsultation != null)
            'consultation du ${_dateFmt.format(depense.dateConsultation!)}',
        ].join(' — '),
    ].join(' · ');

    return Material(
      color: AppColors.blueMist,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            StatusChip(
              label: depense.categorie.label,
              level: depense.type == TypeDepense.consultation
                  ? AlertLevel.info
                  : AlertLevel.success,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    depense.libelle,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (details.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      details,
                      style: const TextStyle(
                        color: AppColors.inkMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  if (depense.observations != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      depense.observations!,
                      style: const TextStyle(
                        color: AppColors.inkMuted,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 16),
            Text(
              '${formatMontant(depense.montant)} FCFA',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              tooltip: 'Modifier',
              onPressed: () => showRegisterDepenseDialog(
                context,
                periode: periode,
                depense: depense,
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.delete_outline,
                size: 20,
                color: AppColors.danger,
              ),
              tooltip: 'Supprimer',
              onPressed: () => _confirmerSuppression(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}
