-- ============================================================================
-- LOGISTIQUE (ERP ENSOA) — repris de migration_009_dotation_beneficiaire_nom.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- ============================================================================
-- Ajoute le nom du bénéficiaire sur un bon de sortie d'arme — jusque-là seul
-- le matricule était enregistré.
-- ============================================================================

alter table logistique.dotation_arme add column if not exists beneficiaire_nom text not null default '';
alter table logistique.dotation_arme alter column beneficiaire_nom drop default;
