-- ============================================================================
-- SCOLARITÉ (ENSOA GSES) — repris de 051_sous_modules.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- Migration : le module se décompose en sous-modules.
--
-- Jusqu'ici, un module portait une note unique par apprenant. Il devient un
-- contenant : sa note est la moyenne pondérée de ses sous-modules, chacun
-- avec son coefficient dans la phase.
--
--   phase
--     ├── matière        + coefficient   (contrôle continu, examen)
--     └── module         + coefficient
--           └── sous-module + coefficient   ← nouveau
--
-- Le module reste ce qu'il était en base — une ligne de `controles` de type
-- « module », rattachée à une phase et à une matière. Seule change la façon
-- dont sa note se forme.
--
-- ---------------------------------------------------------------------------
-- `nature` distingue dès maintenant deux sortes de sous-modules :
--
--   'note'  — la note est saisie par l'instructeur, comme partout ailleurs ;
--   'sport' — la note est CALCULÉE à partir d'une performance et d'un
--             barème (migration 052). Le module « Sport » d'une phase n'a
--             que des sous-modules de cette sorte : ses épreuves.
--
-- La colonne est posée ici plutôt qu'en 052 pour que la table n'ait à être
-- modifiée qu'une fois.

create table scolarite.sous_modules (
  id uuid primary key default gen_random_uuid(),
  module_id uuid not null references scolarite.controles (id) on delete cascade,
  nom text not null,
  coefficient numeric(4, 2) not null check (coefficient > 0),
  nature text not null default 'note' check (nature in ('note', 'sport')),
  ordre integer not null default 0,
  created_at timestamptz not null default now(),
  unique (module_id, nom)
);

create index sous_modules_module_idx on scolarite.sous_modules (module_id, ordre);

alter table scolarite.sous_modules enable row level security;

-- Même portée que les contrôles auxquels ils appartiennent : l'encadrement
-- de la division, et l'administrateur partout. L'élève ne lit pas cette
-- table — ses notes lui parviennent par les fonctions dédiées.
create policy sous_modules_select on scolarite.sous_modules
  for select to authenticated
  using (
    exists (
      select 1 from scolarite.controles c
      where c.id = sous_modules.module_id
        and (
          socle.current_role() = 'admin'
          or (
            socle.current_role() in ('chef_division', 'instructeur')
            and c.division_id = socle.current_division()
          )
        )
    )
  );

create policy sous_modules_write on scolarite.sous_modules
  for all to authenticated
  using (
    exists (
      select 1 from scolarite.controles c
      where c.id = sous_modules.module_id
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
      select 1 from scolarite.controles c
      where c.id = sous_modules.module_id
        and (
          socle.current_role() = 'admin'
          or (
            socle.current_role() in ('chef_division', 'instructeur')
            and c.division_id = socle.current_division()
          )
        )
    )
  );

create trigger audit_sous_modules
  after insert or update or delete on scolarite.sous_modules
  for each row execute function socle.audit_trigger();

-- ---------------------------------------------------------------------------
-- La note se rattache désormais soit à une matière, soit à un sous-module.
--
--   contrôle continu, examen → une note par matière, comme avant ;
--   module                   → une note par sous-module.
--
-- L'un ou l'autre, jamais les deux, jamais aucun : c'est ce que dit la
-- contrainte ci-dessous. Elle remplace l'index partiel de la migration 018,
-- qui admettait une note de module sans rattachement.

alter table scolarite.notes
  add column if not exists sous_module_id uuid
    references scolarite.sous_modules (id) on delete cascade;

drop index if exists scolarite.notes_controle_apprenant_sans_matiere_uq;

alter table scolarite.notes
  add constraint notes_rattachement
  check (num_nonnulls(matiere_id, sous_module_id) = 1);

-- Deux index partiels plutôt qu'une contrainte unique unique : une colonne
-- nulle n'entre jamais en conflit avec une autre, l'unicité ne se ferait
-- donc pas.
create unique index notes_par_matiere_uq
  on scolarite.notes (controle_id, apprenant_id, matiere_id)
  where matiere_id is not null;

create unique index notes_par_sous_module_uq
  on scolarite.notes (apprenant_id, sous_module_id)
  where sous_module_id is not null;

create index notes_sous_module_idx on scolarite.notes (sous_module_id);
