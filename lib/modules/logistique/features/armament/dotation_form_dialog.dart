import 'package:sig_ensoa/core/formulaire.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:sig_ensoa/modules/logistique/compat.dart';
import 'package:sig_ensoa/core/theme.dart';
import '../../data/models/armement.dart';
import '../../data/repositories/armament_providers.dart';
import '../../data/repositories/misc_providers.dart';
import '../../shared/widgets/widgets.dart';

/// Bon de sortie d'arme — remise individuelle à un militaire. [arme] est
/// préréglée quand on vient de la fiche détail d'une arme précise ; sinon
/// (ouvert depuis l'onglet "Bons") l'utilisateur la retrouve par numéro de
/// série, avec ses informations affichées en lecture seule une fois trouvée.
class DotationFormDialog extends ConsumerStatefulWidget {
  final Arme? arme;
  const DotationFormDialog({super.key, this.arme});

  @override
  ConsumerState<DotationFormDialog> createState() => _DotationFormDialogState();
}

class _DotationFormDialogState extends ConsumerState<DotationFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _numeroSerieCtrl = TextEditingController();
  final _typeCtrl = TextEditingController();
  final _modeleCtrl = TextEditingController();
  final _beneficiaireCtrl = TextEditingController();
  final _beneficiaireNomCtrl = TextEditingController();
  final _motifCtrl = TextEditingController();
  int _dureeJours = 7;
  bool _envoi = false;
  Arme? _armeTrouvee;
  String? _messageRecherche;

  @override
  void initState() {
    super.initState();
    if (widget.arme != null) _appliquerArme(widget.arme!, message: null);
  }

  @override
  void dispose() {
    _numeroSerieCtrl.dispose();
    _typeCtrl.dispose();
    _modeleCtrl.dispose();
    _beneficiaireCtrl.dispose();
    _beneficiaireNomCtrl.dispose();
    _motifCtrl.dispose();
    super.dispose();
  }

  void _appliquerArme(Arme a, {required String? message}) {
    _numeroSerieCtrl.text = a.numeroSerie;
    _typeCtrl.text = a.type;
    _modeleCtrl.text = a.modele;
    _armeTrouvee = a.etat == EtatArme.enArmurerie ? a : null;
    _messageRecherche =
        message ??
        (a.etat == EtatArme.enArmurerie
            ? null
            : 'Cette arme n\'est pas disponible actuellement (${a.etat.label}).');
  }

  void _rechercherArme() {
    final numero = _numeroSerieCtrl.text.trim();
    if (numero.isEmpty) return;
    final armes = ref.read(armesProvider);
    final trouve = armes.where(
      (a) => a.numeroSerie.toLowerCase() == numero.toLowerCase(),
    );
    setState(() {
      if (trouve.isEmpty) {
        _armeTrouvee = null;
        _typeCtrl.clear();
        _modeleCtrl.clear();
        _messageRecherche = 'Aucune arme trouvée avec ce numéro de série.';
      } else {
        _appliquerArme(trouve.first, message: null);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final lectureSeule = widget.arme != null;
    return AlertDialog(
      scrollable: true,
      title: const Text('Bon de sortie'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _numeroSerieCtrl,
                      readOnly: lectureSeule,
                      decoration: const InputDecoration(
                        labelText: 'Numéro de série de l\'arme',
                      ),
                      textCapitalization: TextCapitalization.characters,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Requis' : null,
                      onEditingComplete: _rechercherArme,
                      onTapOutside: (_) => _rechercherArme(),
                    ),
                  ),
                  if (!lectureSeule) ...[
                    const SizedBox(width: 12),
                    IconButton.filledTonal(
                      tooltip: 'Rechercher l\'arme',
                      onPressed: _rechercherArme,
                      icon: const Icon(Icons.search),
                    ),
                  ],
                ],
              ),
              if (_messageRecherche != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _messageRecherche!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.danger,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _typeCtrl,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: "Type d'arme",
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _modeleCtrl,
                      readOnly: true,
                      decoration: const InputDecoration(labelText: 'Modèle'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _beneficiaireCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Matricule bénéficiaire',
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Requis' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _beneficiaireNomCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nom du bénéficiaire',
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Requis' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _motifCtrl,
                decoration: const InputDecoration(
                  labelText: 'Motif (garde, instruction, mission...)',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Retour prévu dans : '),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: _dureeJours,
                    items: const [1, 3, 7, 14, 30]
                        .map(
                          (d) => DropdownMenuItem(
                            value: d,
                            child: Text('$d jour(s)'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _dureeJours = v ?? 7),
                  ),
                ],
              ),
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
          onPressed: _envoi ? null : _submit,
          child: const Text('Remettre l\'arme'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!validerFormulaire(context, _formKey)) return;
    final arme = _armeTrouvee;
    if (arme == null) {
      setState(
        () => _messageRecherche ??=
            'Recherchez une arme disponible avant d\'enregistrer.',
      );
      return;
    }
    setState(() => _envoi = true);
    final user = ref.read(sessionProvider)!.user;
    final dotation = DotationArme(
      id: const Uuid().v4(),
      armeId: arme.id,
      beneficiaireId: _beneficiaireCtrl.text.trim(),
      beneficiaireNom: _beneficiaireNomCtrl.text.trim(),
      dateRemise: DateTime.now(),
      dateRetourPrevue: DateTime.now().add(Duration(days: _dureeJours)),
      remisePar: user.id,
      motif: _motifCtrl.text.trim().isEmpty ? null : _motifCtrl.text.trim(),
    );
    try {
      await ref.read(dotationsProvider.notifier).remettre(dotation);
      ref
          .read(auditProvider.notifier)
          .log(
            auteurId: user.id,
            action: 'ARME_REMISE',
            cible: arme.numeroSerie,
            detail:
                'Bénéficiaire ${dotation.beneficiaireId} — ${dotation.motif ?? 'sans motif précisé'}',
          );
      if (mounted) {
        showSuccessSnackBar(context, 'Bon de sortie enregistré avec succès.');
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
