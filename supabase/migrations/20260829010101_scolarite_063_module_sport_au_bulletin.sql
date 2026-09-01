-- ============================================================================
-- SCOLARITÉ (ENSOA GSES) — repris de 063_module_sport_au_bulletin.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- Migration : le module Sport compte au bulletin par défaut.
--
-- `inclus_bulletin` vaut `false` à la création d'une évaluation : c'est
-- l'administrateur qui coche, depuis l'écran Bulletins, celles qui doivent
-- figurer. Ce choix a du sens pour un contrôle ou un examen, qu'on peut
-- vouloir écarter d'une période.
--
-- Il n'en a pas pour le Sport. Ce module n'est pas créé par quelqu'un qui
-- pourrait penser à le cocher : il apparaît d'office dans chaque phase
-- (migration 056). Laissé décoché, il comptait dans la moyenne générale
-- affichée à l'écran mais restait absent du bulletin imprimé — deux
-- chiffres divergents pour le même apprenant, sans que rien ne l'explique.
--
-- Il est donc inclus dès sa création. L'administrateur garde la main : le
-- Sport figure maintenant dans l'écran Bulletins, où il se décoche comme
-- les autres.

create or replace function scolarite.assurer_module_sport(p_classe_id uuid)
returns uuid
language plpgsql
security definer
set search_path = scolarite, socle, public
as $$
declare
  v_classe record;
  v_module uuid;
begin
  select id, division_id, type into v_classe
  from scolarite.classes where id = p_classe_id;

  -- Les stages n'ont pas de modules — donc pas de module Sport.
  if v_classe is null or v_classe.type <> 'phase' then
    return null;
  end if;

  select id into v_module
  from scolarite.controles
  where classe_id = p_classe_id and type = 'sport'
  limit 1;

  if v_module is not null then
    return v_module;
  end if;

  insert into scolarite.controles (
    division_id,
    classe_id,
    type,
    libelle,
    coefficient,
    inclus_bulletin
  )
  values (v_classe.division_id, p_classe_id, 'sport', 'Sport', 1, true)
  returning id into v_module;

  return v_module;
end;
$$;

revoke execute on function scolarite.assurer_module_sport(uuid) from public;
grant execute on function scolarite.assurer_module_sport(uuid) to authenticated;

-- Les modules Sport déjà créés n'ont jamais pu être cochés : l'écran
-- Bulletins ne les affichait pas. On les inclut.
update scolarite.controles
set inclus_bulletin = true
where type = 'sport' and inclus_bulletin = false;
