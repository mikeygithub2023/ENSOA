-- ============================================================================
-- LOGISTIQUE (ERP ENSOA) — repris de schema.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- ============================================================================
-- Schéma ERP ST-ENSOA — Supabase (PostgreSQL)
-- Aligné sur l'analyse HFSQL réelle (CST.wda) fournie par l'utilisateur.
-- À exécuter dans Supabase : Project → SQL Editor → New query → coller → Run.
--
-- CONCEPT : contrairement à HFSQL (protocole propriétaire), Postgres/Supabase
-- expose une API REST générée automatiquement (PostgREST) + un système de
-- sécurité "Row Level Security" (RLS) : chaque table décide, ligne par ligne,
-- qui a le droit de lire/écrire selon l'utilisateur connecté (auth.uid()).
-- C'est l'équivalent Postgres de notre système de permissions Dart
-- (UserRole/Permission), mais appliqué côté serveur — donc infalsifiable
-- même si quelqu'un décompile l'APK.
-- ============================================================================

-- --- Rôles applicatifs (mêmes 4 rôles que côté Flutter) --------------------

-- --- Organisation (SERVICE / CELLULE) --------------------------------------


-- --- Profils utilisateurs applicatifs --------------------------------------
-- Supabase gère l'authentification dans auth.users (email/mot de passe).
-- On lie chaque compte à une fiche métier ici : matricule, grade, rôle...

-- Fonction utilitaire : rôle de l'utilisateur actuellement connecté.
-- security definer = s'exécute avec les droits du créateur (contourne RLS
-- sur profiles pour éviter une boucle infinie lors de son propre lookup).

-- --- Personnel militaire (distinct des comptes applicatifs) ----------------
create table logistique.personnel (
  id bigint generated always as identity primary key,
  nom text not null,
  prenom text not null,
  grade integer,
  matricule text unique not null,
  contact text,
  date_naissance text,
  lieu_naissance text,
  mecano text,
  sexe text,
  civilite text,
  statut_actuel text not null default 'Actif'
);

-- --- Référentiel véhicules ---------------------------------------------------
create table logistique.marque_vhl (
  id bigint generated always as identity primary key,
  marque text not null
);

create table logistique.modele_vhl (
  id bigint generated always as identity primary key,
  modele text not null,
  marque_id bigint references logistique.marque_vhl(id)
);

create table logistique.type_vhl (
  id bigint generated always as identity primary key,
  type text not null,
  modele_id bigint references logistique.modele_vhl(id)
);

-- --- Parc automobile ----------------------------------------------------------
create type logistique.etat_vehicule as enum ('disponible', 'en_mission', 'en_reparation', 'hors_service');

create table logistique.vehicule (
  id bigint generated always as identity primary key,
  chassis text not null,
  immatriculation text unique not null,
  kilometrage integer not null default 0,
  etat logistique.etat_vehicule not null default 'disponible',
  position_actuelle text,
  nbre_places integer not null default 5,
  observations text,
  type_vhl_id bigint references logistique.type_vhl(id),
  kilometrage_vidange_prochaine integer not null,
  kilometrage_vidange_precedente integer
);

create table logistique.reparation (
  id bigint generated always as identity primary key,
  date_entree timestamptz not null default now(),
  date_sortie timestamptz,
  pannes_constatees text not null,
  solutions_apportees text,
  chef_equipe text,
  aide_mecano text,
  vehicule_id bigint references logistique.vehicule(id) not null,
  utilisateur_id uuid references socle.profiles(id) not null
);

create table logistique.vidange (
  id bigint generated always as identity primary key,
  date timestamptz not null default now(),
  filtre_vidange text,
  type_huile text not null,
  qte_huile integer not null,
  ingredient text,
  vehicule_id bigint references logistique.vehicule(id) not null,
  utilisateur_id uuid references socle.profiles(id) not null
);

create type logistique.etat_mouvement as enum ('en_cours', 'termine', 'annule');

create table logistique.mouvement (
  id bigint generated always as identity primary key,
  objet text not null,
  date_depart timestamptz not null default now(),
  date_fin timestamptz,
  etat logistique.etat_mouvement not null default 'en_cours',
  vehicule_id bigint references logistique.vehicule(id) not null,
  utilisateur_id uuid references socle.profiles(id) not null,
  km_depart integer not null,
  km_arrivee integer,
  destination text not null,
  nom_chef_bord text not null
);

-- --- Carburant -----------------------------------------------------------------
create table logistique.type_stock (
  id bigint generated always as identity primary key,
  libelle text not null
);

create table logistique.soute (
  id bigint generated always as identity primary key,
  libelle text not null
);

create table logistique.soute_type_stock (
  id bigint generated always as identity primary key,
  soute_id bigint references logistique.soute(id) not null,
  type_stock_id bigint references logistique.type_stock(id),
  qte_gasoil integer not null default 0,
  qte_super integer not null default 0,
  seuil_nominal integer not null,
  seuil_critique integer not null
);

create table logistique.depotage (
  id bigint generated always as identity primary key,
  date timestamptz not null default now(),
  qte_carburant_recue integer not null,
  type_carburant text not null,
  utilisateur_id uuid references socle.profiles(id) not null,
  soute_stock_id bigint references logistique.soute_type_stock(id) not null
);

create table logistique.distribution (
  id bigint generated always as identity primary key,
  soute_stock_id bigint references logistique.soute_type_stock(id) not null,
  personnel_id bigint references logistique.personnel(id),
  utilisateur_id uuid references socle.profiles(id) not null,
  qte_percue integer not null,
  date timestamptz not null default now(),
  type_carburant text not null,
  contact text,
  grade_destinataire text,
  destinataire text not null,
  vehicule text,
  vhl_immatriculation text,
  kilometrage integer,
  motif text
);

-- --- Armement (nouveau module, sans équivalent HFSQL) --------------------------
create type logistique.etat_arme as enum ('en_dotation', 'en_armurerie', 'en_maintenance', 'reforme');

create table logistique.arme (
  id bigint generated always as identity primary key,
  numero_serie text unique not null,
  type text not null,
  modele text not null,
  etat logistique.etat_arme not null default 'en_armurerie',
  date_acquisition timestamptz not null,
  derniere_inspection timestamptz,
  prochaine_inspection timestamptz not null
);

create table logistique.dotation_arme (
  id bigint generated always as identity primary key,
  arme_id bigint references logistique.arme(id) not null,
  beneficiaire_matricule text not null,
  date_remise timestamptz not null default now(),
  date_retour_prevue timestamptz,
  date_retour_effective timestamptz,
  remise_par uuid references socle.profiles(id) not null,
  motif text
);

create table logistique.stock_munition (
  id bigint generated always as identity primary key,
  calibre text not null,
  quantite_disponible integer not null default 0,
  seuil_critique integer not null,
  soute_armement text
);

-- --- Journal d'audit (HISTORIQUE) ----------------------------------------------
create table socle.historique (
  id bigint generated always as identity primary key,
  date timestamptz not null default now(),
  utilisateur_id uuid references socle.profiles(id) not null,
  action text not null,
  cible text not null,
  detail text,
  service_id bigint references socle.service(id)
);

-- ============================================================================
-- ROW LEVEL SECURITY — activée sur toutes les tables métier
-- ============================================================================
alter table socle.profiles enable row level security;
alter table socle.service enable row level security;
alter table socle.cellule enable row level security;
alter table logistique.personnel enable row level security;
alter table logistique.marque_vhl enable row level security;
alter table logistique.modele_vhl enable row level security;
alter table logistique.type_vhl enable row level security;
alter table logistique.vehicule enable row level security;
alter table logistique.reparation enable row level security;
alter table logistique.vidange enable row level security;
alter table logistique.mouvement enable row level security;
alter table logistique.type_stock enable row level security;
alter table logistique.soute enable row level security;
alter table logistique.soute_type_stock enable row level security;
alter table logistique.depotage enable row level security;
alter table logistique.distribution enable row level security;
alter table logistique.arme enable row level security;
alter table logistique.dotation_arme enable row level security;
alter table logistique.stock_munition enable row level security;
alter table socle.historique enable row level security;

-- Tout le monde connecté peut lire son propre profil ; le chef peut tout lire.
create policy "profil personnel" on socle.profiles
  for select using (id = auth.uid() or socle.current_user_role() = 'chef_soutien_technique');

-- Référentiels : lecture pour tout utilisateur connecté, écriture réservée au chef.
create policy "lecture referentiels service" on socle.service for select using (auth.role() = 'authenticated');
create policy "ecriture referentiels service" on socle.service for all using (socle.current_user_role() = 'chef_soutien_technique');
create policy "lecture referentiels cellule" on socle.cellule for select using (auth.role() = 'authenticated');
create policy "ecriture referentiels cellule" on socle.cellule for all using (socle.current_user_role() = 'chef_soutien_technique');
create policy "lecture personnel" on logistique.personnel for select using (auth.role() = 'authenticated');
create policy "ecriture personnel" on logistique.personnel for all using (socle.current_user_role() = 'chef_soutien_technique');
create policy "lecture marque" on logistique.marque_vhl for select using (auth.role() = 'authenticated');
create policy "ecriture marque" on logistique.marque_vhl for all using (socle.current_user_role() = 'chef_soutien_technique');
create policy "lecture modele" on logistique.modele_vhl for select using (auth.role() = 'authenticated');
create policy "ecriture modele" on logistique.modele_vhl for all using (socle.current_user_role() = 'chef_soutien_technique');
create policy "lecture type_vhl" on logistique.type_vhl for select using (auth.role() = 'authenticated');
create policy "ecriture type_vhl" on logistique.type_vhl for all using (socle.current_user_role() = 'chef_soutien_technique');
create policy "lecture type_stock" on logistique.type_stock for select using (auth.role() = 'authenticated');
create policy "ecriture type_stock" on logistique.type_stock for all using (socle.current_user_role() = 'chef_soutien_technique');

-- Parc / Maintenance : garage + chef.
create policy "parc select" on logistique.vehicule for select using (auth.role() = 'authenticated');
create policy "parc ecriture" on logistique.vehicule for all using (socle.current_user_role() in ('garage', 'chef_soutien_technique'));
create policy "reparation select" on logistique.reparation for select using (auth.role() = 'authenticated');
create policy "reparation ecriture" on logistique.reparation for all using (socle.current_user_role() in ('garage', 'chef_soutien_technique'));
create policy "vidange select" on logistique.vidange for select using (auth.role() = 'authenticated');
create policy "vidange ecriture" on logistique.vidange for all using (socle.current_user_role() in ('garage', 'chef_soutien_technique'));
create policy "mouvement select" on logistique.mouvement for select using (auth.role() = 'authenticated');
create policy "mouvement ecriture" on logistique.mouvement for all using (socle.current_user_role() in ('garage', 'chef_soutien_technique'));

-- Carburant : soutien pétrolier + chef.
create policy "soute select" on logistique.soute for select using (auth.role() = 'authenticated');
create policy "soute ecriture" on logistique.soute for all using (socle.current_user_role() in ('soutien_petrolier', 'chef_soutien_technique'));
create policy "soute_stock select" on logistique.soute_type_stock for select using (auth.role() = 'authenticated');
create policy "soute_stock ecriture" on logistique.soute_type_stock for all using (socle.current_user_role() in ('soutien_petrolier', 'chef_soutien_technique'));
create policy "depotage select" on logistique.depotage for select using (auth.role() = 'authenticated');
create policy "depotage ecriture" on logistique.depotage for all using (socle.current_user_role() in ('soutien_petrolier', 'chef_soutien_technique'));
create policy "distribution select" on logistique.distribution for select using (auth.role() = 'authenticated');
create policy "distribution ecriture" on logistique.distribution for all using (socle.current_user_role() in ('soutien_petrolier', 'chef_soutien_technique'));

-- Armement : armurerie + chef uniquement (y compris lecture — accès restreint).
create policy "arme acces" on logistique.arme for all using (socle.current_user_role() in ('armurerie', 'chef_soutien_technique'));
create policy "dotation acces" on logistique.dotation_arme for all using (socle.current_user_role() in ('armurerie', 'chef_soutien_technique'));
create policy "munition acces" on logistique.stock_munition for all using (socle.current_user_role() in ('armurerie', 'chef_soutien_technique'));

-- Historique : tout utilisateur connecté peut ajouter une entrée (ses propres
-- actions), mais seul le chef peut consulter le journal complet.
create policy "historique insert" on socle.historique for insert with check (auth.role() = 'authenticated');
create policy "historique select" on socle.historique for select using (socle.current_user_role() = 'chef_soutien_technique');
