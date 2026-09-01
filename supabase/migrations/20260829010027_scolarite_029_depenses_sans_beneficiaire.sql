-- ============================================================================
-- SCOLARITÉ (ENSOA GSES) — repris de 029_depenses_sans_beneficiaire.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- Migration : retrait des rubriques « Bénéficiaire / fournisseur » et
-- « Référence de la pièce » des dépenses — elles n'étaient pas attendues
-- dans la saisie. Le libellé et les observations suffisent à décrire la
-- dépense.

alter table scolarite.depenses drop column beneficiaire;
alter table scolarite.depenses drop column reference;
