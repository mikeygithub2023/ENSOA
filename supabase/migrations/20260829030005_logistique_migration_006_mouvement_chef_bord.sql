-- ============================================================================
-- LOGISTIQUE (ERP ENSOA) — repris de migration_006_mouvement_chef_bord.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- ============================================================================
-- Ajoute le grade et le contact téléphonique du chef de bord sur un mouvement
-- (trajet/mission) — jusque-là seul le nom était enregistré.
-- ============================================================================

alter table logistique.mouvement add column if not exists grade_chef_bord text not null default '';
alter table logistique.mouvement add column if not exists contact_chef_bord text not null default '';

alter table logistique.mouvement alter column grade_chef_bord drop default;
alter table logistique.mouvement alter column contact_chef_bord drop default;
