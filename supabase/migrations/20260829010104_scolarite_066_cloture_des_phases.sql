-- ============================================================================
-- SCOLARITÉ (ENSOA GSES) — repris de 066_cloture_des_phases.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- Migration : une phase se clôture, et ses élèves passent à la suivante.
--
-- Les phases d'une promotion se suivent : on ne note pas la deuxième avant
-- d'avoir fini la première. Jusqu'ici rien ne l'exprimait — toutes les
-- phases étaient ouvertes en même temps, et rien n'empêchait de saisir une
-- note en dernière phase le premier jour.
--
-- Clôturer une phase fait trois choses :
--   1. elle est figée — plus aucune saisie n'y est possible ;
--   2. ses élèves actifs passent à la phase suivante ;
--   3. cette phase suivante s'ouvre, celles d'après restant verrouillées.
--
-- L'ordre des phases devient explicite. Il se déduisait de la date de
-- création, ce qui marchait tant que l'école les créait dans l'ordre du
-- cursus, mais ne se corrigeait pas.

-- --- 1. L'ordre et l'état ---------------------------------------------------

alter table scolarite.classes
  add column if not exists ordre integer not null default 0;

alter table scolarite.classes
  add column if not exists cloturee_le timestamptz;

-- Reprise : l'ordre existant est celui de la création, promotion par
-- promotion.
with rangs as (
  select id,
         row_number() over (
           partition by promotion_id order by created_at, nom
         ) as rang
  from scolarite.classes
  where promotion_id is not null
)
update scolarite.classes c
set ordre = r.rang
from rangs r
where r.id = c.id and c.ordre = 0;

-- --- 2. Ce que « close » veut dire ------------------------------------------

create or replace function scolarite.phase_close(p_classe_id uuid)
returns boolean
language sql
stable
security definer
set search_path = scolarite, socle, public
as $$
  select exists (
    select 1 from scolarite.classes
    where id = p_classe_id and cloturee_le is not null
  );
$$;

grant execute on function scolarite.phase_close(uuid) to authenticated;

-- Une phase est verrouillée tant qu'une phase antérieure de sa promotion
-- n'est pas close : on ne saute pas d'étape.
create or replace function scolarite.phase_verrouillee(p_classe_id uuid)
returns boolean
language sql
stable
security definer
set search_path = scolarite, socle, public
as $$
  select exists (
    select 1
    from scolarite.classes precedente
    join scolarite.classes cible on cible.id = p_classe_id
    where precedente.promotion_id = cible.promotion_id
      and precedente.type = 'phase'
      and precedente.ordre < cible.ordre
      and precedente.cloturee_le is null
  );
$$;

grant execute on function scolarite.phase_verrouillee(uuid) to authenticated;

-- --- 3. Clôturer ------------------------------------------------------------

create or replace function scolarite.cloturer_phase(p_classe_id uuid)
returns integer
language plpgsql
security definer
set search_path = scolarite, socle, public
as $$
declare
  v_classe record;
  v_bloquante text;
  v_suivante uuid;
  v_migres integer := 0;
begin
  if socle.current_role() <> 'admin' then
    raise exception 'Seul un administrateur peut clôturer une phase.';
  end if;

  select id, promotion_id, type, ordre, cloturee_le, nom
  into v_classe
  from scolarite.classes where id = p_classe_id;

  if v_classe.id is null or v_classe.type <> 'phase' then
    raise exception 'Seule une phase se clôture ; un stage n''en a pas besoin.';
  end if;
  if v_classe.cloturee_le is not null then
    raise exception 'La phase « % » est déjà clôturée.', v_classe.nom;
  end if;

  -- On ne clôture pas dans le désordre : la deuxième phase ne peut pas se
  -- fermer avant la première.
  select nom into v_bloquante
  from scolarite.classes
  where promotion_id = v_classe.promotion_id
    and type = 'phase'
    and ordre < v_classe.ordre
    and cloturee_le is null
  order by ordre
  limit 1;

  if v_bloquante is not null then
    raise exception
      'La phase « % » doit être clôturée avant « % ».',
      v_bloquante, v_classe.nom;
  end if;

  update scolarite.classes set cloturee_le = now() where id = p_classe_id;

  -- Les élèves montent d'une phase. Seuls les actifs : un radié ou un
  -- suspendu ne poursuit pas le cursus, et un diplômé l'a fini.
  select id into v_suivante
  from scolarite.classes
  where promotion_id = v_classe.promotion_id
    and type = 'phase'
    and ordre > v_classe.ordre
  order by ordre
  limit 1;

  if v_suivante is not null then
    update scolarite.apprenants
    set classe_id = v_suivante
    where classe_id = p_classe_id and statut = 'actif';
    get diagnostics v_migres = row_count;
  end if;

  return v_migres;
end;
$$;

revoke execute on function scolarite.cloturer_phase(uuid) from public;
grant execute on function scolarite.cloturer_phase(uuid) to authenticated;

-- Rouvrir une phase close — l'erreur de manipulation existe, et sans cette
-- porte il faudrait passer par la base. Les élèves ne redescendent pas :
-- les faire reculer d'office déferait des affectations peut-être déjà
-- corrigées à la main.
create or replace function scolarite.rouvrir_phase(p_classe_id uuid)
returns void
language plpgsql
security definer
set search_path = scolarite, socle, public
as $$
declare
  v_suivante text;
begin
  if socle.current_role() <> 'admin' then
    raise exception 'Seul un administrateur peut rouvrir une phase.';
  end if;

  -- Rouvrir une phase dont la suivante est déjà close laisserait deux
  -- phases ouvertes en même temps dans le désordre.
  select c.nom into v_suivante
  from scolarite.classes c
  join scolarite.classes cible on cible.id = p_classe_id
  where c.promotion_id = cible.promotion_id
    and c.type = 'phase'
    and c.ordre > cible.ordre
    and c.cloturee_le is not null
  order by c.ordre
  limit 1;

  if v_suivante is not null then
    raise exception
      'Rouvrez d''abord la phase « % », clôturée après celle-ci.', v_suivante;
  end if;

  update scolarite.classes set cloturee_le = null where id = p_classe_id;
end;
$$;

revoke execute on function scolarite.rouvrir_phase(uuid) from public;
grant execute on function scolarite.rouvrir_phase(uuid) to authenticated;

-- --- 4. Le verrou ------------------------------------------------------------
-- Une phase close ne se manipule plus, et une phase verrouillée pas encore.
-- Le contrôle vit ici plutôt que dans l'écran : une clôture qui ne tiendrait
-- qu'à l'interface n'en serait pas une.

create or replace function scolarite.exiger_phase_ouverte(p_classe_id uuid)
returns void
language plpgsql
stable
security definer
set search_path = scolarite, socle, public
as $$
declare
  v_classe record;
begin
  select nom, cloturee_le, type into v_classe
  from scolarite.classes where id = p_classe_id;

  if v_classe.type is distinct from 'phase' then
    return;
  end if;

  if v_classe.cloturee_le is not null then
    raise exception
      'La phase « % » est clôturée : elle ne peut plus être modifiée.',
      v_classe.nom;
  end if;

  if scolarite.phase_verrouillee(p_classe_id) then
    raise exception
      'La phase « % » est verrouillée : clôturez d''abord la phase '
      'précédente.', v_classe.nom;
  end if;
end;
$$;

-- Les tables qui portent directement une phase.
create or replace function scolarite.trg_phase_ouverte_classe_id()
returns trigger
language plpgsql
security definer
set search_path = scolarite, socle, public
as $$
begin
  perform scolarite.exiger_phase_ouverte(
    coalesce(new.classe_id, old.classe_id)
  );
  return coalesce(new, old);
end;
$$;

drop trigger if exists phase_ouverte on scolarite.controles;
create trigger phase_ouverte
  before insert or update or delete on scolarite.controles
  for each row execute function scolarite.trg_phase_ouverte_classe_id();

drop trigger if exists phase_ouverte on scolarite.cours;
create trigger phase_ouverte
  before insert or update or delete on scolarite.cours
  for each row execute function scolarite.trg_phase_ouverte_classe_id();

-- Les sous-modules et les séances passent par leur module.
create or replace function scolarite.trg_phase_ouverte_sous_module()
returns trigger
language plpgsql
security definer
set search_path = scolarite, socle, public
as $$
declare
  v_classe uuid;
begin
  select c.classe_id into v_classe
  from scolarite.controles c
  where c.id = coalesce(new.module_id, old.module_id);

  if v_classe is not null then
    perform scolarite.exiger_phase_ouverte(v_classe);
  end if;
  return coalesce(new, old);
end;
$$;

drop trigger if exists phase_ouverte on scolarite.sous_modules;
create trigger phase_ouverte
  before insert or update or delete on scolarite.sous_modules
  for each row execute function scolarite.trg_phase_ouverte_sous_module();

create or replace function scolarite.trg_phase_ouverte_par_sous_module()
returns trigger
language plpgsql
security definer
set search_path = scolarite, socle, public
as $$
declare
  v_classe uuid;
begin
  select c.classe_id into v_classe
  from scolarite.sous_modules sm
  join scolarite.controles c on c.id = sm.module_id
  where sm.id = coalesce(new.sous_module_id, old.sous_module_id);

  if v_classe is not null then
    perform scolarite.exiger_phase_ouverte(v_classe);
  end if;
  return coalesce(new, old);
end;
$$;

drop trigger if exists phase_ouverte on scolarite.performances_sportives;
create trigger phase_ouverte
  before insert or update or delete on scolarite.performances_sportives
  for each row execute function scolarite.trg_phase_ouverte_par_sous_module();

drop trigger if exists phase_ouverte on scolarite.seances_sportives;
create trigger phase_ouverte
  before insert or update or delete on scolarite.seances_sportives
  for each row execute function scolarite.trg_phase_ouverte_par_sous_module();

-- Les notes saisies. Les notes SPORTIVES, elles, passent : elles ne sont
-- pas saisies mais recalculées par la base à chaque reprise de barème, et
-- les bloquer ici ferait échouer la reprise d'un barème dès qu'une phase
-- serait close. Leur source — la performance — est déjà verrouillée
-- ci-dessus, ce qui suffit.
create or replace function scolarite.trg_phase_ouverte_note()
returns trigger
language plpgsql
security definer
set search_path = scolarite, socle, public
as $$
declare
  v_classe uuid;
  v_ligne record;
begin
  v_ligne := coalesce(new, old);
  if v_ligne.sous_module_id is not null then
    return v_ligne;
  end if;

  select c.classe_id into v_classe
  from scolarite.controles c
  where c.id = v_ligne.controle_id;

  if v_classe is not null then
    perform scolarite.exiger_phase_ouverte(v_classe);
  end if;
  return v_ligne;
end;
$$;

drop trigger if exists phase_ouverte on scolarite.notes;
create trigger phase_ouverte
  before insert or update or delete on scolarite.notes
  for each row execute function scolarite.trg_phase_ouverte_note();
