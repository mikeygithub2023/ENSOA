-- ============================================================================
-- SCOLARITÉ (ENSOA GSES) — repris de schema.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- ============================================================================
-- ENSOA GSES — Schéma Supabase (Phase 1 : fondations)
-- À exécuter une seule fois dans Dashboard Supabase > SQL Editor.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Type de rôle applicatif
-- ----------------------------------------------------------------------------
create type socle.app_role as enum (
  'admin',
  'chef_division',
  'instructeur',
  'eleve_stagiaire',
  'medecin'
);

-- ----------------------------------------------------------------------------
-- 2. Divisions
-- ----------------------------------------------------------------------------
create table socle.divisions (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  nom text not null,
  created_at timestamptz not null default now()
);

insert into socle.divisions (code, nom) values
  ('formation_initiale', 'Division de Formation Initiale'),
  ('formation_specialistes', 'Division de Formation des Spécialistes'),
  ('formation_continue', 'Division de Formation Continue');

-- ----------------------------------------------------------------------------
-- 3. Profils (1:1 avec auth.users)
-- ----------------------------------------------------------------------------
create table socle.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  nom text not null default '',
  prenom text not null default '',
  role socle.app_role not null default 'instructeur',
  division_id uuid references socle.divisions (id),
  created_at timestamptz not null default now()
);

-- Crée automatiquement un profil (rôle instructeur par défaut) à la
-- création d'un compte auth.users. L'edge function create-user met ensuite
-- à jour rôle/division/nom/prénom.
create function socle.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = scolarite, socle, public
as $$
begin
  insert into socle.profiles (id, nom, prenom)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'nom', ''),
    coalesce(new.raw_user_meta_data ->> 'prenom', '')
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function socle.handle_new_user();

-- ----------------------------------------------------------------------------
-- 4. Matières, classes/stages, apprenants (scoping par division)
-- ----------------------------------------------------------------------------
-- Catalogue global : créé uniquement par l'administrateur. L'affectation
-- d'une matière à une division/classe se fait via matiere_modules.
create table scolarite.matieres (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  nom text not null,
  created_at timestamptz not null default now()
);

-- Référentiel des classes (contiennent des élèves) et stages (contiennent
-- des stagiaires) par division — géré par le chef de division concerné (ou
-- l'admin pour n'importe quelle division).
create table scolarite.classes (
  id uuid primary key default gen_random_uuid(),
  division_id uuid not null references socle.divisions (id),
  type text not null check (type in ('classe', 'stage')),
  nom text not null,
  created_at timestamptz not null default now(),
  unique (division_id, type, nom)
);

create index classes_division_idx on scolarite.classes (division_id);

create table scolarite.apprenants (
  id uuid primary key default gen_random_uuid(),
  division_id uuid not null references socle.divisions (id),
  profile_id uuid unique references socle.profiles (id),
  type text not null check (type in ('eleve', 'stagiaire')),
  matricule text not null unique,
  nom text not null,
  prenom text not null,
  classe_id uuid references scolarite.classes (id),
  statut text not null default 'actif' check (statut in ('actif', 'radie', 'diplome', 'suspendu')),
  created_at timestamptz not null default now()
);

create index apprenants_division_idx on scolarite.apprenants (division_id);

-- Association matière ↔ (division, classe), avec le coefficient de la
-- matière pour cette classe — gérée par le chef de division concerné (ou
-- l'admin pour n'importe quelle division).
create table scolarite.matiere_modules (
  id uuid primary key default gen_random_uuid(),
  matiere_id uuid not null references scolarite.matieres (id) on delete cascade,
  division_id uuid not null references socle.divisions (id),
  classe_id uuid not null references scolarite.classes (id) on delete cascade,
  coefficient numeric(4, 2) not null check (coefficient > 0),
  created_at timestamptz not null default now(),
  unique (matiere_id, classe_id)
);

create index matiere_modules_division_idx on scolarite.matiere_modules (division_id);

-- ----------------------------------------------------------------------------
-- 5. Audit log
-- ----------------------------------------------------------------------------
create table socle.audit_log (
  id bigint generated always as identity primary key,
  actor_id uuid,
  action text not null,
  table_name text not null,
  record_id text,
  division_id uuid,
  meta jsonb,
  created_at timestamptz not null default now()
);

create function socle.audit_trigger()
returns trigger
language plpgsql
security definer
set search_path = scolarite, socle, public
as $$
declare
  rec record;
  division uuid;
begin
  rec := coalesce(new, old);

  begin
    division := rec.division_id;
  exception when undefined_column then
    division := null;
  end;

  insert into socle.audit_log (actor_id, action, table_name, record_id, division_id, meta)
  values (
    auth.uid(),
    tg_op,
    tg_table_name,
    rec.id::text,
    division,
    case tg_op
      when 'DELETE' then to_jsonb(old)
      else to_jsonb(new)
    end
  );

  return rec;
end;
$$;

create trigger audit_profiles
  after insert or update or delete on socle.profiles
  for each row execute function socle.audit_trigger();

create trigger audit_apprenants
  after insert or update or delete on scolarite.apprenants
  for each row execute function socle.audit_trigger();

create trigger audit_matieres
  after insert or update or delete on scolarite.matieres
  for each row execute function socle.audit_trigger();

create trigger audit_classes
  after insert or update or delete on scolarite.classes
  for each row execute function socle.audit_trigger();

create trigger audit_matiere_modules
  after insert or update or delete on scolarite.matiere_modules
  for each row execute function socle.audit_trigger();

-- ----------------------------------------------------------------------------
-- 6. Fonctions helper RLS (SECURITY DEFINER pour éviter la récursion)
-- ----------------------------------------------------------------------------
create function socle.current_role()
returns socle.app_role
language sql
security definer
stable
set search_path = scolarite, socle, public
as $$
  select role from socle.profiles where id = auth.uid();
$$;

create function socle.current_division()
returns uuid
language sql
security definer
stable
set search_path = scolarite, socle, public
as $$
  select division_id from socle.profiles where id = auth.uid();
$$;

-- ----------------------------------------------------------------------------
-- 7. Row Level Security
-- ----------------------------------------------------------------------------
alter table socle.divisions enable row level security;
alter table socle.profiles enable row level security;
alter table scolarite.apprenants enable row level security;
alter table scolarite.matieres enable row level security;
alter table scolarite.classes enable row level security;
alter table scolarite.matiere_modules enable row level security;
alter table socle.audit_log enable row level security;

-- divisions : lecture par tout utilisateur authentifié (référentiel statique)
create policy divisions_select on socle.divisions
  for select to authenticated
  using (true);

-- profiles
create policy profiles_select_self on socle.profiles
  for select to authenticated
  using (id = auth.uid());

create policy profiles_select_admin on socle.profiles
  for select to authenticated
  using (socle.current_role() = 'admin');

create policy profiles_select_division_staff on socle.profiles
  for select to authenticated
  using (
    socle.current_role() in ('chef_division', 'instructeur')
    and division_id = socle.current_division()
  );

create policy profiles_update_admin on socle.profiles
  for update to authenticated
  using (socle.current_role() = 'admin')
  with check (socle.current_role() = 'admin');

-- apprenants
create policy apprenants_select_global on scolarite.apprenants
  for select to authenticated
  using (socle.current_role() in ('admin', 'medecin'));

create policy apprenants_select_division_staff on scolarite.apprenants
  for select to authenticated
  using (
    socle.current_role() in ('chef_division', 'instructeur')
    and division_id = socle.current_division()
  );

create policy apprenants_select_self on scolarite.apprenants
  for select to authenticated
  using (profile_id = auth.uid());

create policy apprenants_write_admin on scolarite.apprenants
  for all to authenticated
  using (socle.current_role() = 'admin')
  with check (socle.current_role() = 'admin');

create policy apprenants_write_chef_division on scolarite.apprenants
  for all to authenticated
  using (socle.current_role() = 'chef_division' and division_id = socle.current_division())
  with check (socle.current_role() = 'chef_division' and division_id = socle.current_division());

-- matieres : catalogue global, lisible par tous, modifiable par l'admin
-- uniquement (les chefs de division l'affectent via matiere_modules).
create policy matieres_select on scolarite.matieres
  for select to authenticated
  using (true);

create policy matieres_write_admin on scolarite.matieres
  for all to authenticated
  using (socle.current_role() = 'admin')
  with check (socle.current_role() = 'admin');

-- classes : référentiel par division
create policy classes_select_admin on scolarite.classes
  for select to authenticated
  using (socle.current_role() = 'admin');

create policy classes_select_division_staff on scolarite.classes
  for select to authenticated
  using (
    socle.current_role() in ('chef_division', 'instructeur')
    and division_id = socle.current_division()
  );

create policy classes_select_own on scolarite.classes
  for select to authenticated
  using (
    socle.current_role() = 'eleve_stagiaire'
    and division_id = socle.current_division()
  );

create policy classes_write_admin on scolarite.classes
  for all to authenticated
  using (socle.current_role() = 'admin')
  with check (socle.current_role() = 'admin');

create policy classes_write_chef_division on scolarite.classes
  for all to authenticated
  using (socle.current_role() = 'chef_division' and division_id = socle.current_division())
  with check (socle.current_role() = 'chef_division' and division_id = socle.current_division());

-- matiere_modules
create policy matiere_modules_select_admin on scolarite.matiere_modules
  for select to authenticated
  using (socle.current_role() = 'admin');

create policy matiere_modules_select_division_staff on scolarite.matiere_modules
  for select to authenticated
  using (
    socle.current_role() in ('chef_division', 'instructeur')
    and division_id = socle.current_division()
  );

create policy matiere_modules_write_admin on scolarite.matiere_modules
  for all to authenticated
  using (socle.current_role() = 'admin')
  with check (socle.current_role() = 'admin');

create policy matiere_modules_write_chef_division on scolarite.matiere_modules
  for all to authenticated
  using (socle.current_role() = 'chef_division' and division_id = socle.current_division())
  with check (socle.current_role() = 'chef_division' and division_id = socle.current_division());

-- audit_log : lecture admin uniquement, écriture réservée au trigger (security definer)
create policy audit_log_select_admin on socle.audit_log
  for select to authenticated
  using (socle.current_role() = 'admin');

-- ----------------------------------------------------------------------------
-- 8. Droits de base (RLS filtre les lignes, encore faut-il le droit d'accès
--    à la table elle-même — sans ces GRANT, PostgREST renvoie 42501 même si
--    les policies ci-dessus sont correctes).
-- ----------------------------------------------------------------------------
grant select, insert, update, delete on all tables in schema scolarite to authenticated;
grant usage, select on all sequences in schema scolarite to authenticated;
alter default privileges in schema scolarite grant select, insert, update, delete on tables to authenticated;
alter default privileges in schema scolarite grant usage, select on sequences to authenticated;
