-- ============================================================================
-- SCOLARITÉ (ENSOA GSES) — repris de 013_notes_par_matiere.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- Migration : une note concerne un apprenant ET une matière (pas
-- seulement l'apprenant) — à l'intérieur d'un contrôle, les notes sont
-- saisies matière par matière, puis affichées rangées par matière et par
-- ordre alphabétique des apprenants.
--
-- Pas de données réelles à ce stade (uniquement des notes de test saisies
-- pendant la vérification de la fonctionnalité) : on repart de zéro sur la
-- contrainte d'unicité plutôt que de migrer les lignes existantes.

delete from scolarite.notes;

alter table scolarite.notes
  add column matiere_id uuid references scolarite.matieres (id) on delete cascade;

alter table scolarite.notes alter column matiere_id set not null;

create index notes_matiere_idx on scolarite.notes (matiere_id);

-- Le nom de la contrainte d'unicité générée automatiquement par la
-- création de table (migration 012) n'est pas garanti.
do $$
declare
  con_name text;
begin
  select conname into con_name
  from pg_constraint
  where conrelid = 'scolarite.notes'::regclass
    and contype = 'u'
    and pg_get_constraintdef(oid) ilike '%controle_id%apprenant_id%';
  if con_name is not null then
    execute format('alter table scolarite.notes drop constraint %I', con_name);
  end if;
end $$;

alter table scolarite.notes
  add constraint notes_controle_apprenant_matiere_key
  unique (controle_id, apprenant_id, matiere_id);
