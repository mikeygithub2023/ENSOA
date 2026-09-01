-- ============================================================================
-- SCOLARITÉ (ENSOA GSES) — repris de 019_controle_module_matiere.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- Migration : un "module" est en réalité une matière — sa création ne
-- doit pas demander un libellé libre, mais choisir une matière parmi
-- celles déjà affectées à la classe (coefficient repris de cette
-- affectation). controles.matiere_id relie le module à sa matière ; une
-- même matière ne peut avoir qu'un seul module par classe.

alter table scolarite.controles
  add column matiere_id uuid references scolarite.matieres (id);

create unique index controles_classe_matiere_module_uq
  on scolarite.controles (classe_id, matiere_id)
  where type = 'module' and matiere_id is not null;
