import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:sig_ensoa/core/erreurs.dart';
import 'package:sig_ensoa/core/theme.dart' hide AlertLevel, AlertLevelColor;
import '../../models/apprenant.dart';
import '../../models/classe.dart';
import '../../models/cours.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/ligne_cartes.dart';
import '../apprenants/providers/apprenants_providers.dart';
import 'data/cours_repository.dart';
import 'providers/cours_providers.dart';

final _dateFmt = DateFormat('dd/MM/yyyy à HH:mm');

/// Le travail des élèves sur un devoir : qui a composé, avec quel résultat,
/// et qui ne l'a pas encore fait.
///
/// Ces notes ne sont pas des notes de bulletin — elles mesurent
/// l'assimilation d'un cours, elles ne sanctionnent pas. L'écran le dit,
/// pour qu'aucun instructeur ne les attende dans une moyenne.
Future<void> showResultatsDevoirDialog(
  BuildContext context, {
  required Cours devoir,
  required Classe classe,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.all(24),
      child: _ResultatsDevoirDialog(devoir: devoir, classe: classe),
    ),
  );
}

class _ResultatsDevoirDialog extends ConsumerWidget {
  const _ResultatsDevoirDialog({required this.devoir, required this.classe});

  final Cours devoir;
  final Classe classe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenSize = MediaQuery.of(context).size;
    final width = screenSize.width - 48 < 820 ? screenSize.width - 48 : 820.0;
    final height = screenSize.height - 48 < 760
        ? screenSize.height - 48
        : 760.0;

    final apprenantsAsync = ref.watch(apprenantsByClasseProvider(classe.id));
    final resultatsAsync = ref.watch(resultatsDevoirProvider(devoir.id));

    return SizedBox(
      width: width,
      height: height,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Résultats — ${devoir.titre}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      Text(
                        '${classe.nom} (${classe.type.label})',
                        style: const TextStyle(
                          color: AppColors.inkMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: _Avertissement(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: _Publication(devoir: devoir, classe: classe),
          ),
          Expanded(
            child: apprenantsAsync.when(
              data: (apprenants) => resultatsAsync.when(
                data: (resultats) =>
                    _Contenu(apprenants: apprenants, resultats: resultats),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => EmptyState(
                  message: 'Erreur de chargement : ${messageErreur(error)}',
                  icon: Icons.error_outline,
                ),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => EmptyState(
                message: 'Erreur de chargement : ${messageErreur(error)}',
                icon: Icons.error_outline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Avertissement extends StatelessWidget {
  const _Avertissement();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.blueMist,
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: AppColors.blueDeep),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Ces notes n\'entrent pas dans les moyennes du bulletin. Un QCM '
              'mesure l\'assimilation d\'un cours ; seuls les modules, '
              'contrôles continus et examens sont pris en compte.',
              style: TextStyle(color: AppColors.blueDeep, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _Contenu extends StatelessWidget {
  const _Contenu({required this.apprenants, required this.resultats});

  final List<Apprenant> apprenants;
  final List<ResultatDevoir> resultats;

  @override
  Widget build(BuildContext context) {
    if (apprenants.isEmpty) {
      return const EmptyState(
        message: 'Aucun apprenant dans cette phase ou ce stage.',
        icon: Icons.groups_outlined,
      );
    }

    final parApprenant = {for (final r in resultats) r.apprenantId: r};

    // Une copie existe dès que l'élève a ouvert le sujet — c'est ainsi que le
    // chronomètre s'arme côté serveur (migration 047). Seule celle qui porte
    // une date de remise est composée ; les autres sont en cours.
    bool aRemis(String id) => parApprenant[id]?.terminee != null;
    bool aOuvert(String id) => parApprenant.containsKey(id) && !aRemis(id);

    // Les copies remises en tête, de la meilleure à la plus faible : c'est
    // le classement qu'on cherche. Ceux qui n'ont pas composé ferment la
    // marche, par ordre alphabétique.
    final composes = apprenants.where((a) => aRemis(a.id)).toList()
      ..sort(
        (a, b) =>
            parApprenant[b.id]!.sur20.compareTo(parApprenant[a.id]!.sur20),
      );
    final enCours = apprenants.where((a) => aOuvert(a.id)).toList()
      ..sort((a, b) => a.nomComplet.compareTo(b.nomComplet));
    final absents =
        apprenants.where((a) => !parApprenant.containsKey(a.id)).toList()
          ..sort((a, b) => a.nomComplet.compareTo(b.nomComplet));

    final notes = composes.map((a) => parApprenant[a.id]!.sur20).toList();
    final moyenne = notes.isEmpty
        ? null
        : notes.reduce((a, b) => a + b) / notes.length;
    final reussites = notes.where((n) => n >= 10).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      children: [
        LigneCartes(
          cartes: [
            _Kpi(
              valeur: '${composes.length}/${apprenants.length}',
              label: 'Copies remises',
              principal: true,
            ),
            _Kpi(
              valeur: moyenne == null ? '—' : moyenne.toStringAsFixed(2),
              label: 'Moyenne de la promotion',
              detail: 'sur 20',
            ),
            _Kpi(
              valeur: notes.isEmpty
                  ? '—'
                  : '${(reussites * 100 / notes.length).round()} %',
              label: 'Au-dessus de 10',
              couleur: AppColors.success,
            ),
            _Kpi(
              valeur: '${absents.length}',
              label: 'N\'ont pas composé',
              couleur: absents.isEmpty ? AppColors.inkMuted : AppColors.warning,
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (composes.isNotEmpty) ...[
          const _Entete('COPIES REMISES'),
          for (var i = 0; i < composes.length; i++)
            _LigneResultat(
              rang: i + 1,
              apprenant: composes[i],
              resultat: parApprenant[composes[i].id],
            ),
          const SizedBox(height: 20),
        ],
        if (enCours.isNotEmpty) ...[
          const _Entete('COMPOSITION EN COURS'),
          for (final apprenant in enCours)
            _LigneResultat(
              rang: null,
              apprenant: apprenant,
              resultat: parApprenant[apprenant.id],
            ),
          const SizedBox(height: 20),
        ],
        if (absents.isNotEmpty) ...[
          const _Entete('N\'ONT PAS COMPOSÉ'),
          for (final apprenant in absents)
            _LigneResultat(rang: null, apprenant: apprenant, resultat: null),
        ],
      ],
    );
  }
}

class _Entete extends StatelessWidget {
  const _Entete(this.texte);

  final String texte;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        texte,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          color: AppColors.ink,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _LigneResultat extends StatelessWidget {
  const _LigneResultat({
    required this.rang,
    required this.apprenant,
    required this.resultat,
  });

  final int? rang;
  final Apprenant apprenant;
  final ResultatDevoir? resultat;

  @override
  Widget build(BuildContext context) {
    final resultat = this.resultat;
    final couleur = resultat == null
        ? AppColors.inkMuted
        : (resultat.sur20 >= 10 ? AppColors.success : AppColors.danger);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
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
              SizedBox(
                width: 36,
                child: Text(
                  rang == null ? '—' : '$rang',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.inkMuted,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      apprenant.nomComplet,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (resultat?.terminee != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Remis le ${_dateFmt.format(resultat!.terminee!)}',
                        style: const TextStyle(
                          color: AppColors.inkMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    // Le dépassement est signalé, pas sanctionné : la copie
                    // est notée comme les autres, c'est à l'instructeur
                    // d'apprécier ce qui s'est passé.
                    if (resultat?.horsDelai ?? false) ...[
                      const SizedBox(height: 4),
                      const StatusChip(
                        label: 'Remise hors délai',
                        level: AlertLevel.critical,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 16),
              if (resultat == null)
                const StatusChip(
                  label: 'Non composé',
                  level: AlertLevel.warning,
                )
              // Sujet ouvert, copie pas encore remise : il n'y a pas de note
              // à montrer, et « 0 / 0 » en donnerait une fausse.
              else if (resultat.enCours)
                const StatusChip(label: 'En cours', level: AlertLevel.info)
              else ...[
                Text(
                  '${resultat.note} / ${resultat.bareme}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkMuted,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 92,
                  child: Text(
                    '${resultat.sur20.toStringAsFixed(2)} / 20',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: couleur,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({
    required this.valeur,
    required this.label,
    this.detail,
    this.couleur,
    this.principal = false,
  });

  final String valeur;
  final String label;
  final String? detail;
  final Color? couleur;
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
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: principal ? Colors.white : (couleur ?? AppColors.ink),
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
          if (detail != null) ...[
            const SizedBox(height: 2),
            Text(
              detail!,
              style: TextStyle(
                color: principal ? AppColors.blueSoft : AppColors.inkMuted,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Interrupteur de publication.
///
/// Tant qu'il est fermé, aucun élève ne connaît sa note — c'est ce qui
/// empêche les premiers à composer de renseigner les suivants. Une fois tous
/// passés, l'instructeur ouvre et chacun voit la sienne.
class _Publication extends ConsumerStatefulWidget {
  const _Publication({required this.devoir, required this.classe});

  final Cours devoir;
  final Classe classe;

  @override
  ConsumerState<_Publication> createState() => _PublicationState();
}

class _PublicationState extends ConsumerState<_Publication> {
  late bool _publies = widget.devoir.resultatsPublies;
  bool _enCours = false;

  Future<void> _basculer(bool valeur) async {
    setState(() {
      _publies = valeur;
      _enCours = true;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(coursRepositoryProvider)
          .publierResultats(widget.devoir.id, publies: valeur);
      ref.invalidate(coursByClasseProvider(widget.classe.id));
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            valeur
                ? 'Résultats publiés : chaque élève voit désormais sa note.'
                : 'Résultats retirés : les notes redeviennent invisibles.',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      // Le drapeau revient à son état réel : l'interrupteur ne doit pas
      // laisser croire à une publication qui n'a pas eu lieu.
      if (mounted) setState(() => _publies = !valeur);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Erreur : ${messageErreur(e)}'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppRadii.control),
        border: Border.all(
          color: _publies ? AppColors.success : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _publies ? 'Résultats publiés' : 'Résultats non publiés',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _publies ? AppColors.success : AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _publies
                      ? 'Chaque élève voit sa note dans son espace.'
                      : 'Les notes restent invisibles aux élèves — publiez '
                            'une fois que tous ont composé.',
                  style: const TextStyle(
                    color: AppColors.inkMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(value: _publies, onChanged: _enCours ? null : _basculer),
        ],
      ),
    );
  }
}
