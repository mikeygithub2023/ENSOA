-- ============================================================================
-- SCOLARITÉ (ENSOA GSES) — repris de 033_profil_grade.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- Migration : le grade de l'utilisateur.
--
-- Le personnel de l'école est militaire : le grade fait partie de son
-- identité au même titre que le nom, et c'est sous cette forme qu'on le
-- désigne. Il manquait au profil, alors que la fiche d'un apprenant le
-- porte déjà (`apprenants.grade`, migration 003).
--
-- Texte libre, comme sur la fiche apprenant : la nomenclature des grades
-- couvre officiers, sous-officiers et militaires du rang, et le personnel
-- civil n'en a pas — une liste fermée demanderait à être maintenue sans
-- rien apporter ici, le grade n'étant pas agrégé.

alter table socle.profiles add column grade text;
