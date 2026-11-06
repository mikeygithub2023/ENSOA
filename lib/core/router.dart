import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/accueil/accueil_screen.dart';
import '../features/administration/administration_screen.dart';
import '../features/auth/changer_mot_de_passe_screen.dart';
import '../features/auth/connexion_screen.dart';
import '../features/auth/providers/auth_providers.dart';
import '../features/shell/app_shell.dart';
import '../features/shell/nav_items.dart';
import '../modules/logistique/data/models/armement.dart';
import '../modules/logistique/data/models/oa.dart';
import '../modules/logistique/data/models/vehicule.dart';
import '../modules/logistique/features/armament/armament_screen.dart';
import '../modules/logistique/features/armament/weapon_detail_screen.dart';
import '../modules/logistique/features/audit/audit_screen.dart';
import '../modules/logistique/features/dashboard/soutien_technique_screen.dart';
import '../modules/scolarite/features/scolarite_screen.dart';
import '../modules/logistique/features/fleet/garage_workspace_screen.dart';
import '../modules/logistique/features/fleet/vehicle_detail_screen.dart';
import '../modules/logistique/features/fuel/fuel_screen.dart';
import '../modules/logistique/features/notifications/notifications_screen.dart';
import '../modules/logistique/features/oa/activite_detail_screen.dart';
import '../modules/logistique/features/oa/oa_screen.dart';
import '../modules/logistique/features/police/police_screen.dart';
import '../modules/logistique/features/tasks/mes_taches_screen.dart';
import '../modules/logistique/features/tasks/taches_equipe_screen.dart';
import '../modules/scolarite/features/apprenants/apprenants_list_screen.dart';
import '../modules/scolarite/features/apprenants/apprenant_detail_screen.dart';
import '../modules/scolarite/features/apprenants/controle_detail_screen.dart';
import '../modules/scolarite/features/apprenants/mon_profil_screen.dart';
import '../modules/scolarite/features/bulletins/bulletins_screen.dart';
import '../modules/scolarite/features/consultations/consultations_screen.dart';
import '../modules/scolarite/features/cours/cours_screen.dart';
import '../modules/scolarite/features/depenses/depenses_screen.dart';
import '../modules/scolarite/features/matieres/matieres_screen.dart';
import '../modules/scolarite/features/medicaments/medicaments_screen.dart';
import '../modules/scolarite/features/visites/visites_medicales_screen.dart';
import '../modules/scolarite/features/visites/visite_medicale_detail_screen.dart';
import '../shared/widgets/ecran_a_venir.dart';
import 'supabase_client.dart';

/// Réveille le routeur quand la session ou le profil changent — le second
/// compte autant que le premier : c'est le profil qui dit si l'agent doit
/// d'abord remplacer son mot de passe.
class _Rafraichisseur extends ChangeNotifier {
  _Rafraichisseur(Ref ref) {
    ref.listen(changementsDeSessionProvider, (_, _) => notifyListeners());
    ref.listen(profilCourantProvider, (_, _) => notifyListeners());
  }
}

/// Les écrans effectivement portés. Les autres chemins tombent sur un
/// emplacement provisoire : le menu ne mène jamais au vide, et ce qui manque
/// se lit d'un coup d'œil.
final _ecransPortes = <String, Widget Function()>{
  '/administration': () => const AdministrationScreen(),

  // Scolarité
  // Le regroupement du super administrateur, comme « Soutien technique ».
  '/scolarite/rubrique': () => const ScolariteScreen(),
  '/scolarite/apprenants': () => const ApprenantsListScreen(),
  '/scolarite/cours': () => const CoursScreen(),
  '/scolarite/matieres': () => const MatieresScreen(),
  '/scolarite/bulletins': () => const BulletinsScreen(),
  '/scolarite/consultations': () => const ConsultationsScreen(),
  '/scolarite/visites-medicales': () => const VisitesMedicalesScreen(),
  '/scolarite/pharmacie': () => const MedicamentsScreen(),
  '/scolarite/depenses': () => const DepensesScreen(),
  '/scolarite/mon-espace': () => const MonProfilScreen(),

  // Soutien technique
  // Le regroupement des trois dashboards (garage, carburant, armurerie) sous
  // une seule rubrique — réservé au super administrateur par la permission qui
  // ouvre son entrée de menu.
  '/logistique/soutien-technique': () => const SoutienTechniqueScreen(),
  // Le Garage est désormais un espace à onglets (tableau de bord, liste des
  // véhicules, et bientôt les ordres de mission) plutôt que la seule liste.
  '/logistique/parc': () => const GarageWorkspaceScreen(),
  '/logistique/carburant': () => const FuelScreen(),
  '/logistique/armement': () => const ArmamentScreen(),
  '/logistique/poste-police': () => const PoliceScreen(),
  '/logistique/activites': () => const OaScreen(),
  '/logistique/mes-taches': () => const MesTachesScreen(),
  '/logistique/taches-equipe': () => const TachesEquipeScreen(),

  // Communs aux deux modules
  '/notifications': () => const NotificationsScreen(),
  '/audit': () => const AuditScreen(),
};

/// D'où vient chaque écran encore à porter. Le tableau tient lieu de reste à
/// faire : il se vide à mesure que les écrans arrivent.
const _origines = <String, String>{
  '/scolarite/': 'ENSOA GSES',
  '/logistique/': 'ERP ENSOA',
};

String _origineDe(String chemin) {
  for (final e in _origines.entries) {
    if (chemin.startsWith(e.key)) return e.value;
  }
  return 'les deux applications';
}

final routeurProvider = Provider<GoRouter>((ref) {
  final rafraichisseur = _Rafraichisseur(ref);
  ref.onDispose(rafraichisseur.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: rafraichisseur,
    redirect: (context, state) {
      final connecte = supabase.auth.currentSession != null;
      final surConnexion = state.matchedLocation == '/connexion';
      final surChangement = state.matchedLocation == '/changer-mot-de-passe';

      if (!connecte) return surConnexion ? null : '/connexion';

      // Le profil peut être encore en cours de chargement : on laisse passer,
      // le cadre affiche l'attente. Il n'y a rien à protéger ici que la RLS
      // ne protège déjà côté serveur.
      final profil = ref.read(profilCourantProvider).value;

      if (profil != null && profil.doitChangerMotDePasse) {
        return surChangement ? null : '/changer-mot-de-passe';
      }
      if (surConnexion || surChangement) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/connexion',
        builder: (context, state) => const ConnexionScreen(),
      ),
      GoRoute(
        path: '/changer-mot-de-passe',
        builder: (context, state) => const ChangerMotDePasseScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const AccueilScreen(),
          ),
          // L'ancienne adresse du tableau de bord, fusionné dans le premier
          // bouton : une PWA restée ouverte ou un lien conservé y mène encore.
          GoRoute(path: '/tableau-de-bord', redirect: (_, _) => '/'),

          // Les fiches de la scolarité, désignées par identifiant. L'ordre
          // compte : `controles/:id` doit passer avant `:id`, sinon ce
          // dernier avalerait le segment « controles ».
          GoRoute(
            path: '/scolarite/apprenants/controles/:id',
            builder: (context, state) =>
                ControleDetailScreen(controleId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/scolarite/apprenants/:id',
            builder: (context, state) =>
                ApprenantDetailScreen(apprenantId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/scolarite/visites-medicales/:id',
            builder: (context, state) => VisiteMedicaleDetailScreen(
              visiteId: state.pathParameters['id']!,
            ),
          ),

          // Les fiches de détail : elles reçoivent leur objet par `extra`,
          // comme dans l'application d'origine.
          GoRoute(
            path: '/logistique/parc/detail',
            builder: (context, state) =>
                VehicleDetailScreen(vehicule: state.extra as Vehicule),
          ),
          GoRoute(
            path: '/logistique/armement/detail',
            builder: (context, state) =>
                WeaponDetailScreen(arme: state.extra as Arme),
          ),
          GoRoute(
            path: '/logistique/activites/detail',
            builder: (context, state) =>
                ActiviteDetailScreen(activite: state.extra as Activite),
          ),

          // Chaque entrée du menu a sa route. Les écrans des deux modules
          // arrivent un par un ; d'ici là l'emplacement est tenu, plutôt
          // qu'un menu qui mènerait au vide.
          for (final entree in elementsNav.where((e) => e.chemin != '/'))
            GoRoute(
              path: entree.chemin,
              builder: (context, state) =>
                  _ecransPortes[entree.chemin]?.call() ??
                  EcranAVenir(
                    titre: entree.libelle,
                    origine: _origineDe(entree.chemin),
                  ),
            ),
        ],
      ),
    ],
  );
});
