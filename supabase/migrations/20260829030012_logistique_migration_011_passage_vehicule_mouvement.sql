-- ============================================================================
-- LOGISTIQUE (ERP ENSOA) — repris de migration_011_passage_vehicule_mouvement.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- ============================================================================
-- Relie les passages véhicule du poste de police aux mouvements créés par le
-- Garage : un véhicule ne peut plus sortir "librement" au poste de police —
-- il doit d'abord avoir été autorisé par un mouvement (mission) côté Garage.
-- Le poste de police se contente d'horodater le franchissement réel du
-- portail pour un mouvement déjà autorisé.
-- ============================================================================

alter table logistique.passage_vehicule add column if not exists mouvement_id bigint references logistique.mouvement(id);
