-- ============================================================================
-- LOGISTIQUE (ERP ENSOA) — repris de migration_016b_oa_activites_taches.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- ============================================================================
-- Étape 2/2 — à exécuter APRÈS que migration_016a a été validée.
--
-- Module Officier Adjoint (OA) : création d'activités, affectation de tâches
-- à un acteur (ST, Garage, Armurerie, Santé), cycle à faire → terminée
-- (par l'acteur) → validée (par l'OA).
-- ============================================================================

create table logistique.activite (
  id bigint generated always as identity primary key,
  titre text not null,
  description text,
  date_activite timestamptz not null,
  lieu text,
  statut text not null default 'planifiee' check (statut in ('planifiee', 'en_cours', 'terminee', 'annulee')),
  cree_par uuid references socle.profiles(id) not null,
  cree_le timestamptz not null default now()
);

alter table logistique.activite enable row level security;

-- Lecture ouverte à tout utilisateur connecté (un acteur doit pouvoir voir le
-- contexte de l'activité liée à ses tâches) ; écriture réservée à l'OA.
create policy "activite select" on logistique.activite for select using (auth.role() = 'authenticated');
create policy "activite ecriture" on logistique.activite for all using (socle.current_user_role() = 'officier_adjoint');

create table logistique.tache_activite (
  id bigint generated always as identity primary key,
  activite_id bigint references logistique.activite(id) not null,
  acteur text not null check (acteur in ('st', 'garage', 'armurerie', 'sante')),
  description text not null,
  date_limite timestamptz,
  statut text not null default 'a_faire' check (statut in ('a_faire', 'terminee', 'validee')),
  terminee_par uuid references socle.profiles(id),
  terminee_le timestamptz,
  validee_le timestamptz,
  commentaire text
);

alter table logistique.tache_activite enable row level security;

-- L'OA voit tout ; chaque acteur ne voit que les tâches qui lui sont confiées.
create policy "tache select" on logistique.tache_activite for select using (
  socle.current_user_role() = 'officier_adjoint'
  or (acteur = 'st' and socle.current_user_role() = 'chef_soutien_technique')
  or (acteur = 'garage' and socle.current_user_role() = 'garage')
  or (acteur = 'armurerie' and socle.current_user_role() = 'armurerie')
  or (acteur = 'sante' and socle.current_user_role() = 'sante')
);

create policy "tache insert" on logistique.tache_activite for insert with check (
  socle.current_user_role() = 'officier_adjoint'
);

-- Mise à jour : l'OA (valider, éditer) ou l'acteur concerné (marquer terminée).
create policy "tache update" on logistique.tache_activite for update using (
  socle.current_user_role() = 'officier_adjoint'
  or (acteur = 'st' and socle.current_user_role() = 'chef_soutien_technique')
  or (acteur = 'garage' and socle.current_user_role() = 'garage')
  or (acteur = 'armurerie' and socle.current_user_role() = 'armurerie')
  or (acteur = 'sante' and socle.current_user_role() = 'sante')
);

create policy "tache delete" on logistique.tache_activite for delete using (
  socle.current_user_role() = 'officier_adjoint'
);

-- ============================================================================
-- ÉTAPE MANUELLE REQUISE : créer les comptes Officier Adjoint et Santé
-- ============================================================================
-- 1. Supabase Studio → Authentication → Add user (email + mot de passe).
-- 2. Copier son UUID (User UID sur sa fiche), puis :
--    insert into socle.profiles (id, matricule, nom_complet, grade, role)
--    values ('<uuid-copié>', 'OA-0001', 'Nom Prénom', 'Grade', 'officier_adjoint');
--    -- et pour Santé, avec un autre compte :
--    insert into socle.profiles (id, matricule, nom_complet, grade, role)
--    values ('<uuid-copié>', 'SA-0001', 'Nom Prénom', 'Grade', 'sante');
-- ============================================================================
