-- ============================================================================
-- SCOLARITÉ (ENSOA GSES) — repris de 052_sport_epreuves_et_baremes.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- Migration : l'espace sport.
--
-- Le sport est un module comme un autre — une ligne de `controles` de type
-- « module », rattachée à une phase. Ses sous-modules sont les épreuves :
-- 3000 mètres, tractions, parcours du combattant. Comme le module appartient
-- à la phase, le sport de FCB et celui de CA1 sont deux modules distincts,
-- et leurs moyennes ne se mélangent jamais.
--
-- Ce qui distingue une épreuve d'un sous-module ordinaire : sa note n'est
-- pas saisie, elle est calculée depuis une performance.
--
--   performance  ──(barème de l'épreuve, pour le sexe de l'apprenant)──▶  note
--
-- ---------------------------------------------------------------------------
-- Trois notions, et pourquoi elles sont séparées :
--
--   `sous_modules` porte l'épreuve elle-même (nom, coefficient) — elle est
--   un sous-module, elle entre dans la moyenne du module comme les autres.
--
--   `epreuves_sportives` porte ce qui ne concerne que le sport : l'unité de
--   la performance et son sens. Une table à part plutôt que des colonnes
--   nulles sur tous les sous-modules du monde.
--
--   `bareme_paliers` porte la correspondance chiffrée, par sexe. C'est
--   l'école qui la saisit : aucun barème n'est câblé dans le programme,
--   ils changent d'une école et d'une année à l'autre.

-- --- 1. L'épreuve -----------------------------------------------------------
create table scolarite.epreuves_sportives (
  sous_module_id uuid primary key
    references scolarite.sous_modules (id) on delete cascade,
  unite text not null check (unite in ('secondes', 'metres', 'repetitions', 'points')),
  -- Au 3000 mètres, la meilleure performance est la plus petite ; à la
  -- traction, la plus grande. Sans cette indication, le barème ne saurait
  -- pas dans quel sens interpoler.
  meilleur text not null check (meilleur in ('minimum', 'maximum')),
  consigne text,
  created_at timestamptz not null default now()
);

alter table scolarite.epreuves_sportives enable row level security;

create policy epreuves_sportives_all on scolarite.epreuves_sportives
  for all to authenticated
  using (
    exists (
      select 1
      from scolarite.sous_modules sm
      join scolarite.controles c on c.id = sm.module_id
      where sm.id = epreuves_sportives.sous_module_id
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
      where sm.id = epreuves_sportives.sous_module_id
        and (
          socle.current_role() = 'admin'
          or (
            socle.current_role() in ('chef_division', 'instructeur')
            and c.division_id = socle.current_division()
          )
        )
    )
  );

-- --- 2. Le barème -----------------------------------------------------------
-- Une suite de paliers : « 12'00" vaut 20, 13'00" vaut 17 ». Le système
-- interpole entre deux paliers voisins et borne aux extrémités.
create table scolarite.bareme_paliers (
  id uuid primary key default gen_random_uuid(),
  sous_module_id uuid not null
    references scolarite.epreuves_sportives (sous_module_id) on delete cascade,
  sexe text not null check (sexe in ('M', 'F')),
  performance numeric(10, 2) not null,
  note numeric(4, 2) not null check (note >= 0 and note <= 20),
  created_at timestamptz not null default now(),
  -- Une performance ne peut valoir deux notes pour le même sexe.
  unique (sous_module_id, sexe, performance)
);

create index bareme_paliers_epreuve_idx
  on scolarite.bareme_paliers (sous_module_id, sexe, performance);

alter table scolarite.bareme_paliers enable row level security;

create policy bareme_paliers_all on scolarite.bareme_paliers
  for all to authenticated
  using (
    exists (
      select 1
      from scolarite.sous_modules sm
      join scolarite.controles c on c.id = sm.module_id
      where sm.id = bareme_paliers.sous_module_id
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
      where sm.id = bareme_paliers.sous_module_id
        and (
          socle.current_role() = 'admin'
          or (
            socle.current_role() in ('chef_division', 'instructeur')
            and c.division_id = socle.current_division()
          )
        )
    )
  );

-- --- 3. La performance ------------------------------------------------------
create table scolarite.performances_sportives (
  id uuid primary key default gen_random_uuid(),
  sous_module_id uuid not null
    references scolarite.epreuves_sportives (sous_module_id) on delete cascade,
  apprenant_id uuid not null references scolarite.apprenants (id) on delete cascade,
  valeur numeric(10, 2) not null check (valeur >= 0),
  date_epreuve date not null default current_date,
  observations text,
  saisie_par uuid references socle.profiles (id) default auth.uid(),
  created_at timestamptz not null default now(),
  -- Une performance par épreuve et par apprenant : on garde la dernière
  -- mesure, pas un historique de tentatives.
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

-- --- 4. Le calcul -----------------------------------------------------------
-- Convertit une performance en note, par interpolation linéaire entre les
-- deux paliers qui l'encadrent.
--
-- Aux extrémités, on ne prolonge pas la droite : une performance meilleure
-- que le meilleur palier vaut la note de ce palier, et non davantage. Sans
-- cette borne, un temps exceptionnel donnerait 24/20.
--
-- `null` quand l'épreuve n'a pas de barème pour ce sexe : mieux vaut une
-- note absente qu'une note inventée.
create function scolarite.note_sportive(
  p_sous_module_id uuid,
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
  where sous_module_id = p_sous_module_id
    and sexe = p_sexe
    and performance <= p_performance
  order by performance desc
  limit 1;

  select performance, note into v_haut
  from scolarite.bareme_paliers
  where sous_module_id = p_sous_module_id
    and sexe = p_sexe
    and performance >= p_performance
  order by performance asc
  limit 1;

  -- Aucun palier : pas de barème saisi pour ce sexe.
  if v_bas is null and v_haut is null then
    return null;
  end if;

  -- Hors barème d'un côté : on retient le palier le plus proche, sans
  -- prolonger la droite au-delà.
  if v_bas is null then
    return v_haut.note;
  end if;
  if v_haut is null then
    return v_bas.note;
  end if;

  -- Palier exact, ou deux paliers de même performance.
  if v_haut.performance = v_bas.performance then
    return v_bas.note;
  end if;

  -- Interpolation linéaire entre les deux paliers encadrants. Le sens de
  -- l'épreuve n'a pas à intervenir : il est déjà porté par le barème, où
  -- la note décroît quand la performance se dégrade.
  return round(
    v_bas.note
      + (v_haut.note - v_bas.note)
        * (p_performance - v_bas.performance)
        / (v_haut.performance - v_bas.performance),
    2
  );
end;
$$;

-- La note d'un apprenant à une épreuve, telle qu'elle entre dans la
-- moyenne du module Sport.
create function scolarite.note_epreuve(
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
    p_sous_module_id,
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
