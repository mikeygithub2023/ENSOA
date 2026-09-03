import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/postes.dart';
import '../../core/roles.dart';
import '../../core/theme.dart';
import '../../models/profil.dart';
import '../../modules/logistique/features/admin/assistant_ia.dart';
import '../../modules/scolarite/features/admin/espaces_eleves_screen.dart';
import '../auth/providers/auth_providers.dart';
import 'modifier_compte_dialog.dart';
import 'nouveau_compte_dialog.dart';
import 'providers/comptes_providers.dart';

enum _Rubrique { comptes, espacesEleves, assistant }

/// L'administration : les comptes du personnel, et les espaces des élèves.
///
/// Les deux ne se ressemblent pas et c'est voulu. Un compte du personnel
/// s'ouvre un par un, à un poste. Un espace élève s'ouvre par classe entière,
/// et son identifiant est le numéro de téléphone de l'élève.
class AdministrationScreen extends ConsumerStatefulWidget {
  const AdministrationScreen({super.key});

  @override
  ConsumerState<AdministrationScreen> createState() =>
      _AdministrationScreenState();
}

class _AdministrationScreenState extends ConsumerState<AdministrationScreen> {
  _Rubrique _rubrique = _Rubrique.comptes;

  @override
  Widget build(BuildContext context) {
    final moi = ref.watch(profilCourantProvider).value;
    // Ouvrir l'espace d'un élève est un acte de la scolarité : un chef de
    // service du soutien technique n'a pas à y toucher.
    final espaces = moi != null && moi.peut(Permission.administrerScolarite);
    // L'assistant interroge les données du domaine que l'on commande : il est
    // ouvert à l'administrateur comme au chef du Soutien Technique, et la
    // fonction serveur borne ce que chacun peut lui faire lire.
    final assistant =
        moi != null &&
        (moi.peut(Permission.administrerScolarite) ||
            moi.peut(Permission.administrerPlateforme));

    if (!espaces && !assistant) return const _Comptes();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<_Rubrique>(
          segments: [
            const ButtonSegment(
              value: _Rubrique.comptes,
              label: Text('Comptes du personnel'),
              icon: Icon(Icons.badge_rounded, size: 18),
            ),
            if (espaces)
              const ButtonSegment(
                value: _Rubrique.espacesEleves,
                label: Text('Espaces élèves'),
                icon: Icon(Icons.groups_rounded, size: 18),
              ),
            if (assistant)
              const ButtonSegment(
                value: _Rubrique.assistant,
                label: Text('Assistant'),
                icon: Icon(Icons.auto_awesome_rounded, size: 18),
              ),
          ],
          selected: {_rubrique},
          showSelectedIcon: false,
          onSelectionChanged: (choix) =>
              setState(() => _rubrique = choix.first),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: switch (_rubrique) {
            _Rubrique.comptes => const _Comptes(),
            _Rubrique.espacesEleves => const EspacesElevesScreen(),
            _Rubrique.assistant => const AssistantIa(),
          },
        ),
      ],
    );
  }
}

/// Les comptes du personnel — ouverture, modification, désactivation,
/// suppression. On y nomme quelqu'un à un POSTE, pas à un rôle de module :
/// c'est le poste qui décide des rôles à poser.
class _Comptes extends ConsumerStatefulWidget {
  const _Comptes();

  @override
  ConsumerState<_Comptes> createState() => _ComptesState();
}

class _ComptesState extends ConsumerState<_Comptes> {
  final _rechercheCtrl = TextEditingController();
  String _recherche = '';

  @override
  void dispose() {
    _rechercheCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final comptes = ref.watch(comptesProvider);
    final moi = ref.watch(profilCourantProvider).value;
    final monPoste = moi == null
        ? null
        : posteDepuisRoles(moi.roleScolarite, moi.roleLogistique);
    final sousMonAutorite = postesCreables[monPoste] ?? const <Poste>{};

    return comptes.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(
          'Comptes illisibles : $e',
          style: const TextStyle(color: AppColors.danger),
        ),
      ),
      data: (liste) {
        final filtres = liste.where(_correspond).toList();

        return ListView(
          children: [
            TextField(
              controller: _rechercheCtrl,
              decoration: InputDecoration(
                hintText: 'Rechercher un compte (nom, identifiant, poste)…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _recherche.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() {
                          _rechercheCtrl.clear();
                          _recherche = '';
                        }),
                      ),
              ),
              onChanged: (v) => setState(() => _recherche = v),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Comptes (${filtres.length})',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                if (sousMonAutorite.isNotEmpty)
                  FilledButton.icon(
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => const NouveauCompteDialog(),
                    ),
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                    label: const Text('Ouvrir un compte'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (filtres.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: Text(
                    'Aucun compte pour cette recherche.',
                    style: TextStyle(color: AppColors.inkMuted),
                  ),
                ),
              ),
            for (final compte in filtres) ...[
              _Carte(
                compte: compte,
                cestMoi: compte.id == moi?.id,
                sousMonAutorite: sousMonAutorite.contains(
                  posteDepuisRoles(compte.roleScolarite, compte.roleLogistique),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }

  bool _correspond(Profil compte) {
    if (_recherche.trim().isEmpty) return true;
    final poste = posteDepuisRoles(compte.roleScolarite, compte.roleLogistique);
    final champs = [
      compte.nomComplet,
      compte.matricule ?? '',
      compte.grade ?? '',
      compte.appellation(poste?.libelle),
    ].join(' ').toLowerCase();
    return champs.contains(_recherche.trim().toLowerCase());
  }
}

class _Carte extends ConsumerStatefulWidget {
  const _Carte({
    required this.compte,
    required this.cestMoi,
    required this.sousMonAutorite,
  });

  final Profil compte;
  final bool cestMoi;
  final bool sousMonAutorite;

  @override
  ConsumerState<_Carte> createState() => _CarteState();
}

class _CarteState extends ConsumerState<_Carte> {
  bool _enCours = false;

  @override
  Widget build(BuildContext context) {
    final compte = widget.compte;
    final poste = posteDepuisRoles(compte.roleScolarite, compte.roleLogistique);

    // Un compte dont le poste n'est pas reconnu — deux rôles qui ne
    // correspondent à aucun poste, ou aucun rôle du tout — n'appartenait à
    // l'autorité de personne : il était donc impossible à corriger comme à
    // supprimer. C'est précisément celui qu'il faut pouvoir reprendre en
    // main, et cela revient à qui ouvre les comptes.
    final orphelin = poste == null;
    // Deux permissions, et pas une seule. Se désactiver ou se supprimer
    // fermerait la porte derrière soi — cela reste interdit. Mais corriger son
    // nom, son grade, ou écrire « Commandant de l'école » sur son propre
    // compte ne met rien en péril, et jusqu'ici c'était impossible : le seul
    // administrateur de l'école n'avait personne pour le faire à sa place.
    final modifiable = widget.sousMonAutorite || orphelin;
    final revocable = modifiable && !widget.cestMoi;

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              (compte.actif ? AppColors.success : AppColors.inkMuted)
                  .withValues(alpha: 0.12),
          child: Icon(
            Icons.person_outline,
            color: compte.actif ? AppColors.success : AppColors.inkMuted,
          ),
        ),
        title: Text(
          compte.identiteComplete,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${compte.matricule ?? "sans identifiant"} · '
          '${compte.appellation(poste?.libelle)}',
        ),
        trailing: Wrap(
          spacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (compte.doitChangerMotDePasse)
              const _Pastille(
                libelle: 'Mot de passe à changer',
                couleur: AppColors.warning,
              ),
            _Pastille(
              libelle: compte.actif ? 'Actif' : 'Désactivé',
              couleur: compte.actif ? AppColors.blueDeep : AppColors.inkMuted,
            ),
            if (widget.cestMoi)
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Text(
                  'vous',
                  style: TextStyle(fontSize: 12, color: AppColors.inkMuted),
                ),
              ),
            if (modifiable) ...[
              IconButton(
                tooltip: 'Modifier',
                onPressed: _enCours
                    ? null
                    : () => showDialog(
                        context: context,
                        builder: (_) => ModifierCompteDialog(
                          compte: compte,
                          cestMoi: widget.cestMoi,
                        ),
                      ),
                icon: const Icon(Icons.edit_outlined),
              ),
              if (revocable) ...[
                IconButton(
                  tooltip: compte.actif ? 'Désactiver' : 'Réactiver',
                  onPressed: _enCours ? null : _basculerActivation,
                  icon: Icon(
                    compte.actif
                        ? Icons.block_outlined
                        : Icons.check_circle_outline,
                  ),
                ),
                IconButton(
                  tooltip: 'Supprimer',
                  onPressed: _enCours ? null : _confirmerSuppression,
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppColors.danger,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _basculerActivation() async {
    await _agir(
      () => ref
          .read(comptesRepositoryProvider)
          .changerActivation(widget.compte.id, !widget.compte.actif),
    );
  }

  Future<void> _confirmerSuppression() async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Supprimer le compte'),
        content: Text(
          "Le compte de ${widget.compte.identiteComplete} sera supprimé "
          "définitivement. Pour conserver la trace de ce qu'il a saisi, "
          "préférez le désactiver.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirme != true) return;
    await _agir(
      () => ref.read(comptesRepositoryProvider).supprimer(widget.compte.id),
    );
  }

  Future<void> _agir(Future<void> Function() action) async {
    final messager = ScaffoldMessenger.of(context);
    setState(() => _enCours = true);
    try {
      await action();
      ref.invalidate(comptesProvider);
    } catch (e) {
      messager.showSnackBar(
        SnackBar(
          content: Text('$e'.replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }
}

/// Badge de statut en pilule — fond teinté, texte plein.
class _Pastille extends StatelessWidget {
  const _Pastille({required this.libelle, required this.couleur});

  final String libelle;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        libelle,
        style: TextStyle(
          color: couleur,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
