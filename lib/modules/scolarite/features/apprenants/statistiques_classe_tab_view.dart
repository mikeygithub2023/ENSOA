import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sig_ensoa/core/erreurs.dart';
import 'package:sig_ensoa/core/theme.dart' hide AlertLevel, AlertLevelColor;
import '../../models/absence.dart';
import '../../models/apprenant.dart';
import '../../models/classe.dart';
import '../../models/consultation_medicale.dart';
import '../../models/controle.dart';
import '../../models/note.dart';
import '../../models/permission.dart';
import '../../models/sous_module.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/graphe_barres.dart';
import '../../shared/widgets/ligne_cartes.dart';
import '../matieres/providers/matieres_providers.dart';
import 'bureaux.dart';
import 'moyennes.dart';
import 'providers/absences_providers.dart';
import 'providers/apprenants_providers.dart';
import 'providers/consultations_medicales_providers.dart';
import 'providers/controles_providers.dart';
import 'providers/permissions_providers.dart';
import 'providers/sous_modules_providers.dart';

/// Tranches de notes retenues pour lire la distribution d'une classe d'un
/// coup d'œil — bornes basses incluses, hautes exclues (sauf la dernière).
const _tranches = [
  (min: 16.0, max: 21.0, label: '16 et plus', couleur: AppColors.success),
  (min: 14.0, max: 16.0, label: '14 à 16', couleur: AppColors.success),
  (min: 12.0, max: 14.0, label: '12 à 14', couleur: AppColors.blue),
  (min: 10.0, max: 12.0, label: '10 à 12', couleur: AppColors.blueDeep),
  (min: 8.0, max: 10.0, label: '8 à 10', couleur: AppColors.warning),
  (min: 0.0, max: 8.0, label: 'Moins de 8', couleur: AppColors.danger),
];

/// Ce qu'une classe ou un stage donne à lire, selon le bureau qui regarde.
///
/// Quatre questions se posent au commandement : qui est là, comment la
/// promotion travaille, qui décroche, et ce qui la tient éloignée du rang
/// (absences, permissions, santé). Elles ne relèvent pas du même bureau, et
/// l'écran ne montre donc plus les quatre à tout le monde :
///
///  - l'**instruction** reçoit l'effectif et les **résultats** ;
///  - les **ressources humaines** reçoivent l'effectif, la **disponibilité**
///    et la **santé** — sans les notes, qui ne les regardent pas.
///
/// L'effectif figure dans les deux : il est la base de lecture de tout le
/// reste. Chaque bureau ne charge que ce qu'il montre.
///
/// Les moyennes suivent exactement la règle du bulletin (voir `moyennes.dart`)
/// — un apprenant sans note à une évaluation y est non classé, jamais compté
/// zéro. Elles portent en revanche sur **toutes** les évaluations saisies,
/// là où le bulletin se limite à celles cochées par l'administrateur : ici
/// on cherche l'état réel de la promotion, pas le document officiel.
class StatistiquesClasseTabView extends ConsumerWidget {
  const StatistiquesClasseTabView({
    super.key,
    required this.classe,
    required this.bureau,
  });

  final Classe classe;
  final Bureau bureau;

  bool get _instruction => bureau == Bureau.instruction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apprenantsAsync = ref.watch(apprenantsByClasseProvider(classe.id));
    // Un provider qu'on ne lit pas n'est pas chargé : les ressources humaines
    // n'ont pas à descendre toutes les notes de la phase pour afficher un
    // effectif, ni l'instruction toutes les consultations.
    final controlesAsync = _instruction
        ? ref.watch(controlesByClasseProvider(classe.id))
        : null;
    final notesAsync = _instruction
        ? ref.watch(notesByClasseProvider(classe.id))
        : null;
    final matiereModulesAsync = _instruction
        ? ref.watch(matiereModulesProvider)
        : null;
    final sousModulesAsync = _instruction
        ? ref.watch(sousModulesByClasseProvider(classe.id))
        : null;
    final absencesAsync = _instruction
        ? null
        : ref.watch(absencesByClasseProvider(classe.id));
    final permissionsAsync = _instruction
        ? null
        : ref.watch(permissionsByClasseProvider(classe.id));
    final consultationsAsync = _instruction
        ? null
        : ref.watch(consultationsMedicalesByClasseProvider(classe.id));

    final chargements = <AsyncValue<Object?>>[
      apprenantsAsync,
      ?controlesAsync,
      ?notesAsync,
      ?matiereModulesAsync,
      ?sousModulesAsync,
      ?absencesAsync,
      ?permissionsAsync,
      ?consultationsAsync,
    ];
    final loading = chargements.any((a) => a.isLoading);
    final error = chargements
        .map((a) => a.error)
        .firstWhere((e) => e != null, orElse: () => null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: _instruction
              ? 'Résultats — ${classe.nom}'
              : 'Statistiques générales — ${classe.nom}',
        ),
        const SizedBox(height: 4),
        Text(
          _instruction
              ? 'Établis sur l\'ensemble des évaluations saisies pour cette '
                    'phase ou ce stage.'
              : 'Établies sur l\'ensemble des données enregistrées pour cette '
                    'phase ou ce stage — hors notation, qui relève de '
                    'l\'instruction.',
          style: const TextStyle(color: AppColors.inkMuted, fontSize: 13),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : error != null
              ? EmptyState(
                  message: 'Erreur de chargement : ${messageErreur(error)}',
                  icon: Icons.error_outline,
                )
              : _Contenu(
                  bureau: bureau,
                  apprenants: apprenantsAsync.value ?? const [],
                  controles: controlesAsync?.value ?? const [],
                  notes: notesAsync?.value ?? const [],
                  coefMatiereById: coefficientsMatieres(
                    matiereModulesAsync?.value ?? const [],
                    classe.id,
                  ),
                  sousModules: sousModulesAsync?.value ?? const [],
                  absences: absencesAsync?.value ?? const [],
                  permissions: permissionsAsync?.value ?? const [],
                  consultations: consultationsAsync?.value ?? const [],
                ),
        ),
      ],
    );
  }
}

class _Contenu extends StatelessWidget {
  const _Contenu({
    required this.bureau,
    required this.apprenants,
    required this.controles,
    required this.notes,
    required this.coefMatiereById,
    required this.sousModules,
    required this.absences,
    required this.permissions,
    required this.consultations,
  });

  final Bureau bureau;
  final List<Apprenant> apprenants;
  final List<Controle> controles;
  final List<Note> notes;
  final Map<String, num> coefMatiereById;
  final List<SousModule> sousModules;
  final List<Absence> absences;
  final List<Permission> permissions;
  final List<ConsultationMedicale> consultations;

  @override
  Widget build(BuildContext context) {
    if (apprenants.isEmpty) {
      return const EmptyState(
        message: 'Aucun apprenant dans cette phase ou ce stage.',
        icon: Icons.groups_outlined,
      );
    }

    final notesParApprenant = <String, List<Note>>{};
    for (final note in notes) {
      notesParApprenant.putIfAbsent(note.apprenantId, () => []).add(note);
    }

    // Un apprenant non classé (aucune note nulle part) est écarté des
    // moyennes, jamais compté zéro — mais on le compte à part, car c'est
    // précisément lui qu'il faut aller chercher.
    final moyennes = <String, num>{};
    for (final apprenant in apprenants) {
      final moyenne = moyenneGenerale(
        controles: controles,
        notes: notesParApprenant[apprenant.id] ?? const [],
        coefMatiereById: coefMatiereById,
        sousModules: sousModules,
      );
      if (moyenne != null) moyennes[apprenant.id] = moyenne;
    }

    final classes = moyennes.values.toList()..sort();
    final moyenneClasse = classes.isEmpty
        ? null
        : classes.reduce((a, b) => a + b) / classes.length;
    final admis = classes.where((m) => m >= 10).length;
    final nonClasses = apprenants.length - moyennes.length;

    return ListView(
      children: [
        _Bloc(
          titre: 'Effectif',
          enfants: [
            LigneCartes(
              cartes: [
                _Kpi(
                  valeur: '${apprenants.length}',
                  label: 'Effectif inscrit',
                  principal: true,
                ),
                for (final statut in ApprenantStatut.values)
                  if (apprenants.any((a) => a.statut == statut))
                    _Kpi(
                      valeur:
                          '${apprenants.where((a) => a.statut == statut).length}',
                      label: statut.label,
                      couleur: statut == ApprenantStatut.actif
                          ? AppColors.success
                          : AppColors.warning,
                    ),
              ],
            ),
          ],
        ),
        if (bureau == Bureau.instruction)
          _Bloc(
            titre: 'Résultats',
            sousTitre:
                'Moyennes pondérées par les coefficients, sur les '
                '${controles.length} évaluation(s) saisie(s). Un apprenant sans '
                'note à une évaluation y est non classé, jamais compté zéro.',
            enfants: [
              LigneCartes(
                cartes: [
                  _Kpi(
                    valeur: moyenneClasse == null
                        ? '—'
                        : moyenneClasse.toStringAsFixed(2),
                    label: 'Moyenne de la promotion',
                    principal: true,
                  ),
                  _Kpi(
                    valeur: classes.isEmpty
                        ? '—'
                        : '${(admis * 100 / classes.length).round()} %',
                    label: 'Au-dessus de 10',
                    couleur: AppColors.success,
                  ),
                  _Kpi(
                    valeur: '${classes.length - admis}',
                    label: 'En dessous de 10',
                    couleur: AppColors.danger,
                  ),
                  _Kpi(
                    valeur: '$nonClasses',
                    label: 'Non classés',
                    couleur: nonClasses == 0
                        ? AppColors.inkMuted
                        : AppColors.warning,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              GrapheBarres(
                titre: 'Répartition de la promotion',
                sousTitre:
                    'Combien d\'apprenants dans chaque tranche de moyenne.',
                largeurLabel: 140,
                messageVide: 'Aucune moyenne calculable : aucune note saisie.',
                barres: [
                  for (final tranche in _tranches)
                    BarreDonnee(
                      label: tranche.label,
                      valeur: classes
                          .where((m) => m >= tranche.min && m < tranche.max)
                          .length,
                      detail: classes.isEmpty
                          ? null
                          : '${(classes.where((m) => m >= tranche.min && m < tranche.max).length * 100 / classes.length).round()} %',
                      couleur: tranche.couleur,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              GrapheBarres(
                titre: 'Moyenne par évaluation',
                sousTitre:
                    'Les évaluations les plus faibles en bas : c\'est là que '
                    'l\'instruction doit être reprise.',
                couleur: AppColors.blue,
                messageVide: 'Aucune évaluation enregistrée.',
                barres: _moyennesParControle(),
              ),
            ],
          ),
        if (bureau == Bureau.ressourcesHumaines) ...[
          _Bloc(
            titre: 'Disponibilité',
            sousTitre:
                'Ce qui tient un apprenant éloigné du rang, toutes périodes '
                'confondues.',
            enfants: [
              LigneCartes(
                cartes: [
                  _Kpi(
                    valeur: '${absences.length}',
                    label: 'Absences enregistrées',
                    couleur: AppColors.warning,
                  ),
                  _Kpi(
                    valeur: '${absences.where((a) => a.enCours).length}',
                    label: 'Absences en cours',
                    couleur: AppColors.danger,
                  ),
                  _Kpi(
                    valeur: '${permissions.length}',
                    label: 'Permissions accordées',
                    couleur: AppColors.blueDeep,
                  ),
                  _Kpi(
                    valeur: '$_joursDeRepos',
                    label: 'Jours de repos médical',
                    couleur: AppColors.blue,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              GrapheBarres(
                titre: 'Apprenants les plus absents',
                sousTitre:
                    'Nombre d\'absences enregistrées — les cas à convoquer.',
                couleur: AppColors.warning,
                messageVide: 'Aucune absence enregistrée.',
                barres: _classementAbsences(),
              ),
            ],
          ),
          _Bloc(
            titre: 'Santé',
            sousTitre:
                'Ce qui envoie les apprenants à l\'infirmerie — de quoi '
                'réorienter la préparation physique et la prévention.',
            enfants: [
              LigneCartes(
                cartes: [
                  _Kpi(
                    valeur: '${consultations.length}',
                    label: 'Consultations',
                    principal: true,
                  ),
                  _Kpi(
                    valeur:
                        '${consultations.where((c) => c.type == ConsultationType.urgence).length}',
                    label: 'Dont urgences',
                    couleur: AppColors.danger,
                  ),
                  _Kpi(
                    valeur:
                        '${consultations.where((c) => c.hospitalisationInterne || c.hospitalisationExterne).length}',
                    label: 'Hospitalisations',
                    couleur: AppColors.danger,
                  ),
                  _Kpi(
                    valeur: '${consultations.where((c) => c.exemption).length}',
                    label: 'Exemptions',
                    couleur: AppColors.warning,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              GrapheBarres(
                titre: 'Pathologies les plus fréquentes',
                sousTitre:
                    'Sur les consultations dont la pathologie a été renseignée.',
                couleur: AppColors.danger,
                messageVide:
                    'Aucune pathologie renseignée sur les consultations de '
                    'cette phase ou ce stage.',
                barres: _pathologies(),
              ),
            ],
          ),
        ],
      ],
    );
  }

  int get _joursDeRepos =>
      consultations.fold<int>(0, (somme, c) => somme + (c.joursRepos ?? 0));

  /// Moyenne de la promotion à chaque évaluation, la plus faible en dernier
  /// — les évaluations où personne n'est classé sont écartées : elles ne
  /// disent rien du niveau, seulement que rien n'a été saisi.
  List<BarreDonnee> _moyennesParControle() {
    final notesParApprenant = <String, List<Note>>{};
    for (final note in notes) {
      notesParApprenant.putIfAbsent(note.apprenantId, () => []).add(note);
    }

    final barres = <BarreDonnee>[];
    for (final controle in controles) {
      final valeurs = <num>[];
      for (final apprenant in apprenants) {
        final note = noteAuControle(
          controle,
          notesParApprenant[apprenant.id] ?? const [],
          coefMatiereById,
          sousModules: sousModules,
        );
        if (note != null) valeurs.add(note);
      }
      if (valeurs.isEmpty) continue;
      final moyenne = valeurs.reduce((a, b) => a + b) / valeurs.length;
      barres.add(
        BarreDonnee(
          label: controle.libelleQualifie,
          valeur: moyenne,
          detail: '${valeurs.length}/${apprenants.length} classés',
          couleur: moyenne >= 10 ? AppColors.blue : AppColors.danger,
        ),
      );
    }
    barres.sort((a, b) => b.valeur.compareTo(a.valeur));
    return barres;
  }

  /// Les dix apprenants comptant le plus d'absences — au-delà, la liste
  /// n'oriente plus aucune décision.
  List<BarreDonnee> _classementAbsences() {
    final comptes = <String, int>{};
    for (final absence in absences) {
      comptes[absence.apprenantId] = (comptes[absence.apprenantId] ?? 0) + 1;
    }
    final nomsById = {for (final a in apprenants) a.id: a.nomComplet};
    final entrees = comptes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return [
      for (final entree in entrees.take(10))
        BarreDonnee(
          label: nomsById[entree.key] ?? 'Apprenant inconnu',
          valeur: entree.value,
          detail: entree.value <= 1 ? 'absence' : 'absences',
        ),
    ];
  }

  List<BarreDonnee> _pathologies() {
    final comptes = <Pathologie, int>{};
    for (final consultation in consultations) {
      final pathologie = consultation.pathologie;
      if (pathologie == null) continue;
      comptes[pathologie] = (comptes[pathologie] ?? 0) + 1;
    }
    final total = comptes.values.fold<int>(0, (s, v) => s + v);
    final entrees = comptes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return [
      for (final entree in entrees)
        BarreDonnee(
          label: entree.key.label,
          valeur: entree.value,
          detail: '${(entree.value * 100 / total).round()} %',
        ),
    ];
  }
}

/// Un bloc thématique du tableau de bord, avec son titre et son propos.
class _Bloc extends StatelessWidget {
  const _Bloc({required this.titre, required this.enfants, this.sousTitre});

  final String titre;
  final String? sousTitre;
  final List<Widget> enfants;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titre.toUpperCase(),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
              fontSize: 13,
            ),
          ),
          if (sousTitre != null) ...[
            const SizedBox(height: 2),
            Text(
              sousTitre!,
              style: const TextStyle(color: AppColors.inkMuted, fontSize: 12),
            ),
          ],
          const SizedBox(height: 12),
          ...enfants,
        ],
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({
    required this.valeur,
    required this.label,
    this.couleur,
    this.principal = false,
  });

  final String valeur;
  final String label;
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
              fontSize: 22,
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
        ],
      ),
    );
  }
}
