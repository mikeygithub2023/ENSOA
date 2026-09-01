-- ============================================================================
-- LOGISTIQUE (ERP ENSOA) — repris de migration_010b_poste_police_tables.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- ============================================================================
-- Étape 2/2 — à exécuter APRÈS que migration_010a a été validée (rôle
-- 'poste_police' déjà commit). Crée les tables du module Poste de Police.
-- ============================================================================

-- --- Visiteurs ---------------------------------------------------------------
create table logistique.passage_visiteur (
  id bigint generated always as identity primary key,
  contact_visiteur text not null,
  nom_visiteur text not null,
  photo_base64 text,
  couleur_badge text not null check (couleur_badge in ('rouge', 'jaune', 'vert', 'bleu', 'blanc')),
  contact_recu text not null,
  nom_recu text not null,
  date_arrivee timestamptz not null default now(),
  date_sortie timestamptz,
  enregistre_par uuid references socle.profiles(id) not null
);

alter table logistique.passage_visiteur enable row level security;
create policy "passage_visiteur acces" on logistique.passage_visiteur for all using (
  socle.current_user_role() = 'poste_police'
);

-- --- Véhicules -----------------------------------------------------------------
create table logistique.passage_vehicule (
  id bigint generated always as identity primary key,
  vehicule_id bigint references logistique.vehicule(id) not null,
  date_sortie timestamptz not null default now(),
  date_retour timestamptz,
  km_retour integer,
  enregistre_par uuid references socle.profiles(id) not null
);

alter table logistique.passage_vehicule enable row level security;
create policy "passage_vehicule acces" on logistique.passage_vehicule for all using (
  socle.current_user_role() = 'poste_police'
);

-- Le poste de police doit pouvoir mettre à jour le kilométrage du véhicule au
-- retour (VehiculesNotifier.updateKilometrage) : la table `vehicule` n'était
-- ouverte en écriture qu'au garage et au chef soutien technique.
create policy "parc ecriture poste_police" on logistique.vehicule for update using (
  socle.current_user_role() = 'poste_police'
);

-- ============================================================================
-- ÉTAPE MANUELLE REQUISE : créer le compte du poste de police
-- ============================================================================
-- 1. Supabase Studio → Authentication → Add user (email + mot de passe).
-- 2. Copier son UUID, puis :
--    insert into socle.profiles (id, matricule, nom_complet, grade, role)
--    values ('<uuid-copié>', 'PP-0001', 'Nom Prénom', 'Grade', 'poste_police');
-- ============================================================================
