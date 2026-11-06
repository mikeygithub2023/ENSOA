import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:sig_ensoa/core/chargement.dart';
import 'package:sig_ensoa/core/roles.dart';
import 'package:sig_ensoa/core/theme.dart';
import 'package:sig_ensoa/features/auth/providers/auth_providers.dart';
import 'package:sig_ensoa/shared/widgets/rubrique_a_onglets.dart';
import '../../data/models/oa.dart';
import '../../data/repositories/misc_providers.dart';
import '../../data/repositories/oa_providers.dart';
import '../../shared/widgets/skeleton.dart';
import '../../shared/widgets/widgets.dart';
import '../oa/oa_screen.dart';
import '../oa/tache_form_dialog.dart';
import 'tache_quotidienne_form_dialog.dart';
import 'taches_vue.dart';

/// La rubrique « Tâches » du menu : la liste, et les activités pour qui les
/// organise.
class TachesRubriqueScreen extends ConsumerWidget {
  const TachesRubriqueScreen({super.key, this.surActivites = false});

  /// Ouvrir directement sur les activités — ce que font les liens des tableaux
  /// de bord.
  final bool surActivites;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profil = ref.watch(profilCourantProvider).value;
    if (profil == null) return const SizedBox.shrink();

    final activites = profil.peut(Permission.gererActivites);
    return RubriqueAOnglets(
      titre: 'Tâches',
      ongletInitial: surActivites && activites ? 1 : 0,
      onglets: [
        ('Tâches', () => const TachesScreen()),
        if (activites) ('Activités', () => const OaScreen()),
      ],
    );
  }
}

/// Toutes les tâches au même endroit : celles que les activités confient aux
/// services, et les tâches quotidiennes de chacun.
///
/// À gauche, où l'on en est et ce qu'on veut voir ; à droite, la liste, ce qui
/// presse d'abord.
class TachesScreen extends ConsumerStatefulWidget {
  const TachesScreen({super.key});

  @override
  ConsumerState<TachesScreen> createState() => _TachesScreenState();
}

class _TachesScreenState extends ConsumerState<TachesScreen> {
  SegmentTaches _segment = SegmentTaches.toutes;
  DateTime? _jour;
  late DateTime _mois = DateTime(DateTime.now().year, DateTime.now().month);
  String _activite = cleToutesActivites;
  String _personne = cleToutLeMonde;
  final Set<String> _enCours = {};

  /// Qui organise les activités peut viser les tâches et les corriger.
  bool get _superviseur =>
      ref.read(profilCourantProvider).value?.peut(Permission.gererActivites) ??
      false;

  Future<void> _agir(String cle, Future<void> Function() action) async {
    setState(() => _enCours.add(cle));
    try {
      await action();
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _enCours.remove(cle));
    }
  }

  /// Une tâche quotidienne se coche et se décoche. Une tâche d'activité se
  /// déclare terminée, puis l'Officier Adjoint la vise.
  void Function()? _actionDuRond(LigneTache l) {
    final q = l.quotidienne;
    if (q != null) {
      return () => _agir(
        l.cle,
        () => ref
            .read(tachesQuotidiennesProvider.notifier)
            .cocher(q.id, faite: !q.faite),
      );
    }
    final t = l.deActivite!;
    if (t.statut == StatutTache.aFaire && (l.aMoi || _superviseur)) {
      return () => _terminer(l, t);
    }
    if (t.statut == StatutTache.terminee && _superviseur) {
      return () => _viser(l, t);
    }
    return null;
  }

  Future<void> _terminer(LigneTache l, TacheActivite t) async {
    final commentaire = TextEditingController();
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Marquer la tâche comme terminée'),
        content: TextField(
          controller: commentaire,
          decoration: const InputDecoration(
            labelText: 'Commentaire (optionnel)',
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    final texte = commentaire.text.trim();
    commentaire.dispose();
    if (confirme != true || !mounted) return;
    await _agir(l.cle, () async {
      await ref
          .read(tachesProvider.notifier)
          .marquerTerminee(t.id, commentaire: texte.isEmpty ? null : texte);
      _tracer('TACHE_TERMINEE', t.description);
    });
  }

  Future<void> _viser(LigneTache l, TacheActivite t) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Valider la tâche'),
        content: Text('« ${t.description} » a été déclarée terminée.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Valider'),
          ),
        ],
      ),
    );
    if (confirme != true || !mounted) return;
    await _agir(l.cle, () async {
      await ref.read(tachesProvider.notifier).valider(t.id);
      _tracer('TACHE_VALIDEE', t.description);
    });
  }

  void _tracer(String action, String cible) {
    final user = ref.read(profilCourantProvider).value;
    if (user == null) return;
    ref
        .read(auditProvider.notifier)
        .log(auteurId: user.id, action: action, cible: cible);
  }

  Future<void> _ajouter() async {
    final activites = ref
        .read(activitesProvider)
        .where(
          (a) =>
              a.statut == StatutActivite.planifiee ||
              a.statut == StatutActivite.enCours,
        )
        .toList();

    // Seul celui qui organise les activités a un choix à faire.
    if (!_superviseur) return _ajouterQuotidienne();

    final choix = await showDialog<Object>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Ajouter une tâche'),
        children: [
          ListTile(
            leading: const Icon(Icons.today_rounded),
            title: const Text('Tâche quotidienne'),
            subtitle: const Text('Pour vous, ou imputée à une personne'),
            onTap: () => Navigator.of(context).pop('quotidienne'),
          ),
          if (activites.isEmpty)
            const ListTile(
              enabled: false,
              leading: Icon(Icons.event_note_rounded),
              title: Text('Tâche liée à une activité'),
              subtitle: Text('Aucune activité planifiée ou en cours'),
            )
          else ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'Liée à une activité',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.inkMuted,
                ),
              ),
            ),
            for (final a in activites)
              ListTile(
                leading: const Icon(Icons.event_note_rounded),
                title: Text(a.titre),
                subtitle: Text(
                  DateFormat('dd/MM/yyyy').format(a.dateActivite.toLocal()),
                ),
                onTap: () => Navigator.of(context).pop(a),
              ),
          ],
        ],
      ),
    );
    if (!mounted) return;
    if (choix == 'quotidienne') return _ajouterQuotidienne();
    if (choix is Activite) {
      await showDialog(
        context: context,
        builder: (_) => TacheFormDialog(activite: choix),
      );
    }
  }

  Future<void> _ajouterQuotidienne() => showDialog(
    context: context,
    builder: (_) => TacheQuotidienneFormDialog(jour: _jour),
  );

  Future<void> _supprimer(LigneTache l) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la tâche'),
        content: Text('« ${l.titre} » sera supprimée.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirme != true || !mounted) return;
    await _agir(l.cle, () async {
      if (l.quotidienne != null) {
        await ref
            .read(tachesQuotidiennesProvider.notifier)
            .supprimer(l.quotidienne!.id);
      } else {
        await ref.read(tachesProvider.notifier).supprimer(l.deActivite!.id);
      }
    });
  }

  /// Ce que le menu « … » d'une ligne propose, selon ce qu'on a le droit de
  /// faire d'elle.
  List<PopupMenuEntry<VoidCallback>> _menuDe(
    LigneTache l,
    List<Activite> activites,
  ) {
    final moi = ref.read(profilCourantProvider).value;
    final q = l.quotidienne;
    if (q != null) {
      final peutEditer =
          q.creePar == moi?.id ||
          (moi?.peut(Permission.administrerPlateforme) ?? false);
      return [
        if (peutEditer) ...[
          PopupMenuItem(
            value: () => showDialog(
              context: context,
              builder: (_) => TacheQuotidienneFormDialog(tache: q),
            ),
            child: const Text('Modifier'),
          ),
          PopupMenuItem(
            value: () => _supprimer(l),
            child: const Text('Supprimer'),
          ),
        ],
      ];
    }
    final t = l.deActivite!;
    Activite? activite;
    for (final a in activites) {
      if (a.id == t.activiteId) activite = a;
    }
    final act = activite;
    return [
      if (act != null)
        PopupMenuItem(
          value: () => context.push('/logistique/activites/detail', extra: act),
          child: const Text("Ouvrir l'activité"),
        ),
      if (_superviseur && t.statut == StatutTache.aFaire && act != null) ...[
        PopupMenuItem(
          value: () => showDialog(
            context: context,
            builder: (_) => TacheFormDialog(activite: act, tache: t),
          ),
          child: const Text('Modifier'),
        ),
        PopupMenuItem(
          value: () => _supprimer(l),
          child: const Text('Supprimer'),
        ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final profil = ref.watch(profilCourantProvider).value;
    final activites = ref.watch(activitesProvider);
    final toutes = ref.watch(tachesProvider);
    final mes = ref.watch(mesTachesProvider);
    final quotidiennes = ref.watch(tachesQuotidiennesProvider);
    final charge = estCharge(ref, [
      'taches',
      'activites',
      'taches_quotidiennes',
    ]);

    // Le suivi d'ensemble est à ceux qui organisent ou qui encadrent ; les
    // autres n'ont que ce qui leur revient.
    final voitTout =
        (profil?.peut(Permission.gererActivites) ?? false) ||
        (profil?.peut(Permission.voirTachesEquipe) ?? false);

    final maintenant = DateTime.now();
    final lignes = construireLignes(
      taches: voitTout ? toutes : mes,
      mesTaches: {for (final t in mes) t.id},
      activites: activites,
      quotidiennes: quotidiennes,
      moi: profil?.id,
    );

    // Une activité ou une personne disparue des listes ne doit pas laisser un
    // filtre qui ne désignerait plus rien.
    final activitesDesLignes = <String, String>{
      for (final l in lignes)
        if (l.activiteId != null) l.activiteId!: l.contexte,
    };
    final personnes = {for (final l in lignes) l.personne}.toList()..sort();
    final activite =
        _activite == cleToutesActivites ||
            _activite == cleTachesQuotidiennes ||
            activitesDesLignes.containsKey(_activite)
        ? _activite
        : cleToutesActivites;
    final personne =
        _personne == cleToutLeMonde ||
            _personne == cleMoi ||
            personnes.contains(_personne)
        ? _personne
        : cleToutLeMonde;

    final visibles = filtrerLignes(
      lignes,
      maintenant: maintenant,
      segment: _segment,
      jour: _jour,
      activite: activite,
      personne: personne,
    );
    final sections = sectionsDe(visibles, maintenant);

    final panneau = _PanneauGauche(
      lignes: filtrerLignes(
        lignes,
        maintenant: maintenant,
        activite: activite,
        personne: personne,
      ),
      maintenant: maintenant,
      segment: _segment,
      onSegment: (s) => setState(() {
        _segment = s;
        _jour = null;
      }),
      activite: activite,
      activites: activitesDesLignes,
      onActivite: (v) => setState(() => _activite = v),
      personne: personne,
      personnes: personnes,
      onPersonne: (v) => setState(() => _personne = v),
      mois: _mois,
      onMois: (m) => setState(() => _mois = m),
      jour: _jour,
      onJour: (j) => setState(() {
        _jour = _jour != null && _memeJour(_jour!, j) ? null : j;
        _segment = SegmentTaches.toutes;
      }),
    );

    final liste = charge
        ? _Liste(
            sections: sections,
            maintenant: maintenant,
            enCours: _enCours,
            actionDuRond: _actionDuRond,
            menuDe: (l) => _menuDe(l, activites),
            onAjouter: _ajouter,
            jour: _jour,
          )
        : const SkeletonList(itemCount: 4);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, contraintes) {
              final large = contraintes.maxWidth >= 860;
              return SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 24),
                child: large
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: 340, child: panneau),
                          const SizedBox(width: 24),
                          Expanded(child: liste),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [panneau, const SizedBox(height: 24), liste],
                      ),
              );
            },
          ),
        ),
      ],
    );
  }
}

bool _memeJour(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _capitale(String t) =>
    t.isEmpty ? t : t[0].toUpperCase() + t.substring(1);

class _PanneauGauche extends StatelessWidget {
  const _PanneauGauche({
    required this.lignes,
    required this.maintenant,
    required this.segment,
    required this.onSegment,
    required this.activite,
    required this.activites,
    required this.onActivite,
    required this.personne,
    required this.personnes,
    required this.onPersonne,
    required this.mois,
    required this.onMois,
    required this.jour,
    required this.onJour,
  });

  final List<LigneTache> lignes;
  final DateTime maintenant;
  final SegmentTaches segment;
  final ValueChanged<SegmentTaches> onSegment;
  final String activite;
  final Map<String, String> activites;
  final ValueChanged<String> onActivite;
  final String personne;
  final List<String> personnes;
  final ValueChanged<String> onPersonne;
  final DateTime mois;
  final ValueChanged<DateTime> onMois;
  final DateTime? jour;
  final ValueChanged<DateTime> onJour;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CarteDuJour(lignes: lignes, maintenant: maintenant),
        const SizedBox(height: 16),
        _Segments(valeur: segment, onChange: onSegment),
        const SizedBox(height: 16),
        _Filtre(
          // La clé : le champ ne relit sa valeur initiale qu'à sa création.
          key: ValueKey('activite:$activite'),
          libelle: 'Activité',
          icone: Icons.event_note_rounded,
          valeur: activite,
          options: {
            cleToutesActivites: 'Toutes les tâches',
            cleTachesQuotidiennes: 'Tâches quotidiennes',
            ...activites,
          },
          onChange: onActivite,
        ),
        const SizedBox(height: 12),
        _Filtre(
          key: ValueKey('personne:$personne'),
          libelle: 'Responsable',
          icone: Icons.person_outline_rounded,
          valeur: personne,
          options: {
            cleToutLeMonde: 'Tout le monde',
            cleMoi: 'Mes tâches',
            for (final p in personnes)
              if (p.isNotEmpty) p: p,
          },
          onChange: onPersonne,
        ),
        const SizedBox(height: 16),
        _Calendrier(
          mois: mois,
          onMois: onMois,
          jour: jour,
          onJour: onJour,
          maintenant: maintenant,
          lignes: lignes,
        ),
      ],
    );
  }
}

/// Où l'on en est aujourd'hui.
class _CarteDuJour extends StatelessWidget {
  const _CarteDuJour({required this.lignes, required this.maintenant});

  final List<LigneTache> lignes;
  final DateTime maintenant;

  @override
  Widget build(BuildContext context) {
    final duJour = lignes.where((l) => l.estLe(maintenant)).toList();
    final faites = duJour.where((l) => l.faite || l.enAttenteVisa).length;
    // Celles du jour sont déjà comptées dans le titre : « autre » ne doit pas les
    // compter une seconde fois.
    final retards = lignes
        .where((l) => l.enRetard(maintenant) && !l.estLe(maintenant))
        .length;
    final part = duJour.isEmpty ? 0.0 : faites / duJour.length;

    final (titre, legende) = duJour.isEmpty
        ? (
            retards > 0 ? 'Rien de nouveau' : 'Journée libre',
            retards > 0
                ? '$retards tâche(s) en retard.'
                : "Aucune échéance aujourd'hui.",
          )
        : (
            '$faites sur ${duJour.length} réalisée(s)',
            retards > 0
                ? '$retards autre(s) en retard.'
                : "Échéances d'aujourd'hui.",
          );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 68,
              height: 68,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 68,
                    height: 68,
                    child: CircularProgressIndicator(
                      value: part,
                      strokeWidth: 6,
                      strokeCap: StrokeCap.round,
                      backgroundColor: AppColors.blueSoft.withValues(
                        alpha: 0.5,
                      ),
                      valueColor: const AlwaysStoppedAnimation(
                        AppColors.success,
                      ),
                    ),
                  ),
                  Text(
                    '${(part * 100).round()} %',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titre,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    legende,
                    style: TextStyle(
                      fontSize: 12,
                      color: retards > 0
                          ? AppColors.danger
                          : AppColors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Segments extends StatelessWidget {
  const _Segments({required this.valeur, required this.onChange});

  final SegmentTaches valeur;
  final ValueChanged<SegmentTaches> onChange;

  @override
  Widget build(BuildContext context) {
    Widget segment(SegmentTaches s, String libelle) {
      final actif = s == valeur;
      return Expanded(
        child: Semantics(
          button: true,
          selected: actif,
          child: Material(
            color: actif ? AppColors.navy : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.pill),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadii.pill),
              onTap: () => onChange(s),
              child: SizedBox(
                height: 40,
                child: Center(
                  child: Text(
                    libelle,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: actif ? Colors.white : AppColors.inkMuted,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.blueMist,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          segment(SegmentTaches.toutes, 'Toutes'),
          segment(SegmentTaches.aVenir, 'À venir'),
          segment(SegmentTaches.aujourdhui, "Aujourd'hui"),
        ],
      ),
    );
  }
}

class _Filtre extends StatelessWidget {
  const _Filtre({
    super.key,
    required this.libelle,
    required this.icone,
    required this.valeur,
    required this.options,
    required this.onChange,
  });

  final String libelle;
  final IconData icone;
  final String valeur;
  final Map<String, String> options;
  final ValueChanged<String> onChange;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: valeur,
      decoration: InputDecoration(
        labelText: libelle,
        prefixIcon: Icon(icone, size: 20),
      ),
      items: [
        for (final MapEntry(key: cle, value: texte) in options.entries)
          DropdownMenuItem(
            value: cle,
            child: Text(texte, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (v) {
        if (v != null) onChange(v);
      },
    );
  }
}

/// Le mois, avec un point sous chaque jour qui porte une tâche à faire.
class _Calendrier extends StatelessWidget {
  const _Calendrier({
    required this.mois,
    required this.onMois,
    required this.jour,
    required this.onJour,
    required this.maintenant,
    required this.lignes,
  });

  final DateTime mois;
  final ValueChanged<DateTime> onMois;
  final DateTime? jour;
  final ValueChanged<DateTime> onJour;
  final DateTime maintenant;
  final List<LigneTache> lignes;

  @override
  Widget build(BuildContext context) {
    final titre = _capitale(DateFormat.yMMMM('fr_FR').format(mois));
    // Le lundi de la semaine qui contient le 1er.
    final debut = mois.subtract(Duration(days: mois.weekday - 1));
    final aFaire = <DateTime>{
      for (final l in lignes)
        if (!l.faite && l.echeance != null)
          DateTime(l.echeance!.year, l.echeance!.month, l.echeance!.day),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Mois précédent',
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: () => onMois(DateTime(mois.year, mois.month - 1)),
                ),
                Expanded(
                  child: Text(
                    titre,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Mois suivant',
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: () => onMois(DateTime(mois.year, mois.month + 1)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                for (final l in const ['L', 'M', 'M', 'J', 'V', 'S', 'D'])
                  Expanded(
                    child: Center(
                      child: Text(
                        l,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            for (var semaine = 0; semaine < 6; semaine++)
              Row(
                children: [
                  for (var j = 0; j < 7; j++)
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          // Par le calendrier, pas par la durée : un changement
                          // d'heure fausserait une addition de 24 heures.
                          final d = DateTime(
                            debut.year,
                            debut.month,
                            debut.day + semaine * 7 + j,
                          );
                          return _Jour(
                            date: d,
                            duMois: d.month == mois.month,
                            aujourdhui: _memeJour(d, maintenant),
                            choisi: jour != null && _memeJour(d, jour!),
                            marque: aFaire.contains(d),
                            onTap: () => onJour(d),
                          );
                        },
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _Jour extends StatelessWidget {
  const _Jour({
    required this.date,
    required this.duMois,
    required this.aujourdhui,
    required this.choisi,
    required this.marque,
    required this.onTap,
  });

  final DateTime date;
  final bool duMois;
  final bool aujourdhui;
  final bool choisi;
  final bool marque;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        height: 44,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 28,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: choisi ? AppColors.navy : null,
                borderRadius: BorderRadius.circular(8),
                border: aujourdhui && !choisi
                    ? Border.all(color: AppColors.navy, width: 1.5)
                    : null,
              ),
              child: Text(
                '${date.day}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: aujourdhui ? FontWeight.w800 : FontWeight.w500,
                  color: choisi
                      ? Colors.white
                      : (duMois ? AppColors.ink : AppColors.inkMuted),
                ),
              ),
            ),
            const SizedBox(height: 3),
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: marque ? AppColors.danger : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Liste extends StatelessWidget {
  const _Liste({
    required this.sections,
    required this.maintenant,
    required this.enCours,
    required this.actionDuRond,
    required this.menuDe,
    required this.onAjouter,
    required this.jour,
  });

  final List<(String, List<LigneTache>)> sections;
  final DateTime maintenant;
  final Set<String> enCours;
  final void Function()? Function(LigneTache) actionDuRond;
  final List<PopupMenuEntry<VoidCallback>> Function(LigneTache) menuDe;
  final VoidCallback onAjouter;
  final DateTime? jour;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (sections.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: EmptyState(
              message: jour != null
                  ? 'Aucune tâche ce jour-là.'
                  : 'Aucune tâche ici pour le moment.',
              icon: Icons.task_alt_rounded,
            ),
          ),
        for (final (titre, lignes) in sections) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 4),
            child: Text(
              '${titre.toUpperCase()}   ${lignes.length}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: titre == 'En retard'
                    ? AppColors.danger
                    : AppColors.inkMuted,
              ),
            ),
          ),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < lignes.length; i++) ...[
                  if (i > 0) const Divider(height: 1, indent: 60),
                  _LigneVue(
                    ligne: lignes[i],
                    maintenant: maintenant,
                    enCours: enCours.contains(lignes[i].cle),
                    onRond: actionDuRond(lignes[i]),
                    menu: menuDe(lignes[i]),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onAjouter,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: AppColors.navy,
                    child: Icon(Icons.add, size: 18, color: Colors.white),
                  ),
                  SizedBox(width: 14),
                  Text(
                    'Ajouter une tâche',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.blueDeep,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LigneVue extends StatelessWidget {
  const _LigneVue({
    required this.ligne,
    required this.maintenant,
    required this.enCours,
    required this.onRond,
    required this.menu,
  });

  final LigneTache ligne;
  final DateTime maintenant;
  final bool enCours;
  final VoidCallback? onRond;
  final List<PopupMenuEntry<VoidCallback>> menu;

  String _date(DateTime d) => ligne.aUneHeure
      ? DateFormat("dd/MM 'à' HH'h'mm").format(d)
      : DateFormat('dd/MM').format(d);

  @override
  Widget build(BuildContext context) {
    final l = ligne;
    final retard = l.enRetard(maintenant);

    final morceaux = <String>[
      if (l.faite && l.finieLe != null)
        'Faite le ${DateFormat('dd/MM').format(l.finieLe!)}'
      else if (l.echeance != null)
        _date(l.echeance!),
      l.contexte,
      if (l.personne.isNotEmpty && !(l.aMoi && l.quotidienne != null))
        'Pour ${l.personne}',
      if (l.enAttenteVisa) 'En attente de validation',
      if (l.detail != null) l.detail!,
    ];

    // Le point dit ce qui presse : rouge pour l'urgent et le retard, orange
    // pour l'important. Il double le mot, la couleur seule ne suffit pas.
    final Color? point = l.faite
        ? null
        : retard || l.priorite == PrioriteTache.urgente
        ? AppColors.danger
        : l.priorite == PrioriteTache.importante
        ? AppColors.warning
        : null;
    final pointLibelle = retard ? 'En retard' : l.priorite.label;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: enCours
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    onPressed: onRond,
                    tooltip: l.faite
                        ? (l.quotidienne != null
                              ? 'Rouvrir la tâche'
                              : 'Validée')
                        : l.enAttenteVisa
                        ? 'En attente de validation'
                        : 'Marquer comme faite',
                    icon: Icon(
                      l.faite
                          ? Icons.check_circle_rounded
                          : l.enAttenteVisa
                          ? Icons.hourglass_top_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: l.faite
                          ? AppColors.success
                          : l.enAttenteVisa
                          ? AppColors.warning
                          : AppColors.inkMuted,
                    ),
                  ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.titre,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: l.faite ? AppColors.inkMuted : AppColors.ink,
                      decoration: l.faite ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    morceaux.join('  ·  '),
                    style: TextStyle(
                      fontSize: 12,
                      color: retard ? AppColors.danger : AppColors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (point != null)
            Tooltip(
              message: pointLibelle,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: point,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          // On garde la place du menu : sans cela, les points ne s'aligneraient
          // pas d'une ligne à l'autre.
          SizedBox(
            width: 44,
            height: 44,
            child: menu.isEmpty
                ? null
                : PopupMenuButton<VoidCallback>(
                    icon: const Icon(Icons.more_horiz_rounded, size: 20),
                    tooltip: 'Actions',
                    onSelected: (action) => action(),
                    itemBuilder: (_) => menu,
                  ),
          ),
        ],
      ),
    );
  }
}
