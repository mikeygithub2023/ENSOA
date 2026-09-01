import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/identite.dart';
import '../../core/postes.dart';
import '../../core/roles.dart';
import '../../core/theme.dart';
import '../../modules/scolarite/models/division.dart';
import '../auth/providers/auth_providers.dart';
import 'providers/comptes_providers.dart';

/// Ouverture d'un compte. On choisit un poste ; les rôles suivent.
///
/// La liste des postes proposés est bornée par la chaîne de commandement —
/// mais ce n'est qu'une commodité : c'est la fonction serveur qui refuse, la
/// liste déroulante ne protège rien.
class NouveauCompteDialog extends ConsumerStatefulWidget {
  const NouveauCompteDialog({super.key});

  @override
  ConsumerState<NouveauCompteDialog> createState() =>
      _NouveauCompteDialogState();
}

class _NouveauCompteDialogState extends ConsumerState<NouveauCompteDialog> {
  final _formKey = GlobalKey<FormState>();
  final _matricule = TextEditingController();
  final _nom = TextEditingController();
  final _prenom = TextEditingController();
  final _grade = TextEditingController();
  final _motDePasse = TextEditingController();
  final _titre = TextEditingController();

  Poste? _poste;
  String? _divisionId;

  /// Un chef de division ou un commandant de brigade sans division ne voit
  /// rien : la RLS borne à la sienne tout ce qu'il consulte. Pour les autres
  /// postes de la scolarité, l'affectation peut attendre.
  bool get _divisionObligatoire =>
      _poste == Poste.chefDivision || _poste == Poste.commandantBrigade;

  bool _enCours = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    // L'aperçu de l'identifiant se met à jour à la frappe : le matricule est
    // la clé de connexion, autant montrer ce qu'il devient.
    _matricule.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _matricule.dispose();
    _nom.dispose();
    _prenom.dispose();
    _grade.dispose();
    _motDePasse.dispose();
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
          .ouvrir(
            matricule: _matricule.text.trim(),
            nom: _nom.text.trim(),
            prenom: _prenom.text.trim(),
            grade: _grade.text.trim().isEmpty ? null : _grade.text.trim(),
            poste: _poste!,
            motDePasse: _motDePasse.text,
            titre: _titre.text.trim().isEmpty ? null : _titre.text.trim(),
            divisionId: _divisionId,
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
    final divisions = ref.watch(divisionsProvider);

    return AlertDialog(
      scrollable: true,
      title: const Text('Ouvrir un compte'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<Poste>(
                  initialValue: _poste,
                  decoration: const InputDecoration(labelText: 'Poste'),
                  items: [
                    for (final p in postesOuverts)
                      DropdownMenuItem(value: p, child: Text(p.libelle)),
                  ],
                  onChanged: (p) => setState(() => _poste = p),
                  validator: (p) => p == null ? 'Choisissez un poste' : null,
                ),
                if (_poste != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _resumeDesRoles(_poste!),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ],
                // La division n'a de sens que pour les postes de la scolarité,
                // et elle y est déterminante : c'est elle qui borne ce qu'un
                // chef de division ou un instructeur voit. Sans elle, le
                // compte s'ouvre mais ne montre rien.
                if (_poste?.roleScolarite != null) ...[
                  const SizedBox(height: 16),
                  divisions.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text(
                      'Divisions illisibles : $e',
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 12,
                      ),
                    ),
                    data: (liste) => DropdownButtonFormField<String>(
                      initialValue: _divisionId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: _divisionObligatoire
                            ? 'Division'
                            : 'Division (facultatif)',
                      ),
                      items: [
                        for (final d in liste)
                          DropdownMenuItem(value: d.id, child: Text(d.nom)),
                      ],
                      onChanged: (v) => setState(() => _divisionId = v),
                      validator: (v) => _divisionObligatoire && v == null
                          ? 'Ce poste commande une division : choisissez-la'
                          : null,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: _matricule,
                  textCapitalization: TextCapitalization.characters,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: 'Identifiant',
                    helperText: _matricule.text.trim().isEmpty
                        ? "C'est avec lui que la personne se connectera — son matricule, en général."
                        : 'Identifiant technique : '
                              '${Identite.emailDepuisMatricule(_matricule.text.trim())}',
                    helperMaxLines: 2,
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Champ requis'
                      : null,
                ),
                const SizedBox(height: 12),
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
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Champ requis'
                      : null,
                ),
                const SizedBox(height: 12),
                // Le titre était présenté comme un champ libre parmi d'autres,
                // et personne ne devinait qu'il servait à écrire « Commandant
                // de l'école » sur un compte d'administrateur. Il nomme donc
                // maintenant le poste choisi, et propose le titre d'usage
                // quand il y en a un.
                TextFormField(
                  controller: _titre,
                  decoration: InputDecoration(
                    labelText: 'Titre affiché (facultatif)',
                    helperText: _poste == null
                        ? 'Remplace le libellé du poste dans toute '
                              "l'application."
                        : 'Laissé vide, on l\'appellera '
                              '« ${_poste!.libelle} » dans toute '
                              "l'application.",
                    helperMaxLines: 2,
                  ),
                ),
                if (titreDUsage(_poste) != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ActionChip(
                      avatar: const Icon(Icons.military_tech_outlined, size: 16),
                      label: Text(titreDUsage(_poste)!),
                      onPressed: () => setState(
                        () => _titre.text = titreDUsage(_poste)!,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: _motDePasse,
                  decoration: const InputDecoration(
                    labelText: "Mot de passe d'ouverture",
                    helperText:
                        'À remettre en main propre. La personne devra le '
                        'remplacer à sa première connexion.',
                    helperMaxLines: 2,
                  ),
                  validator: (v) =>
                      (v == null ||
                          v.length < Identite.longueurMinimaleMotDePasse)
                      ? '${Identite.longueurMinimaleMotDePasse} caractères minimum'
                      : null,
                ),
                if (_erreur != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _erreur!,
                    style: const TextStyle(color: AppColors.danger),
                  ),
                ],
              ],
            ),
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
              : const Text('Ouvrir le compte'),
        ),
      ],
    );
  }

  /// Dit tout haut ce que le poste implique — utile surtout pour les deux
  /// postes qui ouvrent les deux modules à la fois.
  String _resumeDesRoles(Poste poste) {
    final s = poste.roleScolarite?.libelle;
    final l = poste.roleLogistique?.libelle;
    if (s != null && l != null) return 'Ouvre les deux modules : $s + $l.';
    if (s != null) return 'Module scolarité : $s.';
    if (l != null) return 'Module soutien technique : $l.';
    return '';
  }
}
