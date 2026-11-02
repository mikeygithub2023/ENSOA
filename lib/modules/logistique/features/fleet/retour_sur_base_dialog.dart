import 'package:sig_ensoa/core/formulaire.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sig_ensoa/core/theme.dart';
import 'package:sig_ensoa/modules/logistique/compat.dart';
import '../../data/models/maintenance.dart';
import '../../data/models/pannes.dart';
import '../../data/models/vehicule.dart';
import '../../data/repositories/misc_providers.dart';
import '../../data/repositories/pannes_providers.dart';
import '../../shared/widgets/widgets.dart';

/// Les pannes qu'une réparation a reprises : celles de la demande qui l'a
/// ouverte. Une réparation déclarée sans demande n'en a pas — seul son texte
/// « pannes constatées » les nomme.
List<Panne> pannesDeLaReparation(WidgetRef ref, Reparation r) {
  final demandes = ref
      .watch(demandesReparationProvider)
      .where((d) => d.reparationId == r.id)
      .map((d) => d.id)
      .toSet();
  return ref
      .watch(pannesProvider)
      .where((p) => p.demandeId != null && demandes.contains(p.demandeId))
      .toList();
}

/// Le retour sur base d'un véhicule réparé.
///
/// On y coche les pannes réparées — les autres restent sur le véhicule —, on
/// y consigne celles que le garage a décelées sans les réparer, et l'on dit
/// dans quel état le véhicule revient. La réparation se clôt alors.
class RetourSurBaseDialog extends ConsumerStatefulWidget {
  final Reparation reparation;
  final Vehicule vehicule;
  const RetourSurBaseDialog({
    super.key,
    required this.reparation,
    required this.vehicule,
  });

  @override
  ConsumerState<RetourSurBaseDialog> createState() =>
      _RetourSurBaseDialogState();
}

class _RetourSurBaseDialogState extends ConsumerState<RetourSurBaseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _travauxCtrl = TextEditingController();
  final _panneCtrl = TextEditingController();
  GravitePanne _gravite = GravitePanne.legere;
  EtatVehicule _etatRetour = EtatVehicule.disponible;
  bool _envoi = false;

  /// Les pannes cochées comme réparées. Initialisée à la première
  /// construction, d'après ce que la base sait déjà.
  Set<String>? _reparees;
  final List<PanneDecelee> _decelees = [];

  @override
  void dispose() {
    _travauxCtrl.dispose();
    _panneCtrl.dispose();
    super.dispose();
  }

  void _ajouterPanne() {
    final texte = _panneCtrl.text.trim();
    if (texte.isEmpty) return;
    setState(() {
      _decelees.add(PanneDecelee(texte, _gravite));
      _panneCtrl.clear();
      _gravite = GravitePanne.legere;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pannes = pannesDeLaReparation(ref, widget.reparation);
    final reparees = _reparees ??= {
      for (final p in pannes)
        if (p.resolue) p.id,
    };
    final restantes = pannes.length - reparees.length + _decelees.length;

    return AlertDialog(
      scrollable: true,
      title: Text('Retour sur base — ${widget.vehicule.immatriculation}'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const _Titre('Pannes prises en charge'),
              if (pannes.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    widget.reparation.pannesConstatees,
                    style: const TextStyle(fontSize: 13),
                  ),
                )
              else ...[
                const Text(
                  'Cochez celles qui ont été réparées ; les autres restent '
                  'sur le véhicule.',
                  style: TextStyle(fontSize: 12, color: AppColors.inkMuted),
                ),
                for (final p in pannes)
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: reparees.contains(p.id),
                    onChanged: (v) => setState(() {
                      if (v == true) {
                        reparees.add(p.id);
                      } else {
                        reparees.remove(p.id);
                      }
                    }),
                    title: Text(p.description),
                    subtitle: Text(p.gravite.label),
                  ),
              ],
              const SizedBox(height: 16),
              const _Titre('Pannes décelées, non réparées'),
              for (final (i, p) in _decelees.indexed)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.report_problem_outlined,
                    color: AppColors.warning,
                  ),
                  title: Text(p.description),
                  subtitle: Text(p.gravite.label),
                  trailing: IconButton(
                    tooltip: 'Retirer',
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _decelees.removeAt(i)),
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _panneCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Panne décelée',
                      ),
                      onSubmitted: (_) => _ajouterPanne(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<GravitePanne>(
                      initialValue: _gravite,
                      decoration: const InputDecoration(labelText: 'Gravité'),
                      items: [
                        for (final g in GravitePanne.values)
                          DropdownMenuItem(value: g, child: Text(g.label)),
                      ],
                      onChanged: (g) =>
                          setState(() => _gravite = g ?? GravitePanne.legere),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton.filledTonal(
                    tooltip: 'Ajouter la panne',
                    onPressed: _ajouterPanne,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _travauxCtrl,
                decoration: const InputDecoration(
                  labelText: 'Travaux effectués',
                ),
                maxLines: 2,
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Requis pour valider le retour'
                    : null,
              ),
              const SizedBox(height: 16),
              const _Titre('État du véhicule au retour'),
              SegmentedButton<EtatVehicule>(
                segments: const [
                  ButtonSegment(
                    value: EtatVehicule.disponible,
                    label: Text('Disponible'),
                  ),
                  ButtonSegment(
                    value: EtatVehicule.horsService,
                    label: Text('Hors service'),
                  ),
                ],
                selected: {_etatRetour},
                onSelectionChanged: (s) =>
                    setState(() => _etatRetour = s.first),
              ),
              if (restantes > 0) ...[
                const SizedBox(height: 10),
                Text(
                  restantes == 1
                      ? 'Le véhicule reviendra avec 1 panne non réparée.'
                      : 'Le véhicule reviendra avec $restantes pannes non '
                            'réparées.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.warning,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _envoi ? null : () => _submit(pannes),
          child: const Text('Valider le retour'),
        ),
      ],
    );
  }

  Future<void> _submit(List<Panne> pannes) async {
    if (!validerFormulaire(context, _formKey)) return;
    // Une panne saisie mais pas ajoutée se perdrait sans bruit : on la prend.
    _ajouterPanne();
    setState(() => _envoi = true);
    final user = ref.read(sessionProvider)!.user;
    final reparees = _reparees ?? {};
    try {
      await validerRetourSurBase(
        ref,
        reparationId: widget.reparation.id,
        vehiculeId: widget.vehicule.id,
        auteurId: user.id,
        travauxEffectues: _travauxCtrl.text.trim(),
        etatRetour: _etatRetour,
        pannesReparees: [
          for (final p in pannes)
            if (reparees.contains(p.id)) p.id,
        ],
        pannesNonReparees: [
          for (final p in pannes)
            if (!reparees.contains(p.id)) p.id,
        ],
        pannesDecelees: _decelees,
      );
      ref
          .read(auditProvider.notifier)
          .log(
            auteurId: user.id,
            action: 'RETOUR_SUR_BASE',
            cible: widget.vehicule.immatriculation,
            detail:
                'État : ${_etatRetour.label} — '
                '${reparees.length}/${pannes.length} panne(s) réparée(s), '
                '${_decelees.length} décelée(s)',
          );
      if (mounted) {
        showSuccessSnackBar(context, 'Retour sur base validé.');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _envoi = false);
        showErrorSnackBar(context, e);
      }
    }
  }
}

class _Titre extends StatelessWidget {
  const _Titre(this.texte);

  final String texte;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        texte,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          color: AppColors.navy,
        ),
      ),
    );
  }
}
