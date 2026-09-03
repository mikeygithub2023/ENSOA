import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/roles.dart';
import '../../core/theme.dart';
import '../../shared/widgets/icone_arme.dart';
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
          // Chaque poste du soutien technique a ses propres compteurs.
          //
          // Un seul aperçu servait aux quatre : véhicules, litres en soute,
          // armes, dotations. Trois tuiles sur quatre étaient hors sujet
          // pour chacun d'eux, et l'armurier apprenait l'état du parc
          // plutôt que celui de ses munitions. Le chef du service garde la
          // vue d'ensemble : c'est la sienne.
          if (profil.releveDuSoutienTechnique) ...[
            const SizedBox(height: 28),
            _TitreSection(_sectionDuPoste(profil.roleLogistique)),
            const SizedBox(height: 14),
            _blocDuPoste(profil.roleLogistique),
          ],
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

/// Les compteurs que ce poste doit lire.
Widget _blocDuPoste(RoleLogistique? role) => switch (role) {
  RoleLogistique.sante => const _BlocSante(),
  RoleLogistique.postePolice => const _BlocPolice(),
  RoleLogistique.armurerie => const _BlocArmurerie(),
  RoleLogistique.garage => const _BlocGarage(),
  RoleLogistique.soutienPetrolier => const _BlocCarburant(),
  RoleLogistique.officierAdjoint => const _BlocActivites(),
  _ => const _BlocLogistique(),
};

/// Et le titre qui les annonce.
String _sectionDuPoste(RoleLogistique? role) => switch (role) {
  RoleLogistique.sante => 'Service de santé',
  RoleLogistique.postePolice => 'Poste de police',
  RoleLogistique.armurerie => 'Armurerie',
  RoleLogistique.garage => 'Garage',
  RoleLogistique.soutienPetrolier => 'Soutien pétrolier',
  RoleLogistique.officierAdjoint => 'Activités',
  _ => 'Soutien technique',
};

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
                iconeWidget: const IconeArmeTeintee(
                  couleur: AppColors.blueBright,
                  size: 22,
                ),
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
}

/// Un nombre lisible : les milliers séparés par une espace. Elle était
/// enfermée dans le bloc du soutien technique ; les trois blocs de
/// service en ont besoin aussi.
String _milliers(int valeur) {
  final texte = valeur.toString();
  final tampon = StringBuffer();
  for (var i = 0; i < texte.length; i++) {
    if (i > 0 && (texte.length - i) % 3 == 0) tampon.write(' ');
    tampon.write(texte[i]);
  }
  return tampon.toString();
}

/// Tuile de chiffre : pastille d'icône teintée, valeur en gros, libellé.
class _Tuile extends StatelessWidget {
  const _Tuile({
    this.icone,
    this.iconeWidget,
    required this.valeur,
    required this.titre,
    required this.legende,
    this.couleur = AppColors.blueDeep,
  }) : assert(
         icone != null || iconeWidget != null,
         'une tuile porte un dessin',
       );

  final IconData? icone;

  /// Pour ce que Material ne dessine pas — une arme, par exemple. Une tuile
  /// qui annonce un inventaire d'armes sous un bouclier générique demande à
  /// être lue pour être comprise ; c'est ce qu'un pictogramme doit éviter.
  final Widget? iconeWidget;
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
            child: iconeWidget ?? Icon(icone, color: couleur, size: 20),
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
          const Icon(
            Icons.tips_and_updates_outlined,
            color: AppColors.blueDeep,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texte,
              style: const TextStyle(fontSize: 12, color: AppColors.ink),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(onPressed: () => context.go(chemin), child: Text(action)),
        ],
      ),
    );
  }
}

/// L'accueil de l'armurier : ses armes, pas le parc ni les soutes.
class _BlocArmurerie extends ConsumerWidget {
  const _BlocArmurerie();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apercu = ref.watch(apercuArmurerieProvider);

    return apercu.when(
      loading: () => const _TuilesEnAttente(nombre: 4),
      error: (e, _) => _Incident(message: '$e'),
      data: (a) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GrilleDeTuiles(
            tuiles: [
              _Tuile(
                iconeWidget: const IconeArmeTeintee(
                  couleur: AppColors.blueBright,
                  size: 22,
                ),
                valeur: '${a.armes}',
                titre: 'Armes inventoriées',
                legende: 'Toutes catégories',
                couleur: AppColors.blueBright,
              ),
              _Tuile(
                icone: Icons.assignment_ind_rounded,
                valeur: '${a.enDotation}',
                titre: 'Armes en dotation',
                legende: 'Sorties non rendues',
                couleur: a.enDotation > 0
                    ? AppColors.warning
                    : AppColors.success,
              ),
              _Tuile(
                icone: Icons.inventory_2_rounded,
                valeur: _milliers(a.cartouches),
                titre: 'Cartouches en stock',
                legende: 'Tous calibres confondus',
                couleur: AppColors.blue,
              ),
              _Tuile(
                icone: Icons.event_busy_rounded,
                valeur: '${a.inspectionsEchues}',
                titre: 'Inspections échues',
                legende: 'Armes à contrôler',
                couleur: a.inspectionsEchues > 0
                    ? AppColors.danger
                    : AppColors.success,
              ),
            ],
          ),
          if (a.vide) ...[
            const SizedBox(height: 12),
            const _Amorce(
              texte:
                  "L'armurerie n'a encore rien en base. Commencez par les "
                  "types d'armes, puis l'inventaire.",
              chemin: '/logistique/armement',
              action: "Ouvrir l'armement",
            ),
          ],
        ],
      ),
    );
  }
}

/// L'accueil du garage : son parc, pas les soutes ni l'armement.
class _BlocGarage extends ConsumerWidget {
  const _BlocGarage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apercu = ref.watch(apercuGarageProvider);

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
                valeur: '${a.disponibles}/${a.vehicules}',
                titre: 'Véhicules disponibles',
                legende: 'Sur le parc total',
              ),
              _Tuile(
                icone: Icons.car_repair_rounded,
                valeur: '${a.enReparation}',
                titre: 'En réparation',
                legende: 'Immobilisés à l\'atelier',
                couleur: a.enReparation > 0
                    ? AppColors.warning
                    : AppColors.success,
              ),
              _Tuile(
                icone: Icons.oil_barrel_rounded,
                valeur: '${a.vidangesAPrevoir}',
                titre: 'Vidanges à prévoir',
                legende: 'Kilométrage atteint',
                couleur: a.vidangesAPrevoir > 0
                    ? AppColors.warning
                    : AppColors.success,
              ),
              _Tuile(
                icone: Icons.garage_rounded,
                valeur: '${a.vehicules}',
                titre: 'Parc total',
                legende: 'Véhicules enregistrés',
                couleur: AppColors.blueBright,
              ),
            ],
          ),
          if (a.vide) ...[
            const SizedBox(height: 12),
            const _Amorce(
              texte:
                  "Le garage n'a encore aucun véhicule. Commencez par les "
                  "référentiels, puis le parc.",
              chemin: '/logistique/parc',
              action: 'Ouvrir le parc',
            ),
          ],
        ],
      ),
    );
  }
}

/// L'accueil du soutien pétrolier : ses soutes, pas le parc ni l'armement.
class _BlocCarburant extends ConsumerWidget {
  const _BlocCarburant();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apercu = ref.watch(apercuCarburantProvider);

    return apercu.when(
      loading: () => const _TuilesEnAttente(nombre: 4),
      error: (e, _) => _Incident(message: '$e'),
      data: (a) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GrilleDeTuiles(
            tuiles: [
              _Tuile(
                icone: Icons.oil_barrel_rounded,
                valeur: _milliers(a.litres),
                titre: 'Litres en soute',
                legende: 'Gasoil et super cumulés',
                couleur: AppColors.blue,
              ),
              _Tuile(
                icone: Icons.warehouse_rounded,
                valeur: '${a.soutes}',
                titre: 'Soutes en service',
                legende: 'Toutes répartitions',
                couleur: AppColors.blueBright,
              ),
              _Tuile(
                icone: Icons.warning_amber_rounded,
                valeur: '${a.soutesEnAlerte}',
                titre: 'Sous le seuil',
                legende: 'Répartitions à réapprovisionner',
                couleur: a.soutesEnAlerte > 0
                    ? AppColors.danger
                    : AppColors.success,
              ),
              _Tuile(
                icone: Icons.local_gas_station_rounded,
                valeur: _milliers(a.sortiesDuJour),
                titre: 'Litres distribués',
                legende: "Depuis minuit",
                couleur: AppColors.ivoryOrange,
              ),
            ],
          ),
          if (a.vide) ...[
            const SizedBox(height: 12),
            const _Amorce(
              texte:
                  "Le soutien pétrolier n'a encore rien en base. Commencez "
                  "par les soutes et leurs répartitions.",
              chemin: '/logistique/carburant',
              action: 'Ouvrir le carburant',
            ),
          ],
        ],
      ),
    );
  }
}

/// L'accueil du Service de santé : ses consultants, sa pharmacie.
class _BlocSante extends ConsumerWidget {
  const _BlocSante();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apercu = ref.watch(apercuSanteProvider);

    return apercu.when(
      loading: () => const _TuilesEnAttente(nombre: 4),
      error: (e, _) => _Incident(message: '$e'),
      data: (a) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GrilleDeTuiles(
            tuiles: [
              _Tuile(
                icone: Icons.medical_services_rounded,
                valeur: '${a.consultationsOuvertes}',
                titre: 'Consultations ouvertes',
                legende: 'En attente ou en cours',
              ),
              _Tuile(
                icone: Icons.emergency_rounded,
                valeur: '${a.urgences}',
                titre: 'Urgences',
                legende: 'Non encore traitées',
                couleur: a.urgences > 0 ? AppColors.danger : AppColors.success,
              ),
              _Tuile(
                icone: Icons.medication_rounded,
                valeur: '${a.medicamentsSousSeuil}',
                titre: 'Médicaments sous seuil',
                legende: 'À réapprovisionner',
                couleur: a.medicamentsSousSeuil > 0
                    ? AppColors.warning
                    : AppColors.success,
              ),
              _Tuile(
                icone: Icons.event_available_rounded,
                valeur: '${a.visitesAVenir}',
                titre: 'Visites à venir',
                legende: "À compter d'aujourd'hui",
                couleur: AppColors.blue,
              ),
            ],
          ),
          if (a.vide) ...[
            const SizedBox(height: 12),
            const _Amorce(
              texte:
                  'Rien en attente au service de santé. La pharmacie et les '
                  'visites se tiennent depuis leurs rubriques.',
              chemin: '/scolarite/consultations',
              action: 'Ouvrir les consultations',
            ),
          ],
        ],
      ),
    );
  }
}

/// L'accueil du Poste de police : ce qui entre et ce qui sort.
class _BlocPolice extends ConsumerWidget {
  const _BlocPolice();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apercu = ref.watch(apercuPoliceProvider);

    return apercu.when(
      loading: () => const _TuilesEnAttente(nombre: 4),
      error: (e, _) => _Incident(message: '$e'),
      data: (a) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GrilleDeTuiles(
            tuiles: [
              _Tuile(
                icone: Icons.badge_rounded,
                valeur: '${a.visiteursPresents}',
                titre: 'Visiteurs présents',
                legende: 'Entrés, pas encore ressortis',
                couleur: a.visiteursPresents > 0
                    ? AppColors.warning
                    : AppColors.success,
              ),
              _Tuile(
                icone: Icons.login_rounded,
                valeur: '${a.visiteursDuJour}',
                titre: 'Entrées du jour',
                legende: 'Depuis minuit',
                couleur: AppColors.blue,
              ),
              _Tuile(
                icone: Icons.no_crash_rounded,
                valeur: '${a.vehiculesSortis}',
                titre: 'Véhicules sortis',
                legende: 'Pas encore rentrés',
                couleur: a.vehiculesSortis > 0
                    ? AppColors.warning
                    : AppColors.success,
              ),
              _Tuile(
                icone: Icons.swap_horiz_rounded,
                valeur: '${a.mouvementsDuJour}',
                titre: 'Mouvements du jour',
                legende: 'Sorties enregistrées',
                couleur: AppColors.blueBright,
              ),
            ],
          ),
          if (a.vide) ...[
            const SizedBox(height: 12),
            const _Amorce(
              texte:
                  "Aucun passage enregistré. Le registre s'ouvre depuis la "
                  'rubrique Poste de Police.',
              chemin: '/logistique/poste-police',
              action: 'Ouvrir le poste',
            ),
          ],
        ],
      ),
    );
  }
}
