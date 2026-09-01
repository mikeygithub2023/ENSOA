import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:sig_ensoa/core/erreurs.dart';
import 'package:sig_ensoa/core/theme.dart' hide AlertLevel, AlertLevelColor;
import '../../models/demande_reapprovisionnement.dart';
import '../../models/medicament.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/pdf_preview_dialog.dart';
import '../apprenants/pdf_fonts.dart';
import 'demande_reapprovisionnement_pdf.dart';
import 'providers/demandes_reapprovisionnement_providers.dart';
import 'register_demande_reapprovisionnement_dialog.dart';

final _dateFmt = DateFormat('dd/MM/yyyy');

/// Rubrique « Demandes de réapprovisionnement » de la pharmacie : les
/// fiches déjà établies, et de quoi en établir une nouvelle. Une fiche
/// exprime un besoin — elle ne touche pas au stock, qui ne bougera qu'à la
/// réception effective, par un mouvement de stock.
class DemandesReapprovisionnementView extends ConsumerStatefulWidget {
  const DemandesReapprovisionnementView({super.key, required this.medicaments});

  final List<Medicament> medicaments;

  @override
  ConsumerState<DemandesReapprovisionnementView> createState() =>
      _DemandesReapprovisionnementViewState();
}

class _DemandesReapprovisionnementViewState
    extends ConsumerState<DemandesReapprovisionnementView> {
  String? _impressionEnCours;

  Future<void> _imprimer(DemandeReapprovisionnement demande) async {
    if (_impressionEnCours != null) return;
    setState(() => _impressionEnCours = demande.id);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final armoiries = (await rootBundle.load(
        'assets/images/armoiries_ci.png',
      )).buffer.asUint8List();
      final doc = buildDemandeReapprovisionnementPdf(
        demande,
        armoiries: armoiries,
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
      if (mounted) setState(() => _impressionEnCours = null);
    }
  }

  Future<void> _supprimer(DemandeReapprovisionnement demande) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Supprimer la demande'),
        content: Text(
          'Voulez-vous vraiment supprimer la demande du '
          '${_dateFmt.format(demande.dateDemande)} '
          '(${demande.lignes.length} médicament(s)) ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Supprimer',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (confirme != true) return;
    try {
      await ref
          .read(demandesReapprovisionnementRepositoryProvider)
          .deleteDemande(demande.id);
      ref.invalidate(demandesReapprovisionnementProvider);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Demande supprimée.'),
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
  Widget build(BuildContext context) {
    final demandesAsync = ref.watch(demandesReapprovisionnementProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Fiches établies, la plus récente en tête.',
                style: TextStyle(color: AppColors.inkMuted, fontSize: 13),
              ),
            ),
            FilledButton.icon(
              onPressed: widget.medicaments.isEmpty
                  ? null
                  : () => showRegisterDemandeReapprovisionnementDialog(
                      context,
                      medicaments: widget.medicaments,
                    ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Nouvelle demande'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: demandesAsync.when(
            data: (demandes) {
              if (demandes.isEmpty) {
                return const EmptyState(
                  message: 'Aucune demande de réapprovisionnement établie.',
                  icon: Icons.assignment_outlined,
                );
              }
              return ListView.separated(
                itemCount: demandes.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) => _DemandeTile(
                  demande: demandes[index],
                  impression: _impressionEnCours == demandes[index].id,
                  onImprimer: () => _imprimer(demandes[index]),
                  onSupprimer: () => _supprimer(demandes[index]),
                ),
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

/// Une fiche, dépliable pour voir le détail des médicaments commandés sans
/// avoir à l'imprimer.
class _DemandeTile extends StatefulWidget {
  const _DemandeTile({
    required this.demande,
    required this.impression,
    required this.onImprimer,
    required this.onSupprimer,
  });

  final DemandeReapprovisionnement demande;
  final bool impression;
  final VoidCallback onImprimer;
  final VoidCallback onSupprimer;

  @override
  State<_DemandeTile> createState() => _DemandeTileState();
}

class _DemandeTileState extends State<_DemandeTile> {
  bool _deplie = false;

  @override
  Widget build(BuildContext context) {
    final demande = widget.demande;

    return Material(
      color: AppColors.blueMist,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _deplie = !_deplie),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    _deplie ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.inkMuted,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Demande du ${_dateFmt.format(demande.dateDemande)}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        if (demande.observations != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            demande.observations!,
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
                  StatusChip(
                    label:
                        '${demande.lignes.length} article(s) · '
                        '${demande.totalUnites} unité(s)',
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: widget.impression ? null : widget.onImprimer,
                    icon: const Icon(Icons.print_outlined, size: 18),
                    label: Text(
                      widget.impression ? 'Préparation...' : 'Imprimer',
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: AppColors.danger,
                    ),
                    tooltip: 'Supprimer',
                    onPressed: widget.onSupprimer,
                  ),
                ],
              ),
            ),
          ),
          if (_deplie) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(48, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final ligne in demande.lignes)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              ligne.medicamentNom ?? 'Médicament inconnu',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          Text(
                            'Stock au moment de la demande : '
                            '${ligne.stockAuMomentDeLaDemande}',
                            style: const TextStyle(
                              color: AppColors.inkMuted,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 16),
                          SizedBox(
                            width: 110,
                            child: Text(
                              'Demandé : ${ligne.quantiteDemandee}',
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
