-- ============================================================================
-- LOGISTIQUE (ERP ENSOA) — repris de migration_002_reparation_lieu.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- ============================================================================
-- Migration : ajout du champ "lieu" sur REPARATION (lieu de mise en réparation)
-- Champ absent de l'analyse HFSQL d'origine, ajouté à la demande utilisateur.
-- À exécuter dans Supabase → SQL Editor.
-- ============================================================================
alter table logistique.reparation add column if not exists lieu text;
