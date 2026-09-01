-- ============================================================================
-- SCOLARITÉ (ENSOA GSES) — repris de 050_promotions_et_phases.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- Migration : réarticulation de la scolarité.
--
--   division
--     ├── promotion            (formation initiale, formation des spécialistes)
--     │     └── phase          (ex-« classe » : FCB, CA1…)
--     └── stage                (formation continue)
--
-- ---------------------------------------------------------------------------
-- Ce que cette migration EFFACE
--
--   Les notes et les évaluations. Le module cesse de porter une note
--   directe — il la tirera de ses sous-modules (migration 051) — et
--   conserver les anciennes n'aurait plus de sens.
--
-- Ce qu'elle NE touche PAS, malgré l'autorisation d'effacer
--
--   Les classes elles-mêmes, et avec elles les permissions, absences,
--   consultations et visites médicales : toutes s'y rattachent sans
--   cascade. Les supprimer aurait emporté le dossier médical et
--   disciplinaire de l'école, ce qui n'était pas l'objet.
--
--   Les classes existantes deviennent donc des phases, rattachées à une
--   promotion créée pour l'occasion et laissée à renommer. Les
--   affectations de matières et leurs coefficients restent valables : le
--   modèle ne les change pas.
--
-- ---------------------------------------------------------------------------
-- « Phase » est le mot de l'école, « classes » reste le nom de la table :
-- une quarantaine de fichiers s'y réfèrent, et le renommer n'apporterait
-- rien à l'utilisateur, qui ne lit que l'écran.

-- --- 1. Les promotions ------------------------------------------------------
create table if not exists scolarite.promotions (
  id uuid primary key default gen_random_uuid(),
  division_id uuid not null references socle.divisions (id) on delete cascade,
  nom text not null,
  annee integer,
  created_at timestamptz not null default now(),
  unique (division_id, nom)
);

create index if not exists promotions_division_idx on scolarite.promotions (division_id);

alter table scolarite.promotions enable row level security;

drop policy if exists promotions_select on scolarite.promotions;
create policy promotions_select on scolarite.promotions
  for select to authenticated
  using (
    socle.current_role() in ('admin', 'medecin')
    or division_id = socle.current_division()
  );

drop policy if exists promotions_write_admin on scolarite.promotions;
create policy promotions_write_admin on scolarite.promotions
  for all to authenticated
  using (socle.current_role() = 'admin')
  with check (socle.current_role() = 'admin');

drop policy if exists promotions_write_chef_division on scolarite.promotions;
create policy promotions_write_chef_division on scolarite.promotions
  for all to authenticated
  using (
    socle.current_role() = 'chef_division'
    and division_id = socle.current_division()
  )
  with check (
    socle.current_role() = 'chef_division'
    and division_id = socle.current_division()
  );

drop trigger if exists audit_promotions on scolarite.promotions;
create trigger audit_promotions
  after insert or update or delete on scolarite.promotions
  for each row execute function socle.audit_trigger();

-- --- 2. Les phases ----------------------------------------------------------
alter table scolarite.classes
  add column if not exists promotion_id uuid
    references scolarite.promotions (id) on delete cascade;

create index if not exists classes_promotion_idx on scolarite.classes (promotion_id);

-- L'ancienne contrainte n'admettait que « classe » et « stage » : elle doit
-- tomber avant que les classes ne deviennent des phases, sinon la mise à
-- jour ci-dessous est refusée.
alter table scolarite.classes drop constraint if exists classes_type_check;
alter table scolarite.classes drop constraint if exists classes_rattachement;

-- Une promotion d'accueil par division à promotions, pour que les classes
-- déjà saisies deviennent des phases sans être perdues. Son nom est un
-- appel à la renommer.
insert into scolarite.promotions (division_id, nom)
select d.id, 'Promotion à préciser'
from socle.divisions d
where d.code in ('formation_initiale', 'formation_specialistes')
  and exists (select 1 from scolarite.classes c where c.division_id = d.id)
on conflict (division_id, nom) do nothing;

-- Formation initiale et spécialistes : les classes deviennent des phases,
-- rattachées à la promotion d'accueil de leur division.
update scolarite.classes c
  set type = 'phase',
      promotion_id = p.id
from scolarite.promotions p
join socle.divisions d on d.id = p.division_id
where c.division_id = p.division_id
  and d.code in ('formation_initiale', 'formation_specialistes')
  and p.nom = 'Promotion à préciser';

-- Formation continue : tout y est stage, sans promotion.
update scolarite.classes c
  set type = 'stage',
      promotion_id = null
from socle.divisions d
where d.id = c.division_id
  and d.code = 'formation_continue';

alter table scolarite.classes
  add constraint classes_type_check check (type in ('phase', 'stage'));

-- Une phase appartient à une promotion ; un stage n'en a pas. C'est cette
-- règle qui distingue les deux branches de l'arbre.
alter table scolarite.classes
  add constraint classes_rattachement check (
    (type = 'phase' and promotion_id is not null)
    or (type = 'stage' and promotion_id is null)
  );

-- --- 3. Le sexe de l'apprenant ----------------------------------------------
-- Le barème sportif en dépend : un même temps ne vaut pas la même note
-- pour un homme et pour une femme. Facultatif en base — l'effectif déjà
-- saisi ne le renseigne pas —, mais exigé à la saisie d'une performance.
alter table scolarite.apprenants
  add column if not exists sexe text check (sexe in ('M', 'F'));

-- --- 4. Table rase des évaluations ------------------------------------------
-- Dans cet ordre : les notes s'appuient sur les contrôles.
delete from scolarite.notes;
delete from scolarite.controles;
