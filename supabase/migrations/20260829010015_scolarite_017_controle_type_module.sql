-- ============================================================================
-- SCOLARITÉ (ENSOA GSES) — repris de 017_controle_type_module.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- Migration : les contrôles continu/intermédiaire ne concernent que les
-- stages ; les classes (élèves) ont en plus une catégorie "Modules". La
-- valeur 'intermediaire' reste inchangée en base (seul son libellé
-- affiché change selon le type de classe/stage, géré côté application) —
-- seule la liste des valeurs autorisées évolue, pour accepter 'module'.

do $$
declare
  con_name text;
begin
  select conname into con_name
  from pg_constraint
  where conrelid = 'scolarite.controles'::regclass
    and contype = 'c'
    and pg_get_constraintdef(oid) ilike '%type%continu%intermediaire%';
  if con_name is not null then
    execute format('alter table scolarite.controles drop constraint %I', con_name);
  end if;
end $$;

alter table scolarite.controles
  add constraint controles_type_check
  check (type in ('continu', 'intermediaire', 'module'));
