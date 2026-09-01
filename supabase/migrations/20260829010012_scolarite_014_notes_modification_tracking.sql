-- ============================================================================
-- SCOLARITÉ (ENSOA GSES) — repris de 014_notes_modification_tracking.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- Migration : suivi de la modification d'une note — l'affichage doit
-- pouvoir signaler qu'une note a été modifiée après sa première saisie et
-- montrer, au survol, la valeur précédente.

alter table scolarite.notes add column previous_note numeric(4, 2);
