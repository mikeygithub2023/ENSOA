import 'package:sig_ensoa/core/roles.dart';
import '../models/armement.dart';
import '../models/audit_entry.dart';
import '../models/maintenance.dart';
import '../models/mouvement_vehicule.dart';
import '../models/notification_item.dart';
import '../models/user.dart';
import '../models/vehicule.dart';

/// Données factices — permettent de faire fonctionner et démontrer l'app
/// sans backend réel. Structure alignée sur l'analyse HFSQL réelle (CST.wda).
/// À remplacer par de vrais repositories (webservice REST) en implémentant
/// les mêmes interfaces que celles utilisées par l'UI.
final now = DateTime.now();

// --- Organisation (SERVICE / CELLULE) ---------------------------------

// --- Comptes applicatifs (UTILISATEUR) ---------------------------------

final List<AppUser> seedUsers = [
  const AppUser(
    id: 'u1',
    matricule: 'ENSOA-0001',
    nomComplet: 'Cdt Diabaté N.',
    grade: 'Commandant',
    role: RoleLogistique.chefSoutienTechnique,
    celluleId: 'c4',
  ),
  const AppUser(
    id: 'u2',
    matricule: 'ENSOA-0298',
    nomComplet: 'Adj Bamba S.',
    grade: 'Adjudant',
    role: RoleLogistique.soutienPetrolier,
    celluleId: 'c1',
  ),
  const AppUser(
    id: 'u3',
    matricule: 'ENSOA-0410',
    nomComplet: 'Cpl Yao R.',
    grade: 'Caporal',
    role: RoleLogistique.garage,
    celluleId: 'c2',
  ),
  const AppUser(
    id: 'u4',
    matricule: 'ENSOA-0355',
    nomComplet: 'Sgt Traoré M.',
    grade: 'Sergent',
    role: RoleLogistique.armurerie,
    celluleId: 'c3',
  ),
];

// --- Référentiel véhicules (MARQUE_VHL / MODELE_VHL / TYPE_VHL) ---------

final List<MarqueVehicule> seedMarques = [
  const MarqueVehicule(id: 'mq1', marque: 'Toyota'),
  const MarqueVehicule(id: 'mq2', marque: 'Renault'),
  const MarqueVehicule(id: 'mq3', marque: 'Mercedes'),
];

final List<ModeleVehicule> seedModeles = [
  const ModeleVehicule(id: 'mo1', modele: 'Land Cruiser', marqueId: 'mq1'),
  const ModeleVehicule(id: 'mo2', modele: 'Sherpa', marqueId: 'mq2'),
  const ModeleVehicule(id: 'mo3', modele: 'G-Wagon', marqueId: 'mq3'),
  const ModeleVehicule(id: 'mo4', modele: 'Hilux', marqueId: 'mq1'),
];

final List<TypeVehicule> seedTypesVehicule = [
  const TypeVehicule(id: 'tv1', type: '4x4 tout-terrain', modeleId: 'mo1'),
  const TypeVehicule(id: 'tv2', type: 'Camion militaire', modeleId: 'mo2'),
  const TypeVehicule(
    id: 'tv3',
    type: 'Véhicule de commandement',
    modeleId: 'mo3',
  ),
  const TypeVehicule(id: 'tv4', type: 'Pick-up', modeleId: 'mo4'),
];

// --- Parc automobile (VEHICULE) -----------------------------------------

final List<Vehicule> seedVehicules = [
  const Vehicule(
    id: 'v1',
    chassis: 'JTMHV05J904123456',
    immatriculation: 'CI-2201-EN',
    kilometrage: 54200,
    etat: EtatVehicule.disponible,
    positionActuelle: 'Camp ENSOA — 3e Promotion',
    nbrePlaces: 7,
    typeVehiculeId: 'tv1',
    kilometrageVidangeProchaine: 58000,
    kilometrageVidangePrecedente: 48000,
    marque: 'Toyota',
    modele: 'Land Cruiser',
    typeVehicule: '4x4 tout-terrain',
  ),
  const Vehicule(
    id: 'v2',
    chassis: 'VF631CA0000112233',
    immatriculation: 'CI-1187-EN',
    kilometrage: 88750,
    etat: EtatVehicule.enReparation,
    positionActuelle: 'Garage central ENSOA',
    nbrePlaces: 24,
    observations: 'Transport troupe',
    typeVehiculeId: 'tv2',
    kilometrageVidangeProchaine: 90000,
    marque: 'Renault',
    modele: 'Sherpa',
    typeVehicule: 'Camion militaire',
  ),
  const Vehicule(
    id: 'v3',
    chassis: 'WDB4632451X998877',
    immatriculation: 'CI-3390-EN',
    kilometrage: 31200,
    etat: EtatVehicule.enMission,
    positionActuelle: 'En route — Camp Zambakro',
    nbrePlaces: 5,
    observations: 'Véhicule de commandement, État-major',
    typeVehiculeId: 'tv3',
    kilometrageVidangeProchaine: 35000,
    kilometrageVidangePrecedente: 28000,
    marque: 'Mercedes',
    modele: 'G-Wagon',
    typeVehicule: 'Véhicule de commandement',
  ),
  const Vehicule(
    id: 'v4',
    chassis: 'JTFHX22G500445566',
    immatriculation: 'CI-0765-EN',
    kilometrage: 102300,
    etat: EtatVehicule.horsService,
    positionActuelle: 'Garage central ENSOA',
    nbrePlaces: 5,
    typeVehiculeId: 'tv4',
    kilometrageVidangeProchaine: 100000,
    kilometrageVidangePrecedente: 92000,
    marque: 'Toyota',
    modele: 'Hilux',
    typeVehicule: 'Pick-up',
  ),
];

// --- Maintenance (REPARATION / VIDANGE) ----------------------------------

final List<Reparation> seedReparations = [
  Reparation(
    id: 'r1',
    dateEntree: now.subtract(const Duration(days: 3)),
    pannesConstatees: 'Fuite hydraulique — direction assistée',
    chefEquipe: 'Cpl Yao R.',
    vehiculeId: 'v2',
    utilisateurId: 'u3',
  ),
  Reparation(
    id: 'r2',
    dateEntree: now.subtract(const Duration(days: 20)),
    dateSortie: now.subtract(const Duration(days: 12)),
    pannesConstatees: 'Panne moteur — surchauffe récurrente',
    solutionsApportees: 'Remplacement radiateur et durites',
    chefEquipe: 'Cpl Yao R.',
    vehiculeId: 'v4',
    utilisateurId: 'u3',
  ),
];

final List<Vidange> seedVidanges = [
  Vidange(
    id: 'vg1',
    date: now.subtract(const Duration(days: 45)),
    filtreVidange: 'Filtre standard',
    typeHuile: '15W40',
    qteHuile: 8,
    vehiculeId: 'v1',
    utilisateurId: 'u3',
  ),
];

// --- Trajets véhicules (MOUVEMENT) ----------------------------------------

final List<MouvementVehicule> seedMouvementsVehicule = [
  MouvementVehicule(
    id: 'mv1',
    objet: 'Ravitaillement inter-camps',
    dateDepart: now.subtract(const Duration(hours: 6)),
    etat: EtatMouvement.enCours,
    vehiculeId: 'v3',
    utilisateurId: 'u2',
    kmDepart: 31100,
    destination: 'Camp Zambakro',
    gradeChefBord: 'Sgt',
    nomChefBord: 'Kouassi',
    contactChefBord: '0700000000',
  ),
];

// Carburant (SOUTE / TYPE_STOCK / SOUTE_TYPE_STOCK / DEPOTAGE / DISTRIBUTION)
// est entièrement branché sur Supabase — plus de données mock ici.

// --- Armement (nouveau module, sans équivalent dans l'analyse CST) -------

final List<Arme> seedArmes = [
  Arme(
    id: 'a1',
    numeroSerie: 'FA-2024-0113',
    type: "Fusil d'assaut",
    modele: 'FAMAS',
    etat: EtatArme.bon,
    dateAcquisition: DateTime(2020, 6, 1),
    derniereInspection: now.subtract(const Duration(days: 40)),
    prochaineInspection: now.add(const Duration(days: 50)),
  ),
  Arme(
    id: 'a2',
    numeroSerie: 'PA-2019-0876',
    type: 'Pistolet automatique',
    modele: 'PAMAS G1',
    etat: EtatArme.bon,
    dateAcquisition: DateTime(2019, 2, 10),
    derniereInspection: now.subtract(const Duration(days: 95)),
    prochaineInspection: now.subtract(const Duration(days: 5)),
  ),
  Arme(
    id: 'a3',
    numeroSerie: 'FA-2022-0455',
    type: "Fusil d'assaut",
    modele: 'AK-47',
    etat: EtatArme.defectueux,
    dateAcquisition: DateTime(2022, 11, 3),
    derniereInspection: now.subtract(const Duration(days: 10)),
    prochaineInspection: now.add(const Duration(days: 80)),
  ),
];

final List<DotationArme> seedDotations = [
  DotationArme(
    id: 'do1',
    armeId: 'a1',
    beneficiaireId: 'ENSOA-0355',
    beneficiaireNom: 'Adjudant Koffi',
    dateRemise: now.subtract(const Duration(days: 10)),
    dateRetourPrevue: now.add(const Duration(days: 4)),
    remisePar: 'u4',
    motif: 'Garde de nuit',
  ),
  DotationArme(
    id: 'do2',
    armeId: 'a2',
    beneficiaireId: 'ENSOA-0410',
    beneficiaireNom: 'Sergent Diabaté',
    dateRemise: now.subtract(const Duration(days: 30)),
    dateRetourPrevue: now.subtract(const Duration(days: 2)),
    remisePar: 'u4',
    motif: 'Instruction tir',
  ),
];

final List<StockMunition> seedMunitions = [
  const StockMunition(
    id: 'mu1',
    calibre: '5.56x45mm',
    quantiteDisponible: 1200,
    seuilCritique: 500,
    souteArmementId: 'armurerie-1',
  ),
  const StockMunition(
    id: 'mu2',
    calibre: '9x19mm',
    quantiteDisponible: 180,
    seuilCritique: 200,
    souteArmementId: 'armurerie-1',
  ),
];

// --- Notifications / Audit -------------------------------------------------

final List<AppNotification> seedNotifications = [
  AppNotification(
    id: 'n1',
    categorie: NotificationCategory.carburant,
    titre: 'Seuil critique atteint',
    message: 'Soute Gasoil A sous le seuil critique (4200 L / 5000 L).',
    date: now.subtract(const Duration(hours: 2)),
  ),
  AppNotification(
    id: 'n2',
    categorie: NotificationCategory.armement,
    titre: 'Retour d\'arme en retard',
    message: 'PAMAS G1 (PA-2019-0876) — retour attendu depuis 2 jours.',
    date: now.subtract(const Duration(hours: 5)),
  ),
  AppNotification(
    id: 'n3',
    categorie: NotificationCategory.maintenance,
    titre: 'Réparation en cours',
    message: 'Renault Sherpa (CI-1187-EN) — fuite hydraulique signalée.',
    date: now.subtract(const Duration(days: 3)),
  ),
];

final List<AuditEntry> seedAudit = [
  AuditEntry(
    id: 'au1',
    date: now.subtract(const Duration(days: 5)),
    auteurId: 'u2',
    action: 'DEPOTAGE_CREE',
    cible: 'Soute Gasoil A',
    detail: '+8000 L',
  ),
];
