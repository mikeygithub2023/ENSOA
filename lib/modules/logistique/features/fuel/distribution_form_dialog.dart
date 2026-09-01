import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:sig_ensoa/modules/logistique/compat.dart';
import 'package:sig_ensoa/core/supabase_client.dart';
import 'package:sig_ensoa/core/theme.dart';
import 'package:sig_ensoa/core/format.dart';
import '../../data/models/carburant.dart';
import '../../data/repositories/fuel_providers.dart';
import '../../data/repositories/organisation_providers.dart';
import '../../data/repositories/misc_providers.dart';
import '../../shared/widgets/widgets.dart';

class DistributionFormDialog extends ConsumerStatefulWidget {
  const DistributionFormDialog({super.key});

  @override
  ConsumerState<DistributionFormDialog> createState() =>
      _DistributionFormDialogState();
}

class _DistributionFormDialogState
    extends ConsumerState<DistributionFormDialog> {
  final _formKey = GlobalKey<FormState>();

  // Véhicule
  final _immatCtrl = TextEditingController();
  final _marqueCtrl = TextEditingController();
  final _kmCtrl = TextEditingController();

  // Bénéficiaire
  final _contactCtrl = TextEditingController();
  final _gradeCtrl = TextEditingController();

  /// La fiche du bénéficiaire, quand il a été pris dans le référentiel.
  String? _personnelId;
  final _nomCtrl = TextEditingController();

  // Carburant
  String? _souteId;
  String? _souteStockId;
  String _typeCarburant = 'Gasoil';
  final _qteCtrl = TextEditingController();
  final _motifCtrl = TextEditingController();

  bool _envoi = false;
  bool _recherche = false;
  String? _messageRecherche;

  @override
  void dispose() {
    _immatCtrl.dispose();
    _marqueCtrl.dispose();
    _kmCtrl.dispose();
    _contactCtrl.dispose();
    _gradeCtrl.dispose();
    _nomCtrl.dispose();
    _qteCtrl.dispose();
    _motifCtrl.dispose();
    super.dispose();
  }

  /// Recherche la dernière distribution enregistrée pour cette immatriculation
  /// et pré-remplit les champs relatifs au véhicule/bénéficiaire si trouvée.
  Future<void> _rechercherVehicule() async {
    final immat = _immatCtrl.text.trim();
    if (immat.isEmpty) return;
    setState(() {
      _recherche = true;
      _messageRecherche = null;
    });
    try {
      final row = await logistique
          .from('distribution')
          .select()
          .eq('vhl_immatriculation', immat)
          .order('date', ascending: false)
          .limit(1)
          .maybeSingle();
      if (row == null) {
        setState(
          () =>
              _messageRecherche = 'Nouveau véhicule — aucun historique trouvé.',
        );
      } else {
        setState(() {
          _marqueCtrl.text = (row['vehicule'] as String?) ?? '';
          _contactCtrl.text = (row['contact'] as String?) ?? '';
          _gradeCtrl.text = (row['grade_destinataire'] as String?) ?? '';
          _nomCtrl.text = (row['destinataire'] as String?) ?? '';
          _messageRecherche =
              'Véhicule reconnu — informations pré-remplies depuis la dernière distribution.';
        });
      }
    } catch (_) {
      setState(() => _messageRecherche = null);
    } finally {
      if (mounted) setState(() => _recherche = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final soutes = ref.watch(soutesProvider);
    final soutesAvecStock = ref.watch(soutesAvecStockProvider);
    final repartitionsDeLaSoute = soutesAvecStock
        .where((s) => s.soute.id == _souteId)
        .toList();
    final repartitionChoisie = repartitionsDeLaSoute.where(
      (s) => s.stock.id == _souteStockId,
    );
    final carburantRestant = repartitionChoisie.isEmpty
        ? null
        : (_typeCarburant == 'Gasoil'
              ? repartitionChoisie.first.stock.qteGasoil
              : repartitionChoisie.first.stock.qteSuper);

    return AlertDialog(
      scrollable: true,
      title: const Text('Nouvelle distribution'),
      content: SizedBox(
        width: 680,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _sectionTitle('Véhicule'),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _immatCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Immatriculation',
                      ),
                      textCapitalization: TextCapitalization.characters,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Requis' : null,
                      onEditingComplete: _rechercherVehicule,
                      onTapOutside: (_) => _rechercherVehicule(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton.filledTonal(
                    tooltip: 'Rechercher l\'historique de ce véhicule',
                    onPressed: _recherche ? null : _rechercherVehicule,
                    icon: _recherche
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search),
                  ),
                ],
              ),
              if (_messageRecherche != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _messageRecherche!,
                    style: const TextStyle(fontSize: 12, color: AppColors.blue),
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _marqueCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Marque du véhicule',
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Requis' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _kmCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Kilométrage',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Requis' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _sectionTitle('Bénéficiaire'),
              // Choisir dans le référentiel remplit les trois champs et
              // rattache la distribution à la fiche du militaire. Ce n'est pas
              // obligatoire : quelqu'un qui n'y figure pas se saisit à la main,
              // comme avant.
              Consumer(
                builder: (context, ref, _) {
                  final personnel = ref.watch(personnelProvider);
                  if (personnel.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _personnelId,
                      decoration: const InputDecoration(
                        labelText: 'Prendre dans le personnel (facultatif)',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('— Saisir à la main —'),
                        ),
                        for (final p in personnel)
                          DropdownMenuItem(
                            value: p.id,
                            child: Text(
                              '${p.grade ?? ''} ${p.nomComplet} · ${p.matricule}'
                                  .trim(),
                            ),
                          ),
                      ],
                      onChanged: (id) {
                        final choisi = trouverPersonnel(personnel, id);
                        setState(() {
                          _personnelId = id;
                          if (choisi != null) {
                            _gradeCtrl.text = choisi.grade ?? '';
                            _nomCtrl.text = choisi.nomComplet;
                            _contactCtrl.text = choisi.contact ?? '';
                          }
                        });
                      },
                    ),
                  );
                },
              ),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _gradeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Grade (ou "Civil")',
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Requis' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _nomCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nom et prénoms',
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Requis' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contactCtrl,
                decoration: const InputDecoration(labelText: 'Contact'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Requis' : null,
              ),
              const SizedBox(height: 20),
              _sectionTitle('Carburant'),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _souteId,
                      decoration: const InputDecoration(labelText: 'Soute'),
                      items: [
                        for (final s in soutes)
                          DropdownMenuItem(value: s.id, child: Text(s.libelle)),
                      ],
                      onChanged: (v) => setState(() {
                        _souteId = v;
                        _souteStockId = null;
                      }),
                      validator: (v) => v == null ? 'Requis' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _souteStockId,
                      decoration: const InputDecoration(
                        labelText: 'Répartition',
                      ),
                      items: [
                        for (final s in repartitionsDeLaSoute)
                          DropdownMenuItem(
                            value: s.stock.id,
                            child: Text(
                              s.stock.repartitionLibelle,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: _souteId == null
                          ? null
                          : (v) => setState(() => _souteStockId = v),
                      validator: (v) => v == null ? 'Requis' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _typeCarburant,
                      decoration: const InputDecoration(
                        labelText: 'Type de carburant',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Gasoil',
                          child: Text('Gasoil'),
                        ),
                        DropdownMenuItem(value: 'Super', child: Text('Super')),
                      ],
                      onChanged: (v) =>
                          setState(() => _typeCarburant = v ?? 'Gasoil'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.blueMist,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        carburantRestant == null
                            ? 'Restant : —'
                            : 'Restant : ${formatMilliers(carburantRestant)} L',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _qteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Quantité servie (L)',
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  final qte = int.tryParse(v ?? '') ?? 0;
                  if (qte <= 0) return 'Quantité invalide';
                  if (carburantRestant != null && qte > carburantRestant) {
                    return 'Supérieur au carburant restant (${formatMilliers(carburantRestant)} L)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _motifCtrl,
                decoration: const InputDecoration(labelText: 'Motif'),
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
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      title,
      style: const TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 13,
        color: AppColors.inkMuted,
      ),
    ),
  );

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _envoi = true);
    final user = ref.read(sessionProvider)!.user;
    try {
      await ref
          .read(distributionsProvider.notifier)
          .add(
            Distribution(
              id: const Uuid().v4(),
              souteStockId: _souteStockId!,
              utilisateurId: user.id,
              quantitePercue: int.parse(_qteCtrl.text),
              date: DateTime.now(),
              typeCarburant: _typeCarburant,
              contact: _contactCtrl.text.trim(),
              gradeDestinataire: _gradeCtrl.text.trim(),
              destinataire: _nomCtrl.text.trim(),
              personnelId: _personnelId,
              vehicule: _marqueCtrl.text.trim(),
              vhlImmatriculation: _immatCtrl.text.trim(),
              kilometrage: int.tryParse(_kmCtrl.text),
              motif: _motifCtrl.text.trim().isEmpty
                  ? null
                  : _motifCtrl.text.trim(),
            ),
          );
      ref
          .read(auditProvider.notifier)
          .log(
            auteurId: user.id,
            action: 'DISTRIBUTION_CREE',
            cible: _nomCtrl.text.trim(),
            detail:
                '-${_qteCtrl.text} L $_typeCarburant — ${_immatCtrl.text.trim()}',
          );
      if (mounted) {
        showSuccessSnackBar(context, 'Distribution enregistrée avec succès.');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _envoi = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur Supabase : $e')));
      }
    }
  }
}
