-- ============================================================================
-- SCOLARITÉ (ENSOA GSES) — repris de 008_absences.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- Migration : gestion des absences des élèves/stagiaires — onglet
-- "Absences" de l'écran Élèves & Stagiaires. Même principe que les
-- permissions (migration 007) : toujours rattachée à un apprenant précis,
-- division/classe dénormalisées pour un scoping RLS direct.

create table scolarite.absences (
  id uuid primary key default gen_random_uuid(),
  apprenant_id uuid not null references scolarite.apprenants (id) on delete cascade,
  division_id uuid not null references socle.divisions (id),
  classe_id uuid not null references scolarite.classes (id),
  date_debut date not null,
  date_fin date not null,
  motif text,
  justifiee boolean not null default false,
  created_at timestamptz not null default now(),
  check (date_fin >= date_debut)
);

create index absences_apprenant_idx on scolarite.absences (apprenant_id);
create index absences_classe_idx on scolarite.absences (classe_id);
create index absences_division_idx on scolarite.absences (division_id);

alter table scolarite.absences enable row level security;

-- select : admin/médecin (vue globale), chef de division/instructeur pour
-- leur division, l'apprenant concerné pour ses propres absences.
create policy absences_select_global on scolarite.absences
  for select to authenticated
  using (socle.current_role() in ('admin', 'medecin'));

create policy absences_select_division_staff on scolarite.absences
  for select to authenticated
  using (
    socle.current_role() in ('chef_division', 'instructeur')
    and division_id = socle.current_division()
  );

create policy absences_select_self on scolarite.absences
  for select to authenticated
  using (
    exists (
      select 1 from scolarite.apprenants a
      where a.id = absences.apprenant_id
        and a.profile_id = auth.uid()
    )
  );

-- écriture : admin (toute division) ou chef de division (la sienne
-- uniquement) — même règle que sur `apprenants`/`permissions`.
create policy absences_write_admin on scolarite.absences
  for all to authenticated
  using (socle.current_role() = 'admin')
  with check (socle.current_role() = 'admin');

create policy absences_write_chef_division on scolarite.absences
  for all to authenticated
  using (socle.current_role() = 'chef_division' and division_id = socle.current_division())
  with check (socle.current_role() = 'chef_division' and division_id = socle.current_division());

create trigger audit_absences
  after insert or update or delete on scolarite.absences
  for each row execute function socle.audit_trigger();

grant select, insert, update, delete on scolarite.absences to authenticated;
