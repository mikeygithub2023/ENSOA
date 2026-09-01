import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sig_ensoa/core/erreurs.dart';
import 'package:sig_ensoa/core/theme.dart' hide AlertLevel, AlertLevelColor;
import '../../models/apprenant.dart';
import '../../models/classe.dart';
import '../../models/consultation_medicale.dart';
import '../../models/controle.dart';
import '../../models/note.dart';
import '../../models/sous_module.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/graphe_barres.dart';
import '../../shared/widgets/ligne_cartes.dart';
import '../matieres/providers/matieres_providers.dart';
import 'moyennes.dart';
import 'providers/absences_providers.dart';
import 'providers/apprenants_providers.dart';
import 'providers/consultations_medicales_providers.dart';
import 'providers/controles_providers.dart';
import 'providers/permissions_providers.dart';
import 'providers/sous_modules_providers.dart';

/// Statistiques personnelles d'un apprenant : sa moyenne, son rang dans la
/// promotion, ce qui l'a tenu éloigné du rang.
///
/// Le rang est ce que la fiche seule ne peut pas dire : une moyenne de 12
/// ne veut rien dire tant qu'on ignore où elle situe l'apprenant parmi ses
/// camarades. Il est donc calculé en regard de toute la classe.
///
/// Les moyennes suivent la règle du bulletin (voir `moyennes.dart`) : une
/// évaluation sans note est « non classé », jamais un zéro.
class StatistiquesApprenantSection extends ConsumerWidget {
  const StatistiquesApprenantSection({
    super.key,
    required this.apprenant,
    required this.classe,
  });

  final Apprenant apprenant;
  final Classe classe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controlesAsync = ref.watch(controlesByClasseProvider(classe.id));
    final notesClasseAsync = ref.watch(notesByClasseProvider(classe.id));
    final camaradesAsync = ref.watch(apprenantsByClasseProvider(classe.id));
    final matiereModulesAsync = ref.watch(matiereModulesProvider);
    final sousModulesAsync = ref.watch(sousModulesByClasseProvider(classe.id));
    final absencesAsync = ref.watch(absencesByApprenantProvider(apprenant.id));
    final permissionsAsync = ref.watch(
      permissionsByApprenantProvider(apprenant.id),
    );
    final consultationsAsync = ref.watch(
      consultationsMedicalesByApprenantProvider(apprenant.id),
    );

    final chargements = [
      controlesAsync,
      notesClasseAsync,
      camaradesAsync,
      matiereModulesAsync,
      sousModulesAsync,
      absencesAsync,
      permissionsAsync,
      consultationsAsync,
    ];
    if (chargements.any((a) => a.isLoading)) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final error = chargements
        .map((a) => a.error)
        .firstWhere((e) => e != null, orElse: () => null);
    if (error != null) {
      return EmptyState(
        message: 'Erreur de chargement : ${messageErreur(error)}',
        icon: Icons.error_outline,
      );
    }

    final controles = controlesAsync.value ?? const [];
    final notesClasse = notesClasseAsync.value ?? const <Note>[];
    final camarades = camaradesAsync.value ?? const <Apprenant>[];
    final coefMatiereById = coefficientsMatieres(
      matiereModulesAsync.value ?? const [],
      classe.id,
    );
    final sousModules = sousModulesAsync.value ?? const <SousModule>[];
    final consultations = consultationsAsync.value ?? const [];

    final notesParApprenant = <String, List<Note>>{};
    for (final note in notesClasse) {
      notesParApprenant.putIfAbsent(note.apprenantId, () => []).add(note);
    }
    final mesNotes = notesParApprenant[apprenant.id] ?? const <Note>[];

    final maMoyenne = moyenneGenerale(
      controles: controles,
      notes: mesNotes,
      coefMatiereById: coefMatiereById,
      sousModules: sousModules,
    );

    // Le rang ne compte que les apprenants effectivement classés : un
    // camarade sans aucune note n'est ni devant ni derrière.
    final moyennesClasse = <num>[];
    for (final camarade in camarades) {
      final moyenne = moyenneGenerale(
        controles: controles,
        notes: notesParApprenant[camarade.id] ?? const [],
        coefMatiereById: coefMatiereById,
        sousModules: sousModules,
      );
      if (moyenne != null) moyennesClasse.add(moyenne);
    }
    moyennesClasse.sort((a, b) => b.compareTo(a));
    final rang = maMoyenne == null
        ? null
        : moyennesClasse.indexWhere((m) => m == maMoyenne) + 1;
    final moyennePromotion = moyennesClasse.isEmpty
        ? null
        : moyennesClasse.reduce((a, b) => a + b) / moyennesClasse.length;

    final joursRepos = consultations.fold<int>(
      0,
      (somme, c) => somme + (c.joursRepos ?? 0),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LigneCartes(
          cartes: [
            _Kpi(
              valeur: maMoyenne == null ? '—' : maMoyenne.toStringAsFixed(2),
              label: 'Moyenne générale',
              detail: maMoyenne == null
                  ? 'Non classé'
                  : moyennePromotion == null
                  ? null
                  : _ecartPromotion(maMoyenne, moyennePromotion),
              principal: true,
            ),
            _Kpi(
              valeur: rang == null ? '—' : '$rang${rang == 1 ? 'er' : 'e'}',
              label: 'Rang dans la promotion',
              detail: moyennesClasse.isEmpty
                  ? 'Aucun classé'
                  : 'sur ${moyennesClasse.length} classé(s)',
              couleur: AppColors.blueDeep,
            ),
            _Kpi(
              valeur:
                  '${_nombreClassees(controles, mesNotes, coefMatiereById, sousModules)}'
                  '/${controles.length}',
              label: 'Évaluations classées',
              detail: 'sur celles enregistrées',
              couleur: AppColors.blue,
            ),
            _Kpi(
              valeur: '${(absencesAsync.value ?? const []).length}',
              label: 'Absences',
              couleur: AppColors.warning,
            ),
            _Kpi(
              valeur: '${(permissionsAsync.value ?? const []).length}',
              label: 'Permissions',
              couleur: AppColors.blueDeep,
            ),
            _Kpi(
              valeur: '${consultations.length}',
              label: 'Consultations',
              detail: consultations.isEmpty
                  ? null
                  : '${consultations.where((c) => c.type == ConsultationType.urgence).length} urgence(s)',
              couleur: AppColors.blue,
            ),
            _Kpi(
              valeur: '$joursRepos',
              label: 'Jours de repos médical',
              couleur: joursRepos == 0 ? AppColors.inkMuted : AppColors.danger,
            ),
          ],
        ),
        const SizedBox(height: 16),
        GrapheBarres(
          titre: 'Notes par évaluation',
          sousTitre:
              'La note de l\'apprenant en regard de la moyenne de la '
              'promotion — en rouge, ce qui est sous la moyenne de 10.',
          couleur: AppColors.blue,
          messageVide:
              'Aucune note enregistrée pour cet apprenant. Les évaluations '
              'où il n\'est pas classé ne sont pas représentées.',
          barres: _notesParEvaluation(
            controles,
            mesNotes,
            notesParApprenant,
            camarades,
            coefMatiereById,
            sousModules,
          ),
        ),
      ],
    );
  }

  /// Écart à la moyenne de la promotion, tel qu'on le commente à l'oral.
  String _ecartPromotion(num moyenne, num promotion) {
    final ecart = moyenne - promotion;
    if (ecart.abs() < 0.005) return 'dans la moyenne de la promotion';
    final signe = ecart > 0 ? '+' : '−';
    return '$signe${ecart.abs().toStringAsFixed(2)} / promotion';
  }

  int _nombreClassees(
    List<dynamic> controles,
    List<Note> mesNotes,
    Map<String, num> coefMatiereById,
    List<SousModule> sousModules,
  ) {
    var compte = 0;
    for (final controle in controles) {
      if (noteAuControle(
            controle,
            mesNotes,
            coefMatiereById,
            sousModules: sousModules,
          ) !=
          null) {
        compte++;
      }
    }
    return compte;
  }

  /// Une barre par évaluation où l'apprenant est classé, avec la moyenne de
  /// la promotion en commentaire — c'est la comparaison qui fait décider,
  /// pas la note seule.
  List<BarreDonnee> _notesParEvaluation(
    List<dynamic> controles,
    List<Note> mesNotes,
    Map<String, List<Note>> notesParApprenant,
    List<Apprenant> camarades,
    Map<String, num> coefMatiereById,
    List<SousModule> sousModules,
  ) {
    final barres = <BarreDonnee>[];
    for (final controle in controles) {
      final maNote = noteAuControle(
        controle,
        mesNotes,
        coefMatiereById,
        sousModules: sousModules,
      );
      if (maNote == null) continue;

      final valeurs = <num>[];
      for (final camarade in camarades) {
        final note = noteAuControle(
          controle,
          notesParApprenant[camarade.id] ?? const [],
          coefMatiereById,
          sousModules: sousModules,
        );
        if (note != null) valeurs.add(note);
      }
      final moyenne = valeurs.isEmpty
          ? null
          : valeurs.reduce((a, b) => a + b) / valeurs.length;

      barres.add(
        BarreDonnee(
          label: (controle as Controle).libelleQualifie,
          valeur: maNote,
          detail: moyenne == null
              ? null
              : 'promo ${moyenne.toStringAsFixed(2)}',
          couleur: maNote >= 10 ? AppColors.blue : AppColors.danger,
        ),
      );
    }
    return barres;
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
