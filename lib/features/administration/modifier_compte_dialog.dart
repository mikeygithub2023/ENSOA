import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/erreurs.dart';
import '../../core/postes.dart';
import '../../modules/scolarite/models/promotion.dart';
import '../../core/theme.dart';
import '../../models/profil.dart';
import '../auth/providers/auth_providers.dart';
import 'providers/comptes_providers.dart';

/// Modification d'un compte : l'identité et le poste.
///
/// Le matricule n'y figure pas — c'est la clé de connexion, et la changer
/// sans refaire le compte d'authentification laisserait son titulaire à la
/// porte. Un matricule erroné se corrige en rouvrant le compte.
class ModifierCompteDialog extends ConsumerStatefulWidget {
  const ModifierCompteDialog({
    super.key,
    required this.compte,
    this.cestMoi = false,
  });

  final Profil compte;

  /// Son propre compte : tout se corrige, sauf le poste. Se rétrograder
  /// soi-même laisserait l'école sans administrateur, et personne pour
  /// revenir en arrière.
  final bool cestMoi;

  @override
  ConsumerState<ModifierCompteDialog> createState() =>
      _ModifierCompteDialogState();
}

class _ModifierCompteDialogState extends ConsumerState<ModifierCompteDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nom = TextEditingController(text: widget.compte.nom);
  late final _prenom = TextEditingController(text: widget.compte.prenom);
  late final _grade = TextEditingController(text: widget.compte.grade ?? '');
  late final _titre = TextEditingController(text: widget.compte.titre ?? '');

  late Poste? _poste = posteDepuisRoles(
    widget.compte.roleScolarite,
    widget.compte.roleLogistique,
  );

  /// La promotion commandée, pour un Commandant de Brigade. C'est elle qui
  /// borne tout ce qu'il voit.
  late String? _promotionId = widget.compte.promotionId;
  bool _enCours = false;
  String? _erreur;

  @override
  void dispose() {
    _nom.dispose();
    _prenom.dispose();
    _grade.dispose();
    _titre.dispose();
    super.dispose();
  }

  Future<void> _valider() async {
    if (!_formKey.currentState!.validate() || _poste == null) return;
    setState(() {
      _enCours = true;
      _erreur = null;
    });

    try {
      await ref
          .read(comptesRepositoryProvider)
          .modifier(
            id: widget.compte.id,
            nom: _nom.text.trim(),
            prenom: _prenom.text.trim(),
            grade: _grade.text.trim().isEmpty ? null : _grade.text.trim(),
            titre: _titre.text.trim().isEmpty ? null : _titre.text.trim(),
            poste: _poste!,
            promotionId: _promotionId,
          );
      ref.invalidate(comptesProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _erreur = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final moi = ref.watch(profilCourantProvider).value;
    final monPoste = moi == null
        ? null
        : posteDepuisRoles(moi.roleScolarite, moi.roleLogistique);
    final postesOuverts = (postesCreables[monPoste] ?? const <Poste>{}).toList();

    return AlertDialog(
      scrollable: true,
      title: Text(widget.compte.matricule ?? 'Compte'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<Poste>(
                initialValue: postesOuverts.contains(_poste) ? _poste : null,
                decoration: InputDecoration(
                  labelText: 'Poste',
                  helperText: widget.cestMoi
                      ? 'Votre propre poste ne se change pas ici : un autre '
                            'administrateur doit le faire.'
                      : null,
                  helperMaxLines: 2,
                ),
                items: [
                  for (final p in postesOuverts)
                    DropdownMenuItem(value: p, child: Text(p.libelle)),
                ],
                onChanged: widget.cestMoi
                    ? null
                    : (p) => setState(() => _poste = p),
                validator: (p) => p == null ? 'Choisissez un poste' : null,
              ),
              if (_poste == Poste.commandantBrigade) ...[
                const SizedBox(height: 16),
                ref
                    .watch(promotionsNommeesProvider)
                    .when(
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text(
                        'Promotions illisibles : ${messageErreur(e)}',
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontSize: 12,
                        ),
                      ),
                      data: (liste) => DropdownButtonFormField<String>(
                        initialValue: _promotionId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Promotion commandée',
                          helperText:
                              'Il ne verra que les phases de cette promotion '
                              'et les élèves qui y sont affectés.',
                          helperMaxLines: 2,
                        ),
                        items: [
                          for (final p in liste)
                            DropdownMenuItem(
                              value: p.id,
                              child: Text(p.intitule),
                            ),
                        ],
                        onChanged: (v) => setState(() => _promotionId = v),
                        validator: (v) => v == null
                            ? 'Ce poste commande une promotion : choisissez-la'
                            : null,
                      ),
                    ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _grade,
                      decoration: const InputDecoration(
                        labelText: 'Grade (facultatif)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _prenom,
                      decoration: const InputDecoration(labelText: 'Prénom'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nom,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'Nom'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _titre,
                decoration: InputDecoration(
                  labelText: 'Titre affiché (facultatif)',
                  helperText: _poste == null
                      ? 'Remplace le libellé du poste dans toute '
                            "l'application. Le poste, lui, ne change pas."
                      : 'Laissé vide, on l\'appellera '
                            '« ${_poste!.libelle} » dans toute '
                            "l'application. Le poste, lui, ne change pas.",
                  helperMaxLines: 3,
                ),
              ),
              // Le titre d'usage à portée de doigt : c'est par là qu'un
              // compte d'administrateur devient « Commandant de l'école ».
              if (titreDUsage(_poste) != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ActionChip(
                    avatar: const Icon(Icons.military_tech_outlined, size: 16),
                    label: Text(titreDUsage(_poste)!),
                    onPressed: () =>
                        setState(() => _titre.text = titreDUsage(_poste)!),
                  ),
                ),
              ],
              if (_erreur != null) ...[
                const SizedBox(height: 16),
                Text(_erreur!, style: const TextStyle(color: AppColors.danger)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _enCours ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _enCours ? null : _valider,
          child: _enCours
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Enregistrer'),
        ),
      ],
    );
  }
}
