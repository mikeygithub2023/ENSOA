-- ============================================================================
-- SCOLARITÉ (ENSOA GSES) — repris de 009_absence_date_fin_optionnelle.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- Migration : la date de fin d'une absence n'est plus saisie à
-- l'enregistrement (on ne connaît pas encore le retour) — elle est
-- renseignée plus tard, quand l'apprenant revient, via une action dédiée
-- ("Marquer le retour") sur la ligne de la liste.

alter table scolarite.absences alter column date_fin drop not null;

-- Le nom de la contrainte générée automatiquement par la création de table
-- (migration 008) n'est pas garanti — on la retrouve dynamiquement plutôt
-- que de supposer un nom fixe.
do $$
declare
  con_name text;
begin
  select conname into con_name
  from pg_constraint
  where conrelid = 'scolarite.absences'::regclass
    and contype = 'c'
    and pg_get_constraintdef(oid) ilike '%date_fin%date_debut%';
  if con_name is not null then
    execute format('alter table scolarite.absences drop constraint %I', con_name);
  end if;
end $$;

alter table scolarite.absences
  add constraint absences_date_fin_apres_debut check (date_fin is null or date_fin >= date_debut);
