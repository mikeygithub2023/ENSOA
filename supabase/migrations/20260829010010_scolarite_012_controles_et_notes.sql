-- ============================================================================
-- SCOLARITÉ (ENSOA GSES) — repris de 012_controles_et_notes.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- Migration : contrôles (continu/intermédiaire) et notes des élèves/
-- stagiaires — onglet "Contrôle continu / Contrôle intermédiaire" de
-- l'écran Élèves & Stagiaires.
--
-- Un contrôle n'est pas rattaché à une matière précise : c'est une
-- évaluation générale (continu ou intermédiaire) avec son propre
-- coefficient. Les notes (sur 20) sont saisies apprenant par apprenant à
-- l'intérieur du contrôle choisi.

create table scolarite.controles (
  id uuid primary key default gen_random_uuid(),
  division_id uuid not null references socle.divisions (id),
  classe_id uuid not null references scolarite.classes (id),
  type text not null check (type in ('continu', 'intermediaire')),
  libelle text not null,
  coefficient numeric(4, 2) not null check (coefficient > 0),
  created_at timestamptz not null default now()
);

create index controles_classe_idx on scolarite.controles (classe_id);
create index controles_division_idx on scolarite.controles (division_id);

create table scolarite.notes (
  id uuid primary key default gen_random_uuid(),
  controle_id uuid not null references scolarite.controles (id) on delete cascade,
  apprenant_id uuid not null references scolarite.apprenants (id) on delete cascade,
  note numeric(4, 2) not null check (note >= 0 and note <= 20),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (controle_id, apprenant_id)
);

create index notes_controle_idx on scolarite.notes (controle_id);
create index notes_apprenant_idx on scolarite.notes (apprenant_id);

alter table scolarite.controles enable row level security;
alter table scolarite.notes enable row level security;

-- controles : même schéma de droits que permissions/absences/consultations.
create policy controles_select_global on scolarite.controles
  for select to authenticated
  using (socle.current_role() in ('admin', 'medecin'));

create policy controles_select_division_staff on scolarite.controles
  for select to authenticated
  using (
    socle.current_role() in ('chef_division', 'instructeur')
    and division_id = socle.current_division()
  );

create policy controles_select_self on scolarite.controles
  for select to authenticated
  using (
    exists (
      select 1 from scolarite.apprenants a
      where a.classe_id = controles.classe_id
        and a.profile_id = auth.uid()
    )
  );

create policy controles_write_admin on scolarite.controles
  for all to authenticated
  using (socle.current_role() = 'admin')
  with check (socle.current_role() = 'admin');

create policy controles_write_chef_division on scolarite.controles
  for all to authenticated
  using (socle.current_role() = 'chef_division' and division_id = socle.current_division())
  with check (socle.current_role() = 'chef_division' and division_id = socle.current_division());

create trigger audit_controles
  after insert or update or delete on scolarite.controles
  for each row execute function socle.audit_trigger();

-- notes : lecture élargie au staff de la division du contrôle et à
-- l'apprenant concerné (ses propres notes) ; écriture réservée à
-- admin/chef de division, comme le contrôle parent.
create policy notes_select_global on scolarite.notes
  for select to authenticated
  using (socle.current_role() in ('admin', 'medecin'));

create policy notes_select_division_staff on scolarite.notes
  for select to authenticated
  using (
    exists (
      select 1 from scolarite.controles c
      where c.id = notes.controle_id
        and socle.current_role() in ('chef_division', 'instructeur')
        and c.division_id = socle.current_division()
    )
  );

create policy notes_select_self on scolarite.notes
  for select to authenticated
  using (
    exists (
      select 1 from scolarite.apprenants a
      where a.id = notes.apprenant_id
        and a.profile_id = auth.uid()
    )
  );

create policy notes_write_admin on scolarite.notes
  for all to authenticated
  using (socle.current_role() = 'admin')
  with check (socle.current_role() = 'admin');

create policy notes_write_chef_division on scolarite.notes
  for all to authenticated
  using (
    exists (
      select 1 from scolarite.controles c
      where c.id = notes.controle_id
        and socle.current_role() = 'chef_division'
        and c.division_id = socle.current_division()
    )
  )
  with check (
    exists (
      select 1 from scolarite.controles c
      where c.id = notes.controle_id
        and socle.current_role() = 'chef_division'
        and c.division_id = socle.current_division()
    )
  );

create trigger audit_notes
  after insert or update or delete on scolarite.notes
  for each row execute function socle.audit_trigger();

grant select, insert, update, delete on scolarite.controles, scolarite.notes to authenticated;
