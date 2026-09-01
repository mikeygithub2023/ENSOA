-- ============================================================================
-- SCOLARITÉ (ENSOA GSES) — repris de 056_sport_activites_et_seances.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- Migration : le sport se réorganise en activités et en séances.
--
-- Jusqu'ici une épreuve sportive ÉTAIT un sous-module : son barème lui
-- appartenait, et mesurer deux fois le 3000 mètres dans l'année demandait
-- de ressaisir le barème. La structure voulue sépare les deux :
--
--   Activité sportive (catalogue de l'école)  ── son barème, par sexe
--         ▲
--         │ choisie par
--   Séance sportive (dans le module Sport d'une phase, à une date)
--         └── une performance par apprenant → une note, calculée
--
-- Une activité se paramètre une fois pour toute l'école ; une séance la
-- convoque un jour donné devant une phase. Toutes les séances pèsent le
-- même poids dans la note du module Sport — leur coefficient reste donc à
-- 1, et la moyenne pondérée du module devient de fait une moyenne simple.
--
-- Le module Sport lui-même n'est plus une matière que l'on affecte : il
-- existe d'office dans chaque phase, comme une rubrique à part entière à
-- côté de Modules, Contrôle continu et Examen.

-- --- 1. Sport devient un type de contrôle ----------------------------------

alter table scolarite.controles drop constraint if exists controles_type_check;
alter table scolarite.controles
  add constraint controles_type_check
  check (type in ('continu', 'intermediaire', 'module', 'sport'));

-- --- 2. Le catalogue des activités ------------------------------------------

create table if not exists scolarite.activites_sportives (
  id uuid primary key default gen_random_uuid(),
  nom text not null unique,
  unite text not null check (unite in ('secondes', 'metres', 'repetitions', 'points')),
  -- Au 3000 mètres la meilleure performance est la plus petite, à la
  -- traction la plus grande. Sans cette indication le barème ne saurait
  -- pas dans quel sens interpoler.
  meilleur text not null check (meilleur in ('minimum', 'maximum')),
  consigne text,
  created_at timestamptz not null default now()
);

alter table scolarite.activites_sportives enable row level security;

-- Même portée que le catalogue des matières, dont c'est le pendant : tout
-- l'encadrement le consulte, l'administrateur seul le tient à jour.
drop policy if exists activites_sportives_select on scolarite.activites_sportives;
create policy activites_sportives_select on scolarite.activites_sportives
  for select to authenticated using (true);

drop policy if exists activites_sportives_write on scolarite.activites_sportives;
create policy activites_sportives_write on scolarite.activites_sportives
  for all to authenticated
  using (socle.current_role() = 'admin')
  with check (socle.current_role() = 'admin');

drop trigger if exists audit_activites_sportives on scolarite.activites_sportives;
create trigger audit_activites_sportives
  after insert or update or delete on scolarite.activites_sportives
  for each row execute function socle.audit_trigger();

-- Reprise de l'existant : les sous-modules sportifs déjà saisis sont, dans
-- la nouvelle lecture, des activités. On les remonte au catalogue avec
-- leur unité et leur sens quand ils en avaient un ; ceux qui n'étaient pas
-- encore configurés prennent des valeurs par défaut, à corriger dans
-- Matières › Activités sportives.
insert into scolarite.activites_sportives (nom, unite, meilleur, consigne)
select
  sm.nom,
  coalesce(e.unite, 'secondes'),
  coalesce(e.meilleur, 'minimum'),
  e.consigne
from scolarite.sous_modules sm
left join scolarite.epreuves_sportives e on e.sous_module_id = sm.id
where sm.nature = 'sport'
on conflict (nom) do nothing;

-- --- 3. Le barème se rattache à l'activité ----------------------------------

alter table scolarite.bareme_paliers
  add column if not exists activite_id uuid references scolarite.activites_sportives (id) on delete cascade;

-- Les paliers déjà saisis suivent leur épreuve devenue activité.
update scolarite.bareme_paliers bp
set activite_id = a.id
from scolarite.sous_modules sm
join scolarite.activites_sportives a on a.nom = sm.nom
where bp.sous_module_id = sm.id
  and bp.activite_id is null;

-- Un palier orphelin (activité introuvable) n'a plus de sens : il ne
-- pourrait plus noter personne.
delete from scolarite.bareme_paliers where activite_id is null;

alter table scolarite.bareme_paliers alter column activite_id set not null;

-- Les politiques en place s'appuient sur `sous_module_id` : elles tombent
-- avant lui, sans quoi Postgres refuse de retirer la colonne.
drop policy if exists bareme_paliers_all on scolarite.bareme_paliers;
drop policy if exists bareme_paliers_commandant on scolarite.bareme_paliers;

alter table scolarite.bareme_paliers drop column if exists sous_module_id;

drop index if exists scolarite.bareme_paliers_epreuve_idx;
create index bareme_paliers_activite_idx
  on scolarite.bareme_paliers (activite_id, sexe, performance);

alter table scolarite.bareme_paliers
  drop constraint if exists bareme_paliers_sous_module_id_sexe_performance_key;
alter table scolarite.bareme_paliers
  add constraint bareme_paliers_activite_sexe_performance_key
  unique (activite_id, sexe, performance);

-- Le barème n'appartient plus à une phase mais à l'école : il se lit
-- partout et ne s'écrit qu'en administration, comme le catalogue des
-- matières. Le Commandant de Brigade n'a donc plus besoin d'une politique
-- à lui — la lecture générale le couvre.
create policy bareme_paliers_select on scolarite.bareme_paliers
  for select to authenticated using (true);
create policy bareme_paliers_write on scolarite.bareme_paliers
  for all to authenticated
  using (socle.current_role() = 'admin')
  with check (socle.current_role() = 'admin');

-- --- 4. La séance -----------------------------------------------------------
-- Elle remplace `epreuves_sportives` : un sous-module du module Sport,
-- rattaché à l'activité qu'il fait passer et daté du jour où elle a eu
-- lieu.

drop table if exists scolarite.epreuves_sportives cascade;

create table scolarite.seances_sportives (
  sous_module_id uuid primary key
    references scolarite.sous_modules (id) on delete cascade,
  activite_id uuid not null
    references scolarite.activites_sportives (id) on delete restrict,
  date_seance date not null default current_date,
  created_at timestamptz not null default now()
);

create index seances_sportives_activite_idx
  on scolarite.seances_sportives (activite_id);

alter table scolarite.seances_sportives enable row level security;

create policy seances_sportives_all on scolarite.seances_sportives
  for all to authenticated
  using (
    exists (
      select 1
      from scolarite.sous_modules sm
      join scolarite.controles c on c.id = sm.module_id
      where sm.id = seances_sportives.sous_module_id
        and (
          socle.current_role() = 'admin'
          or (
            socle.current_role() in ('chef_division', 'instructeur')
            and c.division_id = socle.current_division()
          )
        )
    )
  )
  with check (
    exists (
      select 1
      from scolarite.sous_modules sm
      join scolarite.controles c on c.id = sm.module_id
      where sm.id = seances_sportives.sous_module_id
        and (
          socle.current_role() = 'admin'
          or (
            socle.current_role() in ('chef_division', 'instructeur')
            and c.division_id = socle.current_division()
          )
        )
    )
  );

create trigger audit_seances_sportives
  after insert or update or delete on scolarite.seances_sportives
  for each row execute function socle.audit_trigger();

-- Les anciens sous-modules sportifs sont devenus des activités : ils n'ont
-- plus lieu d'être comme sous-modules. Aucune performance n'y était
-- rattachée, donc aucune note ne disparaît.
delete from scolarite.sous_modules where nature = 'sport';

-- --- 5. Le module Sport de chaque phase -------------------------------------
-- Il n'est plus choisi parmi les matières : il existe d'office.

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

  insert into scolarite.controles (division_id, classe_id, type, libelle, coefficient)
  values (v_classe.division_id, p_classe_id, 'sport', 'Sport', 1)
  returning id into v_module;

  return v_module;
end;
$$;

revoke execute on function scolarite.assurer_module_sport(uuid) from public;
grant execute on function scolarite.assurer_module_sport(uuid) to authenticated;

create or replace function scolarite.trg_classe_module_sport()
returns trigger
language plpgsql
security definer
set search_path = scolarite, socle, public
as $$
begin
  perform scolarite.assurer_module_sport(new.id);
  return new;
end;
$$;

drop trigger if exists creer_module_sport on scolarite.classes;
create trigger creer_module_sport
  after insert on scolarite.classes
  for each row execute function scolarite.trg_classe_module_sport();

-- Le module Sport déjà créé à la main (via une matière « Sport ») devient
-- le module Sport de sa phase, plutôt que d'en laisser deux côte à côte.
update scolarite.controles
set type = 'sport', matiere_id = null
where type = 'module'
  and lower(libelle) = 'sport';

-- Puis on complète les phases qui n'en ont pas encore.
do $$
declare
  v_classe uuid;
begin
  for v_classe in select id from scolarite.classes where type = 'phase'
  loop
    perform scolarite.assurer_module_sport(v_classe);
  end loop;
end;
$$;

-- --- 6. Les performances se rattachent à la séance --------------------------

drop table if exists scolarite.performances_sportives cascade;

create table scolarite.performances_sportives (
  id uuid primary key default gen_random_uuid(),
  sous_module_id uuid not null
    references scolarite.sous_modules (id) on delete cascade,
  apprenant_id uuid not null references scolarite.apprenants (id) on delete cascade,
  valeur numeric(10, 2) not null check (valeur >= 0),
  observations text,
  saisie_par uuid references socle.profiles (id) default auth.uid(),
  created_at timestamptz not null default now(),
  -- Une performance par séance et par apprenant : la date appartient à la
  -- séance, pas à la performance, et on garde la mesure retenue plutôt
  -- qu'un historique de tentatives.
  unique (sous_module_id, apprenant_id)
);

create index performances_sportives_apprenant_idx
  on scolarite.performances_sportives (apprenant_id);

alter table scolarite.performances_sportives enable row level security;

create policy performances_sportives_all on scolarite.performances_sportives
  for all to authenticated
  using (
    exists (
      select 1
      from scolarite.sous_modules sm
      join scolarite.controles c on c.id = sm.module_id
      where sm.id = performances_sportives.sous_module_id
        and (
          socle.current_role() = 'admin'
          or (
            socle.current_role() in ('chef_division', 'instructeur')
            and c.division_id = socle.current_division()
          )
        )
    )
  )
  with check (
    exists (
      select 1
      from scolarite.sous_modules sm
      join scolarite.controles c on c.id = sm.module_id
      where sm.id = performances_sportives.sous_module_id
        and (
          socle.current_role() = 'admin'
          or (
            socle.current_role() in ('chef_division', 'instructeur')
            and c.division_id = socle.current_division()
          )
        )
    )
  );

create trigger audit_performances_sportives
  after insert or update or delete on scolarite.performances_sportives
  for each row execute function socle.audit_trigger();

-- --- 7. Le calcul, rebranché sur l'activité ---------------------------------
-- Le premier paramètre passe du sous-module à l'activité : Postgres refuse
-- de renommer un paramètre par `create or replace`, il faut donc défaire
-- les deux fonctions d'abord — `note_epreuve` avant celle dont elle
-- dépend.

drop function if exists scolarite.note_epreuve(uuid, uuid);
drop function if exists scolarite.note_sportive(uuid, text, numeric);

create or replace function scolarite.note_sportive(
  p_activite_id uuid,
  p_sexe text,
  p_performance numeric
)
returns numeric
language plpgsql
stable
security definer
set search_path = scolarite, socle, public
as $$
declare
  v_bas record;   -- palier de performance immédiatement inférieure
  v_haut record;  -- palier de performance immédiatement supérieure
begin
  if p_sexe is null or p_performance is null then
    return null;
  end if;

  select performance, note into v_bas
  from scolarite.bareme_paliers
  where activite_id = p_activite_id
    and sexe = p_sexe
    and performance <= p_performance
  order by performance desc
  limit 1;

  select performance, note into v_haut
  from scolarite.bareme_paliers
  where activite_id = p_activite_id
    and sexe = p_sexe
    and performance >= p_performance
  order by performance asc
  limit 1;

  -- Aucun palier : pas de barème saisi pour ce sexe.
  if v_bas is null and v_haut is null then
    return null;
  end if;

  -- Hors barème d'un côté : on retient le palier le plus proche, sans
  -- prolonger la droite au-delà. Une performance exceptionnelle vaut la
  -- note du meilleur palier, pas davantage.
  if v_bas is null then
    return v_haut.note;
  end if;
  if v_haut is null then
    return v_bas.note;
  end if;

  if v_haut.performance = v_bas.performance then
    return v_bas.note;
  end if;

  return round(
    v_bas.note
      + (v_haut.note - v_bas.note)
        * (p_performance - v_bas.performance)
        / (v_haut.performance - v_bas.performance),
    2
  );
end;
$$;

-- La note d'un apprenant à une séance : sa performance, lue au barème de
-- l'activité que cette séance faisait passer.
create or replace function scolarite.note_epreuve(
  p_sous_module_id uuid,
  p_apprenant_id uuid
)
returns numeric
language sql
stable
security definer
set search_path = scolarite, socle, public
as $$
  select scolarite.note_sportive(
    (select s.activite_id from scolarite.seances_sportives s
      where s.sous_module_id = p_sous_module_id),
    (select a.sexe from scolarite.apprenants a where a.id = p_apprenant_id),
    (select p.valeur from scolarite.performances_sportives p
      where p.sous_module_id = p_sous_module_id
        and p.apprenant_id = p_apprenant_id)
  );
$$;

revoke execute on function scolarite.note_sportive(uuid, text, numeric) from public;
revoke execute on function scolarite.note_epreuve(uuid, uuid) from public;
grant execute on function scolarite.note_sportive(uuid, text, numeric) to authenticated;
grant execute on function scolarite.note_epreuve(uuid, uuid) to authenticated;

-- --- 8. Les déclencheurs de synchronisation ---------------------------------
-- `sync_note_sportive` et `trg_performance_sportive` (migration 055)
-- restent valables : ils raisonnent en sous-module, et une séance EST un
-- sous-module. Seul le barème change de rattachement.

drop trigger if exists sync_notes_bareme on scolarite.bareme_paliers;

create or replace function scolarite.resync_notes_activite(p_activite_id uuid)
returns void
language plpgsql
security definer
set search_path = scolarite, socle, public
as $$
declare
  v_performance record;
begin
  for v_performance in
    select p.sous_module_id, p.apprenant_id
    from scolarite.performances_sportives p
    join scolarite.seances_sportives s on s.sous_module_id = p.sous_module_id
    where s.activite_id = p_activite_id
  loop
    perform scolarite.sync_note_sportive(
      v_performance.sous_module_id,
      v_performance.apprenant_id
    );
  end loop;
end;
$$;

revoke execute on function scolarite.resync_notes_activite(uuid) from public;

create or replace function scolarite.trg_bareme_palier()
returns trigger
language plpgsql
security definer
set search_path = scolarite, socle, public
as $$
begin
  if tg_op = 'DELETE' then
    perform scolarite.resync_notes_activite(old.activite_id);
    return old;
  end if;

  if tg_op = 'UPDATE'
     and old.activite_id is distinct from new.activite_id then
    perform scolarite.resync_notes_activite(old.activite_id);
  end if;

  perform scolarite.resync_notes_activite(new.activite_id);
  return new;
end;
$$;

create trigger sync_notes_bareme
  after insert or update or delete on scolarite.bareme_paliers
  for each row execute function scolarite.trg_bareme_palier();

-- Une séance qui change d'activité change toutes ses notes.
create or replace function scolarite.trg_seance_sportive()
returns trigger
language plpgsql
security definer
set search_path = scolarite, socle, public
as $$
begin
  if tg_op <> 'UPDATE' or old.activite_id is not distinct from new.activite_id then
    return new;
  end if;
  perform scolarite.resync_notes_epreuve(new.sous_module_id);
  return new;
end;
$$;

drop trigger if exists sync_notes_seance on scolarite.seances_sportives;
create trigger sync_notes_seance
  after update on scolarite.seances_sportives
  for each row execute function scolarite.trg_seance_sportive();

-- --- 9. Le Commandant de Brigade sur les tables refaites --------------------
-- `epreuves_sportives` et `performances_sportives` ont été supprimées puis
-- recréées : leurs politiques de la migration 054 sont parties avec elles.
-- On les rétablit là où elles gardent un sens, et on les étend à la séance.

create policy performances_sportives_commandant on scolarite.performances_sportives
  for all to authenticated
  using (scolarite.commande_l_apprenant(apprenant_id))
  with check (scolarite.commande_l_apprenant(apprenant_id));

create policy seances_sportives_commandant on scolarite.seances_sportives
  for all to authenticated
  using (
    exists (
      select 1 from scolarite.sous_modules sm
      join scolarite.controles c on c.id = sm.module_id
      where sm.id = seances_sportives.sous_module_id
        and scolarite.commande_la_phase(c.classe_id)
    )
  )
  with check (
    exists (
      select 1 from scolarite.sous_modules sm
      join scolarite.controles c on c.id = sm.module_id
      where sm.id = seances_sportives.sous_module_id
        and scolarite.commande_la_phase(c.classe_id)
    )
  );
