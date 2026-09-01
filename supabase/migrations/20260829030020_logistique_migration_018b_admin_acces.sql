-- ============================================================================
-- LOGISTIQUE (ERP ENSOA) — repris de migration_018b_admin_acces.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- ============================================================================
-- Étape 2/2 — à exécuter APRÈS que migration_018a a été validée.
--
-- Accès de l'Administrateur : gestion complète des comptes (profiles), et
-- lecture large sur les domaines dont la RLS était jusqu'ici restreinte à un
-- seul rôle métier — nécessaire au tableau de bord transversal.
-- ============================================================================

-- --- Gestion des utilisateurs -------------------------------------------------
create policy "profil admin select" on socle.profiles for select using (socle.current_user_role() = 'administrateur');
create policy "profil admin insert" on socle.profiles for insert with check (socle.current_user_role() = 'administrateur');
create policy "profil admin update" on socle.profiles for update using (socle.current_user_role() = 'administrateur');
create policy "profil admin delete" on socle.profiles for delete using (socle.current_user_role() = 'administrateur');

-- --- Lecture transversale pour le tableau de bord -----------------------------
create policy "arme select admin" on logistique.arme for select using (socle.current_user_role() = 'administrateur');
create policy "dotation select admin" on logistique.dotation_arme for select using (socle.current_user_role() = 'administrateur');
create policy "munition select admin" on logistique.stock_munition for select using (socle.current_user_role() = 'administrateur');
create policy "epi select admin" on logistique.equipement_protection for select using (socle.current_user_role() = 'administrateur');
create policy "dotation_epi select admin" on logistique.dotation_equipement for select using (socle.current_user_role() = 'administrateur');
create policy "passage_visiteur select admin" on logistique.passage_visiteur for select using (socle.current_user_role() = 'administrateur');
create policy "passage_vehicule select admin" on logistique.passage_vehicule for select using (socle.current_user_role() = 'administrateur');
create policy "tache select admin" on logistique.tache_activite for select using (socle.current_user_role() = 'administrateur');
create policy "historique select admin" on socle.historique for select using (socle.current_user_role() = 'administrateur');

-- ============================================================================
-- ÉTAPE MANUELLE REQUISE : créer le compte Administrateur
-- ============================================================================
-- 1. Supabase Studio → Authentication → Add user → Create new user.
-- 2. Copier son UUID (User UID), puis :
--    insert into socle.profiles (id, matricule, nom_complet, grade, role)
--    values ('<uuid-copié>', 'ADM-0001', 'Nom Prénom', 'Grade', 'administrateur');
-- ============================================================================
