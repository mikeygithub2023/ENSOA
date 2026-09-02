import 'package:flutter/material.dart';

import '../../core/roles.dart';
import '../../models/profil.dart';

/// Les trois sections du menu. Un agent ne voit que celles où il a quelque
/// chose à faire : un armurier ne voit pas « Scolarité », un instructeur ne
/// voit pas « Soutien technique », et l'infirmerie voit les deux.
enum SectionNav { scolarite, soutienTechnique, commun }

extension SectionNavLibelle on SectionNav {
  String get libelle => switch (this) {
    SectionNav.scolarite => 'Scolarité',
    SectionNav.soutienTechnique => 'Soutien technique',
    SectionNav.commun => 'Général',
  };
}

class ElementNav {
  const ElementNav({
    required this.chemin,
    required this.libelle,
    required this.icone,
    required this.section,
    this.permissions = const {},
    this.iconeArme = false,
  });

  final String chemin;
  final String libelle;
  final IconData icone;
  final SectionNav section;

  /// Les permissions qui ouvrent cette entrée. Vide = ouverte à tous les
  /// comptes affectés. On ne teste jamais le rôle directement : ajouter un
  /// rôle ne doit pas obliger à rouvrir ce fichier.
  final Set<Permission> permissions;

  /// Material Icons ne propose délibérément aucune icône d'arme : l'armement
  /// utilise le dessin fourni avec l'application d'origine.
  final bool iconeArme;

  bool ouvertA(Profil profil) =>
      permissions.isEmpty || permissions.any(profil.peut);
}

/// Les chemins sont préfixés par module : `/admin`, `/notifications` et
/// `/login` existaient dans les deux applications d'origine et se seraient
/// percutés.
const elementsNav = <ElementNav>[
  ElementNav(
    chemin: '/',
    libelle: 'Accueil',
    icone: Icons.grid_view_rounded,
    section: SectionNav.commun,
  ),

  // Juste après l'accueil : ce qui attend une réponse doit se voir dès
  // l'ouverture, sans descendre la colonne. C'est la seule entrée qui porte
  // un compteur.
  ElementNav(
    chemin: '/notifications',
    libelle: 'Notifications',
    icone: Icons.notifications_rounded,
    section: SectionNav.commun,
  ),

  // Un seul tableau de bord pour les deux domaines : celui qui relève des
  // deux bascule de l'un à l'autre à l'intérieur de l'écran.
  ElementNav(
    chemin: '/tableau-de-bord',
    libelle: 'Tableau de bord',
    icone: Icons.insights_rounded,
    section: SectionNav.commun,
    permissions: {
      Permission.voirTableauBordScolarite,
      Permission.voirTableauBordLogistique,
    },
  ),

  // --- Scolarité ---
  ElementNav(
    chemin: '/scolarite/apprenants',
    libelle: 'Élèves & Stagiaires',
    icone: Icons.groups_rounded,
    section: SectionNav.scolarite,
    permissions: {Permission.consulterApprenants},
  ),
  ElementNav(
    chemin: '/scolarite/cours',
    libelle: 'Cours',
    icone: Icons.school_rounded,
    section: SectionNav.scolarite,
    permissions: {Permission.gererCours, Permission.suivreCours},
  ),
  ElementNav(
    chemin: '/scolarite/matieres',
    libelle: 'Matières',
    icone: Icons.menu_book_rounded,
    section: SectionNav.scolarite,
    permissions: {Permission.gererMatieres},
  ),
  ElementNav(
    chemin: '/scolarite/bulletins',
    libelle: 'Bulletins',
    icone: Icons.assignment_turned_in_rounded,
    section: SectionNav.scolarite,
    permissions: {Permission.editerBulletins},
  ),
  ElementNav(
    chemin: '/scolarite/consultations',
    libelle: 'Consultations',
    icone: Icons.medical_services_rounded,
    section: SectionNav.scolarite,
    permissions: {Permission.gererConsultations},
  ),
  ElementNav(
    chemin: '/scolarite/visites-medicales',
    libelle: 'Visites médicales',
    icone: Icons.event_available_rounded,
    section: SectionNav.scolarite,
    permissions: {Permission.gererVisitesMedicales},
  ),
  ElementNav(
    chemin: '/scolarite/pharmacie',
    libelle: 'Pharmacie',
    icone: Icons.medication_rounded,
    section: SectionNav.scolarite,
    permissions: {Permission.gererPharmacie},
  ),
  ElementNav(
    chemin: '/scolarite/depenses',
    libelle: 'Dépenses santé',
    icone: Icons.receipt_long_rounded,
    section: SectionNav.scolarite,
    permissions: {Permission.gererDepensesSante},
  ),
  ElementNav(
    chemin: '/scolarite/mon-espace',
    libelle: 'Mon espace',
    icone: Icons.badge_rounded,
    section: SectionNav.scolarite,
    permissions: {Permission.voirSonEspaceEleve},
  ),

  // --- Soutien technique ---
  ElementNav(
    chemin: '/logistique/parc',
    libelle: 'Parc automobile',
    icone: Icons.directions_car_filled_rounded,
    section: SectionNav.soutienTechnique,
    permissions: {Permission.gererParc, Permission.gererMaintenance},
  ),
  ElementNav(
    chemin: '/logistique/carburant',
    libelle: 'Carburant',
    icone: Icons.local_gas_station_rounded,
    section: SectionNav.soutienTechnique,
    permissions: {Permission.gererCarburant},
  ),
  ElementNav(
    chemin: '/logistique/armement',
    libelle: 'Armement',
    icone: Icons.security_rounded,
    iconeArme: true,
    section: SectionNav.soutienTechnique,
    permissions: {Permission.gererArmement},
  ),
  ElementNav(
    chemin: '/logistique/poste-police',
    libelle: 'Poste de Police',
    icone: Icons.local_police_rounded,
    section: SectionNav.soutienTechnique,
    permissions: {Permission.gererPostePolice},
  ),
  ElementNav(
    chemin: '/logistique/activites',
    libelle: 'Activités',
    icone: Icons.event_note_rounded,
    section: SectionNav.soutienTechnique,
    permissions: {Permission.gererActivites},
  ),
  ElementNav(
    chemin: '/logistique/mes-taches',
    libelle: 'Mes tâches',
    icone: Icons.checklist_rounded,
    section: SectionNav.soutienTechnique,
    permissions: {Permission.voirMesTaches},
  ),
  ElementNav(
    chemin: '/logistique/taches-equipe',
    libelle: "Tâches de l'équipe",
    icone: Icons.groups_2_rounded,
    section: SectionNav.soutienTechnique,
    permissions: {Permission.voirTachesEquipe},
  ),

  ElementNav(
    chemin: '/audit',
    libelle: "Journal d'audit",
    icone: Icons.fact_check_rounded,
    section: SectionNav.commun,
    permissions: {Permission.voirJournalAudit},
  ),
  ElementNav(
    chemin: '/administration',
    libelle: 'Administration',
    icone: Icons.admin_panel_settings_rounded,
    section: SectionNav.commun,
    permissions: {
      Permission.gererUtilisateurs,
      Permission.administrerPlateforme,
      Permission.administrerScolarite,
    },
  ),
];

/// Les entrées visibles pour ce profil, dans l'ordre de déclaration.
List<ElementNav> elementsPour(Profil profil) =>
    elementsNav.where((e) => e.ouvertA(profil)).toList();
