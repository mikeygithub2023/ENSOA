-- ============================================================================
-- SCOLARITÉ (ENSOA GSES) — repris de 021_controles_inclus_bulletin.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- Migration : le calcul des bulletins ne doit porter que sur les modules,
-- contrôles continus et examens explicitement retenus par l'administrateur
-- (menu "Bulletins") — pas automatiquement sur tout ce qui existe pour la
-- classe/stage, pour pouvoir exclure un contrôle incomplet ou annulé sans
-- avoir à le supprimer (et perdre les notes déjà saisies).

alter table scolarite.controles
  add column inclus_bulletin boolean not null default false;
