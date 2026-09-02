import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/postes.dart';
import '../../core/push.dart';
import '../../core/roles.dart';
import '../../core/theme.dart';
import '../../core/verrou_inactivite.dart';
import '../../shared/widgets/icone_arme.dart';
import '../../modules/logistique/data/repositories/armament_providers.dart';
import '../../modules/logistique/data/repositories/fleet_providers.dart';
import '../../modules/logistique/data/repositories/fuel_providers.dart';
import '../../modules/logistique/data/repositories/misc_providers.dart';
import '../../modules/logistique/data/repositories/oa_providers.dart';
import '../../modules/logistique/data/repositories/police_providers.dart';
import '../../modules/scolarite/features/dashboard/providers/dashboard_providers.dart';
import '../accueil/providers/apercu_providers.dart';
import '../auth/ecran_demarrage.dart';
import '../auth/providers/auth_providers.dart';
import 'nav_items.dart';

/// Le cadre de l'application, repris tel quel de la tablette : barre d'icônes
/// en pastille à gauche, grande carte blanche flottante à droite, en-tête
/// « Bonjour », et l'animation d'arrivée en trois temps.
///
/// Ce qui change, et seulement ça : la barre porte désormais les icônes des
/// DEUX modules, filtrées par les permissions du profil. Un armurier voit ce
/// qu'il voyait ; l'infirmerie voit ses consultations et ses tâches.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.child, required this.location});

  final Widget child;
  final String location;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

/// Anime l'arrivée du cadre (barre, en-tête, carte de contenu) une seule fois,
/// au premier affichage après connexion — chaque bloc glisse depuis
/// l'extérieur en fondu vers sa place, pendant que le contenu charge ses
/// données, donnant l'impression d'une seule animation.
class _AppShellState extends ConsumerState<AppShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  )..forward();

  bool _jetonDepose = false;

  late final Animation<double> _fadeBarre = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
  );
  late final Animation<Offset> _slideBarre =
      Tween<Offset>(begin: const Offset(-0.5, 0), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
        ),
      );

  late final Animation<double> _fadeEntete = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.1, 0.8, curve: Curves.easeOut),
  );
  late final Animation<Offset> _slideEntete =
      Tween<Offset>(begin: const Offset(0, -0.4), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.1, 0.9, curve: Curves.easeOutCubic),
        ),
      );

  late final Animation<double> _fadeContenu = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.15, 0.9, curve: Curves.easeOut),
  );
  late final Animation<Offset> _slideContenu =
      Tween<Offset>(begin: const Offset(0.12, 0.08), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.15, 1.0, curve: Curves.easeOutCubic),
        ),
      );

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _rafraichirPourModule(widget.location));
  }

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.location != widget.location) {
      Future.microtask(() => _rafraichirPourModule(widget.location));
    }
  }

  /// Un provider Riverpod ne se recharge que sur action explicite : sans ça,
  /// rouvrir un module afficherait les données du dernier chargement, même si
  /// un autre poste les a modifiées entretemps. On force donc un
  /// rafraîchissement en entrant dans un module. Repris de l'application du
  /// soutien technique, où le besoin est le plus net : le poste de police et
  /// le garage travaillent sur les mêmes véhicules.
  void _rafraichirPourModule(String chemin) {
    // Revenir à l'accueil après avoir saisi quelque chose doit montrer le
    // nouveau chiffre, pas celui du premier affichage.
    if (chemin == '/') {
      ref.invalidate(apercuScolariteProvider);
      ref.invalidate(apercuLogistiqueProvider);
      return;
    }

    if (!chemin.startsWith('/logistique') &&
        chemin != '/audit' &&
        chemin != '/notifications' &&
        chemin != '/tableau-de-bord') {
      return;
    }

    // Le tableau de bord unifié lit les deux domaines : la scolarité par un
    // provider qu'on invalide, le soutien technique par les notifiers ci-après.
    if (chemin == '/tableau-de-bord') {
      ref.invalidate(dashboardStatsProvider);
    }

    ref.read(notificationsProvider.notifier).refresh();

    switch (chemin) {
      case '/tableau-de-bord':
        ref.read(vehiculesProvider.notifier).refresh();
        ref.read(soutesProvider.notifier).refresh();
        ref.read(souteStocksProvider.notifier).refresh();
        ref.read(depotagesProvider.notifier).refresh();
        ref.read(distributionsProvider.notifier).refresh();
        ref.read(armesProvider.notifier).refresh();
        ref.read(dotationsProvider.notifier).refresh();
      case '/logistique/parc':
        ref.read(vehiculesProvider.notifier).refresh();
        ref.read(reparationsProvider.notifier).refresh();
        ref.read(vidangesProvider.notifier).refresh();
        ref.read(mouvementsVehiculeProvider.notifier).refresh();
      case '/logistique/carburant':
        ref.read(soutesProvider.notifier).refresh();
        ref.read(souteStocksProvider.notifier).refresh();
        ref.read(depotagesProvider.notifier).refresh();
        ref.read(distributionsProvider.notifier).refresh();
        ref.read(repartitionsProvider.notifier).refresh();
      case '/logistique/armement':
        ref.read(armesProvider.notifier).refresh();
        ref.read(dotationsProvider.notifier).refresh();
        ref.read(munitionsProvider.notifier).refresh();
        ref.read(equipementsProvider.notifier).refresh();
        ref.read(typesArmeProvider.notifier).refresh();
      case '/logistique/poste-police':
        ref.read(passagesVisiteursProvider.notifier).refresh();
        ref.read(passagesVehiculesProvider.notifier).refresh();
        ref.read(vehiculesProvider.notifier).refresh();
        ref.read(mouvementsVehiculeProvider.notifier).refresh();
      case '/audit':
        ref.read(auditProvider.notifier).refresh();
        ref.read(usersProvider.notifier).refresh();
      case '/logistique/activites':
        ref.read(activitesProvider.notifier).refresh();
        ref.read(tachesProvider.notifier).refresh();
      case '/logistique/mes-taches':
      case '/logistique/taches-equipe':
        ref.read(tachesProvider.notifier).refresh();
        ref.read(activitesProvider.notifier).refresh();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profilAsync = ref.watch(profilCourantProvider);

    return profilAsync.when(
      loading: () => const EcranDemarrage(),
      error: (e, _) => _Impasse(titre: 'Profil illisible', texte: '$e'),
      data: (profil) {
        if (profil == null) {
          return const _Impasse(
            titre: 'Compte non rattaché',
            texte:
                "Ce compte existe mais n'est rattaché à aucun poste. "
                "Demandez à l'administrateur de vous affecter.",
          );
        }
        // Le jeton de notification se dépose une fois, dès que le profil est
        // connu : c'est lui qui dit dans quels registres l'agent doit être
        // inscrit — ceux de la scolarité, du soutien technique, ou les deux.
        if (!_jetonDepose) {
          _jetonDepose = true;
          Push.enregistrer(profil);
        }

        if (!profil.actif) {
          return const _Impasse(
            titre: 'Compte désactivé',
            texte:
                "Votre compte a été désactivé. Adressez-vous à l'administrateur.",
          );
        }

        // Le journal d'audit garde sa place réservée en bas de la barre. Les
        // notifications, elles, remontent en deuxième position : ce qui
        // attend une réponse doit se voir dès l'ouverture.
        final entrees = elementsPour(
          profil,
        ).where((e) => e.chemin != '/audit').toList();
        final large = MediaQuery.of(context).size.width > 900;
        final poste = posteDepuisRoles(
          profil.roleScolarite,
          profil.roleLogistique,
        );

        return VerrouInactivite(
          child: Scaffold(
            backgroundColor: AppColors.canvas,
            resizeToAvoidBottomInset: false,
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SlideTransition(
                      position: _slideBarre,
                      child: FadeTransition(
                        opacity: _fadeBarre,
                        child: _Barre(
                          entrees: entrees,
                          location: widget.location,
                          voitAudit: profil.peut(Permission.voirJournalAudit),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: SlideTransition(
                        position: _slideContenu,
                        child: FadeTransition(
                          opacity: _fadeContenu,
                          child: Container(
                            padding: EdgeInsets.fromLTRB(
                              large ? 32 : 20,
                              24,
                              large ? 32 : 20,
                              20,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.cardBg,
                              borderRadius: BorderRadius.circular(
                                AppRadii.shell,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SlideTransition(
                                  position: _slideEntete,
                                  child: FadeTransition(
                                    opacity: _fadeEntete,
                                    child: _Entete(
                                      nomComplet: profil.nomComplet,
                                      grade: profil.grade ?? '',
                                      poste: profil.appellation(poste?.libelle),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Expanded(child: widget.child),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Barre extends ConsumerStatefulWidget {
  const _Barre({
    required this.entrees,
    required this.location,
    required this.voitAudit,
  });

  final List<ElementNav> entrees;
  final String location;
  final bool voitAudit;

  @override
  ConsumerState<_Barre> createState() => _BarreState();
}

class _BarreState extends ConsumerState<_Barre> {
  bool _deconnexionEnCours = false;

  Future<void> _confirmerDeconnexion() async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Déconnexion'),
        content: const Text('Voulez-vous vraiment vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Déconnecter'),
          ),
        ],
      ),
    );
    if (confirme != true || !mounted) return;
    setState(() => _deconnexionEnCours = true);
    // Le jeton part avec la session : celui qui reprend la tablette ne doit
    // pas recevoir les notifications du précédent.
    await Push.oublier();
    await ref.read(authRepositoryProvider).deconnexion();
    // Pas de remise à zéro de l'état : ce widget est démonté juste après.
  }

  @override
  Widget build(BuildContext context) {
    // Le compteur des notifications non lues. Il se met à jour tout seul :
    // la barre suit la liste, et la liste se recharge à chaque passage sur
    // l'écran des notifications.
    final nonLues = ref
        .watch(notificationsProvider)
        .where((n) => !n.lue)
        .length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Container(
            width: 72,
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: AppColors.pillBg,
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
            // Défilante : les deux modules réunis, un administrateur peut
            // avoir plus d'icônes que la hauteur d'une tablette.
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final e in widget.entrees) ...[
                    _Icone(
                      icone: e.icone,
                      iconeArme: e.iconeArme,
                      libelle: e.libelle,
                      actif: e.chemin == '/'
                          ? widget.location == '/'
                          : widget.location.startsWith(e.chemin),
                      // Seules les notifications portent un compteur : le
                      // reste de la barre n'a rien qui attende une réponse.
                      badge: e.chemin == '/notifications' ? nonLues : 0,
                      onTap: () => context.go(e.chemin),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (widget.voitAudit) ...[
                    const SizedBox(height: 8),
                    _Icone(
                      icone: Icons.fact_check_rounded,
                      libelle: "Journal d'audit",
                      actif: widget.location.startsWith('/audit'),
                      onTap: () => context.go('/audit'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.pillBg,
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
          alignment: Alignment.center,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _deconnexionEnCours ? null : _confirmerDeconnexion,
            child: _deconnexionEnCours
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: AppColors.navy,
                    ),
                  )
                : const Icon(
                    Icons.logout_rounded,
                    color: AppColors.navy,
                    size: 24,
                  ),
          ),
        ),
      ],
    );
  }
}

class _Icone extends StatelessWidget {
  const _Icone({
    this.iconeArme = false,
    required this.icone,
    required this.libelle,
    required this.actif,
    required this.onTap,
    this.badge = 0,
  });

  final IconData icone;
  final bool iconeArme;
  final String libelle;
  final bool actif;
  final VoidCallback onTap;

  /// Combien attendent une réponse. Zéro : rien ne s'affiche.
  final int badge;

  @override
  Widget build(BuildContext context) {
    // L'infobulle est la seule addition : la barre ne porte que des icônes, et
    // elle en porte désormais celles de deux modules.
    return Tooltip(
      message: badge > 0 ? '$libelle ($badge non lue(s))' : libelle,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: actif ? AppColors.navy : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: iconeArme
                  ? ColorFiltered(
                      colorFilter: ColorFilter.mode(
                        actif ? Colors.white : AppColors.inkMuted,
                        BlendMode.srcIn,
                      ),
                      child: const IconeArme(size: 30),
                    )
                  : Icon(
                      icone,
                      color: actif ? Colors.white : AppColors.inkMuted,
                      size: 22,
                    ),
            ),
            // La pastille déborde du cercle, en haut à droite, pour rester
            // lisible sur une icône de 44 pixels. Au-delà de neuf, le chiffre
            // exact importe moins que le fait qu'il y en ait beaucoup.
            if (badge > 0)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  constraints: const BoxConstraints(minWidth: 18),
                  decoration: BoxDecoration(
                    color: AppColors.danger,
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: AppColors.pillBg, width: 2),
                  ),
                  child: Text(
                    badge > 9 ? '9+' : '$badge',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Entete extends StatelessWidget {
  const _Entete({
    required this.nomComplet,
    required this.grade,
    required this.poste,
  });

  final String nomComplet;
  final String grade;
  final String poste;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                grade.isEmpty ? 'Bonjour' : 'Bonjour, $grade',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$nomComplet · $poste',
                style: const TextStyle(fontSize: 13, color: AppColors.inkMuted),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.navy,
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.shield_outlined, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text(
                poste,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Compte connecté mais qui n'ouvre rien — sur le fond de l'application
/// plutôt que sur un écran nu.
class _Impasse extends ConsumerWidget {
  const _Impasse({required this.titre, required this.texte});

  final String titre;
  final String texte;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(AppRadii.card),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock_outline,
                  size: 44,
                  color: AppColors.inkMuted,
                ),
                const SizedBox(height: 16),
                Text(
                  titre,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  texte,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.inkMuted),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () =>
                      ref.read(authRepositoryProvider).deconnexion(),
                  child: const Text('Se déconnecter'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
