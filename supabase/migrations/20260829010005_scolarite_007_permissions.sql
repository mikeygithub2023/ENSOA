-- ============================================================================
-- SCOLARITÉ (ENSOA GSES) — repris de 007_permissions.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- Migration : gestion des permissions (autorisations de sortie) des
-- élèves/stagiaires — onglet "Permissions" de l'écran Élèves & Stagiaires.
--
-- Une permission est toujours rattachée à un apprenant précis, dans sa
-- division/classe (dénormalisées ici comme sur `apprenants`, pour un
-- scoping RLS direct sans jointure).

create table scolarite.permissions (
  id uuid primary key default gen_random_uuid(),
  apprenant_id uuid not null references scolarite.apprenants (id) on delete cascade,
  division_id uuid not null references socle.divisions (id),
  classe_id uuid not null references scolarite.classes (id),
  date_depart date not null,
  date_retour date not null,
  localite text,
  motif text,
  personne_contact text,
  created_at timestamptz not null default now(),
  check (date_retour >= date_depart)
);

create index permissions_apprenant_idx on scolarite.permissions (apprenant_id);
create index permissions_classe_idx on scolarite.permissions (classe_id);
create index permissions_division_idx on scolarite.permissions (division_id);

alter table scolarite.permissions enable row level security;

-- select : admin/médecin (vue globale), chef de division/instructeur pour
-- leur division, l'apprenant concerné pour ses propres permissions.
create policy permissions_select_global on scolarite.permissions
  for select to authenticated
  using (socle.current_role() in ('admin', 'medecin'));

create policy permissions_select_division_staff on scolarite.permissions
  for select to authenticated
  using (
    socle.current_role() in ('chef_division', 'instructeur')
    and division_id = socle.current_division()
  );

create policy permissions_select_self on scolarite.permissions
  for select to authenticated
  using (
    exists (
      select 1 from scolarite.apprenants a
      where a.id = permissions.apprenant_id
        and a.profile_id = auth.uid()
    )
  );

-- écriture : admin (toute division) ou chef de division (la sienne
-- uniquement) — même règle que sur `apprenants`.
create policy permissions_write_admin on scolarite.permissions
  for all to authenticated
  using (socle.current_role() = 'admin')
  with check (socle.current_role() = 'admin');

create policy permissions_write_chef_division on scolarite.permissions
  for all to authenticated
  using (socle.current_role() = 'chef_division' and division_id = socle.current_division())
  with check (socle.current_role() = 'chef_division' and division_id = socle.current_division());

create trigger audit_permissions
  after insert or update or delete on scolarite.permissions
  for each row execute function socle.audit_trigger();

grant select, insert, update, delete on scolarite.permissions to authenticated;
