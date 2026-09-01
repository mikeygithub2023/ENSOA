-- ============================================================================
-- LOGISTIQUE (ERP ENSOA) — repris de migration_012_vehicule_suppression.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- ============================================================================
-- Suppression "douce" d'un véhicule : le bouton Supprimer de la fiche
-- détail ne supprime pas la ligne (l'historique — réparations, vidanges,
-- mouvements — reste rattaché et disponible), il la marque comme supprimée
-- et la retire simplement des listes actives.
-- ============================================================================

alter table logistique.vehicule add column if not exists supprime boolean not null default false;
