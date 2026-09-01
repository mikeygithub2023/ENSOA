-- ============================================================================
-- SCOLARITÉ (ENSOA GSES) — repris de 064_stages_des_specialistes.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- Migration : le module Sport suit le type de la classe, et CM 1 / CM 2
-- deviennent des stages.
--
-- La migration 056 crée un module Sport à l'insertion d'une phase, mais
-- rien ne se passait quand une classe changeait de type par la suite. Une
-- phase convertie en stage gardait donc un module Sport, alors qu'un stage
-- n'a pas de modules ; et un stage devenu phase n'en recevait aucun.
--
-- On rend ce lien symétrique : le module Sport apparaît quand la classe
-- devient une phase, disparaît quand elle devient un stage. Et puisqu'un
-- stage ne se range sous aucune promotion, sa promotion est détachée dans
-- le même mouvement.

-- --- 1. Un stage n'a pas de promotion ---------------------------------------

create or replace function scolarite.trg_classe_type_promotion()
returns trigger
language plpgsql
as $$
begin
  if new.type = 'stage' then
    new.promotion_id := null;
  end if;
  return new;
end;
$$;

drop trigger if exists stage_sans_promotion on scolarite.classes;
create trigger stage_sans_promotion
  before insert or update of type, promotion_id on scolarite.classes
  for each row execute function scolarite.trg_classe_type_promotion();

-- --- 2. Le module Sport suit le type ----------------------------------------

create or replace function scolarite.trg_classe_module_sport_maj()
returns trigger
language plpgsql
security definer
set search_path = scolarite, socle, public
as $$
begin
  if old.type is not distinct from new.type then
    return new;
  end if;

  if new.type = 'stage' then
    -- Le module part avec ses séances et leurs notes (cascade en base).
    -- Sur une classe qui vient d'être requalifiée, il n'a rien à noter.
    delete from scolarite.controles
    where classe_id = new.id and type = 'sport';
  else
    perform scolarite.assurer_module_sport(new.id);
  end if;

  return new;
end;
$$;

drop trigger if exists maj_module_sport on scolarite.classes;
create trigger maj_module_sport
  after update of type on scolarite.classes
  for each row execute function scolarite.trg_classe_module_sport_maj();

-- --- 3. CM 1 et CM 2 sont des stages ----------------------------------------
-- Ils avaient été saisis comme phases de la 36 ème promotion. Ce sont des
-- stages de la Division de Formation des Spécialistes : ils se rangent
-- directement sous elle, au même rang que ses promotions. Aucun apprenant,
-- cours ni note n'y était rattaché — seul leur module Sport, créé d'office,
-- part avec la requalification.

update scolarite.classes
set type = 'stage'
where nom in ('CM 1', 'CM 2')
  and type = 'phase'
  and division_id in (
    select id from socle.divisions
    where nom = 'Division de Formation des Spécialistes'
  );
