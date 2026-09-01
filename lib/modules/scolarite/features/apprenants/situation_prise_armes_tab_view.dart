import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sig_ensoa/core/erreurs.dart';
import 'package:sig_ensoa/core/theme.dart' hide AlertLevel, AlertLevelColor;
import '../../models/absence.dart';
import '../../models/apprenant.dart';
import '../../models/classe.dart';
import '../../models/consultation_medicale.dart';
import '../../models/division.dart';
import '../../models/permission.dart';
import '../../shared/widgets/common.dart';
import '../matieres/providers/matieres_providers.dart';
import 'portee_promotion.dart';
import 'providers/absences_providers.dart';
import 'providers/apprenants_providers.dart';
import 'providers/consultations_medicales_providers.dart';
import 'providers/permissions_providers.dart';

enum _Categorie {
  present,
  permissionnaire,
  consultant,
  reposMedical,
  hospitalise,
  absent,
}

extension _CategorieStyle on _Categorie {
  String get label => switch (this) {
    _Categorie.present => 'Présents',
    _Categorie.permissionnaire => 'Permissionnaires',
    _Categorie.consultant => 'Consultants',
    _Categorie.reposMedical => 'Repos médical',
    _Categorie.hospitalise => 'Hospitalisés',
    _Categorie.absent => 'Absents',
  };

  IconData get icone => switch (this) {
    _Categorie.present => Icons.check_circle_outline,
    _Categorie.permissionnaire => Icons.assignment_turned_in_outlined,
    _Categorie.consultant => Icons.medical_services_outlined,
    _Categorie.reposMedical => Icons.hotel_outlined,
    _Categorie.hospitalise => Icons.local_hospital_outlined,
    _Categorie.absent => Icons.event_busy_outlined,
  };

  Color get couleur => switch (this) {
    _Categorie.present => AppColors.success,
    _Categorie.permissionnaire => AppColors.blueDeep,
    _Categorie.consultant => AppColors.blue,
    _Categorie.reposMedical => AppColors.blueBright,
    _Categorie.hospitalise => AppColors.danger,
    _Categorie.absent => AppColors.warning,
  };
}

/// Détermine la catégorie d'un apprenant pour la journée en cours, par
/// ordre de priorité : hospitalisé > repos médical > consultant >
/// permissionnaire > absent > présent (un même apprenant ne peut apparaître
/// que dans une seule catégorie, même si plusieurs événements se
/// chevauchent).
_Categorie _categorieDuJour({
  required String apprenantId,
  required List<Permission> permissions,
  required List<Absence> absences,
  required List<ConsultationMedicale> consultations,
}) {
  final aujourdhui = DateTime.now();
  final jour = DateTime(aujourdhui.year, aujourdhui.month, aujourdhui.day);

  final consultationsApprenant = consultations.where(
    (c) => c.apprenantId == apprenantId,
  );
  final consultationsDuJour = consultationsApprenant.where(
    (c) => _memeJour(c.dateSouhaitee, jour),
  );
  if (consultationsDuJour.any(
    (c) => c.hospitalisationInterne || c.hospitalisationExterne,
  )) {
    return _Categorie.hospitalise;
  }
  // Un repos médical court à partir du jour de la consultation qui l'a
  // délivré : tant qu'il n'est pas écoulé, l'apprenant n'est pas sur les
  // rangs, même si la consultation date de plusieurs jours.
  if (consultationsApprenant.any((c) => _enReposMedical(c, jour))) {
    return _Categorie.reposMedical;
  }
  if (consultationsDuJour.isNotEmpty) {
    return _Categorie.consultant;
  }
  if (permissions.any(
    (p) => p.apprenantId == apprenantId && p.statut == PermissionStatut.enCours,
  )) {
    return _Categorie.permissionnaire;
  }
  final estAbsent = absences.any((a) {
    if (a.apprenantId != apprenantId) return false;
    if (a.dateDebut.isAfter(jour)) return false;
    return a.dateFin == null || !a.dateFin!.isBefore(jour);
  });
  if (estAbsent) return _Categorie.absent;
  return _Categorie.present;
}

bool _memeJour(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Le repos délivré par le médecin couvre `joursRepos` jours à compter du
/// jour de la consultation, celui-ci compris — un repos de 3 jours prescrit
/// lundi court donc jusqu'à mercredi inclus.
bool _enReposMedical(ConsultationMedicale consultation, DateTime jour) {
  final jours = consultation.joursRepos;
  if (jours == null || jours <= 0) return false;
  final debut = DateTime(
    consultation.dateSouhaitee.year,
    consultation.dateSouhaitee.month,
    consultation.dateSouhaitee.day,
  );
  final ecart = jour.difference(debut).inDays;
  return ecart >= 0 && ecart < jours;
}

/// Situation de Prise d'Armes (SPA) — effectif du jour ventilé par
/// catégorie (présents, permissionnaires, consultants, repos médical,
/// hospitalisés, absents), calculée à partir des Permissions/Absences/
/// Consultations médicales déjà enregistrées, sans nouvelle saisie. Les
/// repos médicaux se déduisent des jours de repos prescrits par le médecin
/// en fin de consultation : leur bénéficiaire n'est pas attendu sur les
/// rangs tant que le repos court. Toujours relative à aujourd'hui.
class SituationPriseArmesTabView extends ConsumerWidget {
  const SituationPriseArmesTabView({
    super.key,
    required this.division,
    required this.classe,
    this.classesRetenues,
  });

  final Division division;
  final Classe? classe;

  /// Phases d'une promotion sélectionnée sans phase précise, nul sinon.
  final Set<String>? classesRetenues;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classe = this.classe;
    final portee = classe == null ? classesRetenues : null;
    final apprenantsAsync =
        (classe != null
                ? ref.watch(apprenantsByClasseProvider(classe.id))
                : ref.watch(apprenantsByDivisionProvider(division.id)))
            .dansLesClasses(portee, (a) => a.classeId);
    final permissionsAsync =
        (classe != null
                ? ref.watch(permissionsByClasseProvider(classe.id))
                : ref.watch(permissionsByDivisionProvider(division.id)))
            .dansLesClasses(portee, (p) => p.classeId);
    final absencesAsync =
        (classe != null
                ? ref.watch(absencesByClasseProvider(classe.id))
                : ref.watch(absencesByDivisionProvider(division.id)))
            .dansLesClasses(portee, (a) => a.classeId);
    final consultationsAsync =
        (classe != null
                ? ref.watch(consultationsMedicalesByClasseProvider(classe.id))
                : ref.watch(
                    consultationsMedicalesByDivisionProvider(division.id),
                  ))
            .dansLesClasses(portee, (c) => c.classeId);
    // Sous "Toutes phases / stages", l'effectif mélange les classes : on
    // rappelle celle de chaque apprenant entre parenthèses.
    final classesById = classe != null
        ? const <String, Classe>{}
        : <String, Classe>{
            for (final c
                in ref.watch(classesListProvider).value ?? const <Classe>[])
              c.id: c,
          };

    final loading =
        apprenantsAsync.isLoading ||
        permissionsAsync.isLoading ||
        absencesAsync.isLoading ||
        consultationsAsync.isLoading;
    final error =
        apprenantsAsync.error ??
        permissionsAsync.error ??
        absencesAsync.error ??
        consultationsAsync.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Situation de Prise d\'Armes'),
        const SizedBox(height: 4),
        Text(
          'Effectif du jour — ${_dateDuJour()}',
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
                  apprenants: apprenantsAsync.value ?? const [],
                  permissions: permissionsAsync.value ?? const [],
                  absences: absencesAsync.value ?? const [],
                  consultations: consultationsAsync.value ?? const [],
                  classesById: classesById,
                ),
        ),
      ],
    );
  }

  static String _dateDuJour() {
    const jours = [
      'lundi',
      'mardi',
      'mercredi',
      'jeudi',
      'vendredi',
      'samedi',
      'dimanche',
    ];
    const mois = [
      'janvier',
      'février',
      'mars',
      'avril',
      'mai',
      'juin',
      'juillet',
      'août',
      'septembre',
      'octobre',
      'novembre',
      'décembre',
    ];
    final now = DateTime.now();
    final jour = jours[now.weekday - 1];
    return '$jour ${now.day} ${mois[now.month - 1]} ${now.year}';
  }
}

class _Contenu extends StatefulWidget {
  const _Contenu({
    required this.apprenants,
    required this.permissions,
    required this.absences,
    required this.consultations,
    required this.classesById,
  });

  final List<Apprenant> apprenants;
  final List<Permission> permissions;
  final List<Absence> absences;
  final List<ConsultationMedicale> consultations;

  /// Vide quand une classe/stage précis(e) est déjà sélectionné(e) — la
  /// provenance n'est alors plus ambiguë.
  final Map<String, Classe> classesById;

  @override
  State<_Contenu> createState() => _ContenuState();
}

class _ContenuState extends State<_Contenu> {
  _Categorie? _expanded;

  @override
  Widget build(BuildContext context) {
    if (widget.apprenants.isEmpty) {
      return const EmptyState(
        message: 'Aucun apprenant pour cette phase ou ce stage.',
        icon: Icons.groups_outlined,
      );
    }

    final parCategorie = <_Categorie, List<Apprenant>>{
      for (final c in _Categorie.values) c: [],
    };
    for (final apprenant in widget.apprenants) {
      final categorie = _categorieDuJour(
        apprenantId: apprenant.id,
        permissions: widget.permissions,
        absences: widget.absences,
        consultations: widget.consultations,
      );
      parCategorie[categorie]!.add(apprenant);
    }

    // Les cartes se partagent toute la largeur disponible : autant de
    // colonnes que la largeur le permet (une par catégorie, plus
    // l'effectif total, quand l'écran est assez large), jamais plus
    // étroites que [largeurMinimale].
    const espacement = 12.0;
    const largeurMinimale = 150.0;
    final nbCartes = _Categorie.values.length + 1;

    return LayoutBuilder(
      builder: (context, constraints) {
        final colonnes =
            ((constraints.maxWidth + espacement) ~/
                    (largeurMinimale + espacement))
                .clamp(1, nbCartes);
        final largeur =
            (constraints.maxWidth - espacement * (colonnes - 1)) / colonnes;

        return SingleChildScrollView(
          child: Wrap(
            spacing: espacement,
            runSpacing: espacement,
            children: [
              _EffectifTotalCard(
                total: widget.apprenants.length,
                largeur: largeur,
              ),
              for (final categorie in _Categorie.values)
                _CategorieCard(
                  categorie: categorie,
                  apprenants: parCategorie[categorie]!,
                  largeur: largeur,
                  libelle: _libelleApprenant,
                  expanded: _expanded == categorie,
                  onTap: () => setState(
                    () => _expanded = _expanded == categorie ? null : categorie,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Nom de l'apprenant, suivi de sa classe/stage entre parenthèses quand
  /// l'effectif affiché en mélange plusieurs.
  String _libelleApprenant(Apprenant apprenant) {
    final classe = widget.classesById[apprenant.classeId];
    if (classe == null) return apprenant.nomComplet;
    return '${apprenant.nomComplet} (${classe.nom})';
  }
}

class _EffectifTotalCard extends StatelessWidget {
  const _EffectifTotalCard({required this.total, required this.largeur});

  final int total;
  final double largeur;

  @override
  Widget build(BuildContext context) {
    // Même gabarit qu'une carte de catégorie — icône dans une pastille de
    // même taille et bordure de la couleur du fond — pour que les deux
    // types de cartes s'alignent exactement sur une rangée.
    return Container(
      width: largeur,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.navy),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.groups_outlined,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '$total',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Effectif total',
            style: TextStyle(color: AppColors.blueSoft, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _CategorieCard extends StatelessWidget {
  const _CategorieCard({
    required this.categorie,
    required this.apprenants,
    required this.largeur,
    required this.libelle,
    required this.expanded,
    required this.onTap,
  });

  final _Categorie categorie;
  final List<Apprenant> apprenants;
  final double largeur;
  final String Function(Apprenant) libelle;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
        side: BorderSide(
          color: expanded ? categorie.couleur : AppColors.border,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: apprenants.isEmpty ? null : onTap,
        child: Container(
          width: largeur,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: categorie.couleur.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      categorie.icone,
                      color: categorie.couleur,
                      size: 22,
                    ),
                  ),
                  if (apprenants.isNotEmpty)
                    Icon(
                      expanded ? Icons.expand_less : Icons.expand_more,
                      color: AppColors.inkMuted,
                      size: 20,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                '${apprenants.length}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                categorie.label,
                style: const TextStyle(color: AppColors.inkMuted, fontSize: 13),
              ),
              if (expanded) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 8),
                for (final apprenant in apprenants)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      libelle(apprenant),
                      style: const TextStyle(fontSize: 13),
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
