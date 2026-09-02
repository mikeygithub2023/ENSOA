import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/roles.dart';
import '../../core/theme.dart';
import '../../models/profil.dart';
import '../auth/providers/auth_providers.dart';
import 'providers/apercu_providers.dart';

/// La vue d'ensemble de l'école — ce que l'agent doit savoir avant d'ouvrir
/// quoi que ce soit, borné par ce qui le regarde.
///
/// Un instructeur n'y voit que la scolarité, un armurier que le soutien
/// technique, un administrateur les deux. Les chiffres viennent de la base
/// avec la RLS pour seul filtre : un commandant de division y lit l'effectif de sa
/// division, pas celui de l'école.
class AccueilScreen extends ConsumerWidget {
  const AccueilScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profil = ref.watch(profilCourantProvider).value;
    if (profil == null) return const SizedBox.shrink();

    final aujourdhui = DateFormat.yMMMMEEEEd('fr_FR').format(DateTime.now());

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Bandeau(date: aujourdhui, profil: profil),
          if (profil.releveDeLaScolarite) ...[
            const SizedBox(height: 28),
            const _TitreSection('Scolarité'),
            const SizedBox(height: 14),
            const _BlocScolarite(),
          ],
          // L'Officier Adjoint relève du soutien technique sans en tenir
          // aucun service : il monte les activités de l'école et vise les
          // tâches que les services déclarent faites. Les compteurs du parc
          // et des soutes ne lui apprennent rien — il a les siens.
          if (profil.roleLogistique == RoleLogistique.officierAdjoint) ...[
            const SizedBox(height: 28),
            const _TitreSection('Activités'),
            const SizedBox(height: 14),
            const _BlocActivites(),
          ] else if (profil.releveDuSoutienTechnique) ...[
            const SizedBox(height: 28),
            const _TitreSection('Soutien technique'),
            const SizedBox(height: 14),
            const _BlocLogistique(),
          ],
          const SizedBox(height: 28),
          const _TitreSection('Accès rapide'),
          const SizedBox(height: 14),
          _Raccourcis(profil: profil),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

/// Bandeau sombre : la date, et ce que le poste ouvre. C'est la seule pièce
/// de contraste de l'écran — le reste vit sur la carte blanche.
class _Bandeau extends StatelessWidget {
  const _Bandeau({required this.date, required this.profil});

  final String date;
  final Profil profil;

  @override
  Widget build(BuildContext context) {
    final modules = [
      if (profil.releveDeLaScolarite) 'Scolarité',
      if (profil.releveDuSoutienTechnique) 'Soutien technique',
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.contrastCard,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _capitale(date),
                  style: const TextStyle(
                    color: AppColors.blueSoft,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "École Nationale des Sous-Officiers d'Active",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  modules.length == 2
                      ? 'Vos deux domaines sont ouverts : scolarité et soutien technique.'
                      : 'Domaine ouvert : ${modules.join()}.',
                  style: const TextStyle(
                    color: AppColors.blueSoft,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Image.asset(
            'assets/images/icone_ensoa.png',
            height: 78,
            errorBuilder: (_, _, _) => const SizedBox(),
          ),
        ],
      ),
    );
  }

  String _capitale(String texte) =>
      texte.isEmpty ? texte : texte[0].toUpperCase() + texte.substring(1);
}

class _TitreSection extends StatelessWidget {
  const _TitreSection(this.texte);

  final String texte;

  @override
  Widget build(BuildContext context) {
    return Text(
      texte.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
        color: AppColors.inkMuted,
      ),
    );
  }
}

class _BlocScolarite extends ConsumerWidget {
  const _BlocScolarite();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apercu = ref.watch(apercuScolariteProvider);

    return apercu.when(
      loading: () => const _TuilesEnAttente(nombre: 4),
      error: (e, _) => _Incident(message: '$e'),
      data: (a) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GrilleDeTuiles(
            tuiles: [
              _Tuile(
                icone: Icons.groups_rounded,
                valeur: '${a.apprenants}',
                titre: 'Élèves & stagiaires',
                legende: 'Effectif suivi',
              ),
              _Tuile(
                icone: Icons.flag_rounded,
                valeur: '${a.promotions}',
                titre: 'Promotions',
                legende: 'Ouvertes à ce jour',
                couleur: AppColors.blue,
              ),
              _Tuile(
                icone: Icons.meeting_room_rounded,
                valeur: '${a.classes}',
                titre: 'Classes & stages',
                legende: 'Référentiel',
                couleur: AppColors.blueBright,
              ),
              _Tuile(
                icone: Icons.school_rounded,
                valeur: '${a.cours}',
                titre: 'Cours',
                legende: "Déposés par l'encadrement",
                couleur: AppColors.success,
              ),
            ],
          ),
          if (a.vide) ...[
            const SizedBox(height: 12),
            const _Amorce(
              texte:
                  "La scolarité n'a encore rien en base. Commencez par les "
                  "promotions et les classes : les élèves s'y rattachent.",
              chemin: '/scolarite/matieres',
              action: 'Ouvrir les référentiels',
            ),
          ],
        ],
      ),
    );
  }
}

/// L'aperçu de l'Officier Adjoint : ses activités, et l'état des tâches
/// qu'il a réparties entre les services.
///
/// « Tâches à valider » est le seul chiffre sur lequel il ait à agir : c'est
/// pourquoi il porte la couleur d'alerte dès qu'il n'est pas nul.
class _BlocActivites extends ConsumerWidget {
  const _BlocActivites();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apercu = ref.watch(apercuActivitesProvider);

    return apercu.when(
      loading: () => const _TuilesEnAttente(nombre: 4),
      error: (e, _) => _Incident(message: '$e'),
      data: (a) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GrilleDeTuiles(
            tuiles: [
              _Tuile(
                icone: Icons.event_note_rounded,
                valeur: '${a.enCours}',
                titre: 'Activités en cours',
                legende: 'Planifiées ou commencées',
              ),
              _Tuile(
                icone: Icons.fact_check_rounded,
                valeur: '${a.aValider}',
                titre: 'Tâches à valider',
                legende: 'Les services les déclarent faites',
                couleur: a.aValider > 0
                    ? AppColors.ivoryOrange
                    : AppColors.blueDeep,
              ),
              _Tuile(
                icone: Icons.pending_actions_rounded,
                valeur: '${a.tachesEnCours}',
                titre: 'Tâches en cours',
                legende: 'Confiées, pas encore rendues',
                couleur: AppColors.blueBright,
              ),
              _Tuile(
                icone: Icons.done_all_rounded,
                valeur: '${a.terminees}',
                titre: 'Activités terminées',
                legende: 'Depuis l\'ouverture',
                couleur: AppColors.success,
              ),
            ],
          ),
          if (a.vide) ...[
            const SizedBox(height: 12),
            const _Amorce(
              texte:
                  "Aucune activité n'est encore inscrite au programme. "
                  "Commencez par en créer une, puis répartissez ses tâches "
                  "entre les services.",
              chemin: '/logistique/activites',
              action: 'Ouvrir les activités',
            ),
          ],
        ],
      ),
    );
  }
}

class _BlocLogistique extends ConsumerWidget {
  const _BlocLogistique();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apercu = ref.watch(apercuLogistiqueProvider);

    return apercu.when(
      loading: () => const _TuilesEnAttente(nombre: 4),
      error: (e, _) => _Incident(message: '$e'),
      data: (a) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GrilleDeTuiles(
            tuiles: [
              _Tuile(
                icone: Icons.directions_car_filled_rounded,
                valeur: '${a.vehiculesDisponibles}/${a.vehicules}',
                titre: 'Véhicules disponibles',
                legende: 'Sur le parc total',
              ),
              _Tuile(
                icone: Icons.local_gas_station_rounded,
                valeur: _milliers(a.litresEnSoute),
                titre: 'Litres en soute',
                legende: 'Gasoil et super cumulés',
                couleur: AppColors.blue,
              ),
              _Tuile(
                icone: Icons.security_rounded,
                valeur: '${a.armes}',
                titre: 'Armes inventoriées',
                legende: "Toutes catégories",
                couleur: AppColors.blueBright,
              ),
              _Tuile(
                icone: Icons.assignment_ind_rounded,
                valeur: '${a.armesEnDotation}',
                titre: 'Armes en dotation',
                legende: 'Sorties non rendues',
                couleur: a.armesEnDotation > 0
                    ? AppColors.warning
                    : AppColors.success,
              ),
            ],
          ),
          if (a.vide) ...[
            const SizedBox(height: 12),
            const _Amorce(
              texte:
                  "Le soutien technique n'a encore rien en base. Commencez par "
                  "les référentiels du garage, puis le parc.",
              chemin: '/logistique/parc',
              action: 'Ouvrir le parc',
            ),
          ],
        ],
      ),
    );
  }

  static String _milliers(int valeur) {
    final texte = valeur.toString();
    final tampon = StringBuffer();
    for (var i = 0; i < texte.length; i++) {
      if (i > 0 && (texte.length - i) % 3 == 0) tampon.write(' ');
      tampon.write(texte[i]);
    }
    return tampon.toString();
  }
}

/// Tuile de chiffre : pastille d'icône teintée, valeur en gros, libellé.
class _Tuile extends StatelessWidget {
  const _Tuile({
    required this.icone,
    required this.valeur,
    required this.titre,
    required this.legende,
    this.couleur = AppColors.blueDeep,
  });

  final IconData icone;
  final String valeur;
  final String titre;
  final String legende;
  final Color couleur;

  /// La même pour toutes : posées côte à côte, des hauteurs dictées par la
  /// longueur des légendes donnaient une rangée dentelée. Elle tient la plus
  /// bavarde d'entre elles — celle dont la légende passe sur deux lignes.
  static const double hauteur = 196;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: hauteur,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: couleur.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icone, color: couleur, size: 20),
          ),
          // L'espace qui reste se met là, entre le pictogramme et le chiffre,
          // plutôt qu'en bas de la tuile. Les chiffres s'alignent alors d'une
          // tuile à l'autre, et la carte se remplit au lieu de sembler
          // inachevée.
          const Spacer(),
          Text(
            valeur,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            titre,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            legende,
            style: const TextStyle(fontSize: 11, color: AppColors.inkMuted),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Range les tuiles sur toute la largeur disponible, à parts égales.
///
/// Elles avaient une largeur fixe de 232 pixels : sur un écran large, la
/// rangée s'arrêtait au milieu et laissait une bande vide à droite. La
/// largeur minimale ne décide plus que du nombre de tuiles qui tiennent sur
/// une ligne ; celles-ci se partagent ensuite ce qu'il y a.
class _GrilleDeTuiles extends StatelessWidget {
  const _GrilleDeTuiles({required this.tuiles});

  final List<Widget> tuiles;

  static const double _espace = 14;
  static const double _largeurMinimale = 232;

  @override
  Widget build(BuildContext context) {
    if (tuiles.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, contraintes) {
        final large = contraintes.maxWidth;
        var parRangee = ((large + _espace) / (_largeurMinimale + _espace))
            .floor();
        if (parRangee < 1) parRangee = 1;
        if (parRangee > tuiles.length) parRangee = tuiles.length;
        final largeur = (large - _espace * (parRangee - 1)) / parRangee;

        return Wrap(
          spacing: _espace,
          runSpacing: _espace,
          children: [
            for (final tuile in tuiles) SizedBox(width: largeur, child: tuile),
          ],
        );
      },
    );
  }
}

class _TuilesEnAttente extends StatelessWidget {
  const _TuilesEnAttente({required this.nombre});

  final int nombre;

  @override
  Widget build(BuildContext context) {
    return _GrilleDeTuiles(
      tuiles: [
        for (var i = 0; i < nombre; i++)
          Container(
            height: _Tuile.hauteur,
            decoration: BoxDecoration(
              color: AppColors.blueMist,
              borderRadius: BorderRadius.circular(AppRadii.card),
            ),
          ),
      ],
    );
  }
}

class _Incident extends StatelessWidget {
  const _Incident({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Chiffres indisponibles : $message',
              style: const TextStyle(color: AppColors.danger, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ce qu'il faut faire quand la base est encore vide — une base neuve n'est
/// pas une panne, mais elle mérite qu'on dise par où commencer.
class _Amorce extends StatelessWidget {
  const _Amorce({
    required this.texte,
    required this.chemin,
    required this.action,
  });

  final String texte;
  final String chemin;
  final String action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.blueMist,
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      child: Row(
        children: [
          const Icon(Icons.tips_and_updates_outlined,
              color: AppColors.blueDeep, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texte,
              style: const TextStyle(fontSize: 12, color: AppColors.ink),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => context.go(chemin),
            child: Text(action),
          ),
        ],
      ),
    );
  }
}

/// Les portes que ce poste ouvre, en clair. La barre d'icônes ne dit pas son
/// nom ; ici, si.
class _Raccourcis extends StatelessWidget {
  const _Raccourcis({required this.profil});

  final Profil profil;

  @override
  Widget build(BuildContext context) {
    final raccourcis = <(String, IconData, String, Permission)>[
      (
        'Élèves & stagiaires',
        Icons.groups_rounded,
        '/scolarite/apprenants',
        Permission.consulterApprenants,
      ),
      ('Cours', Icons.school_rounded, '/scolarite/cours', Permission.gererCours),
      (
        'Consultations',
        Icons.medical_services_rounded,
        '/scolarite/consultations',
        Permission.gererConsultations,
      ),
      (
        'Parc automobile',
        Icons.directions_car_filled_rounded,
        '/logistique/parc',
        Permission.gererParc,
      ),
      (
        'Carburant',
        Icons.local_gas_station_rounded,
        '/logistique/carburant',
        Permission.gererCarburant,
      ),
      (
        'Armement',
        Icons.security_rounded,
        '/logistique/armement',
        Permission.gererArmement,
      ),
      (
        'Poste de Police',
        Icons.local_police_rounded,
        '/logistique/poste-police',
        Permission.gererPostePolice,
      ),
      (
        'Comptes',
        Icons.admin_panel_settings_rounded,
        '/administration',
        Permission.gererUtilisateurs,
      ),
    ].where((r) => profil.peut(r.$4)).toList();

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final (libelle, icone, chemin, _) in raccourcis)
          Material(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(AppRadii.pill),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadii.pill),
              onTap: () => context.go(chemin),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icone, size: 17, color: AppColors.blueDeep),
                    const SizedBox(width: 9),
                    Text(
                      libelle,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
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
