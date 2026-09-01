-- ============================================================================
-- SCOLARITÉ (ENSOA GSES) — repris de 010_consultations_medicales.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- Migration : gestion des consultations médicales de routine — onglet
-- "Consultations médicales" de l'écran Élèves & Stagiaires.
--
-- Ce qui est enregistré ici, c'est l'AUTORISATION d'un apprenant à
-- consulter le médecin pour une visite de routine : tant qu'elle n'existe
-- pas, le médecin ne peut pas faire cette consultation-là (les
-- consultations d'urgence, elles, ne nécessitent aucune autorisation et
-- restent hors périmètre de cette table).
--
-- Cycle de vie : en_attente (juste enregistrée) -> en_cours (le médecin a
-- démarré la consultation) -> terminee (le médecin a rempli ses
-- prescriptions : jours de repos, exemption, hospitalisation interne ou
-- externe).

create table scolarite.consultations_medicales (
  id uuid primary key default gen_random_uuid(),
  apprenant_id uuid not null references scolarite.apprenants (id) on delete cascade,
  division_id uuid not null references socle.divisions (id),
  classe_id uuid not null references scolarite.classes (id),
  date_souhaitee date not null,
  statut text not null default 'en_attente' check (statut in ('en_attente', 'en_cours', 'terminee')),
  jours_repos integer check (jours_repos is null or jours_repos >= 0),
  exemption boolean not null default false,
  hospitalisation_interne boolean not null default false,
  hospitalisation_externe boolean not null default false,
  created_at timestamptz not null default now()
);

create index consultations_medicales_apprenant_idx on scolarite.consultations_medicales (apprenant_id);
create index consultations_medicales_classe_idx on scolarite.consultations_medicales (classe_id);
create index consultations_medicales_division_idx on scolarite.consultations_medicales (division_id);

alter table scolarite.consultations_medicales enable row level security;

-- select : admin/médecin (vue globale), chef de division/instructeur pour
-- leur division, l'apprenant concerné pour ses propres consultations.
create policy consultations_medicales_select_global on scolarite.consultations_medicales
  for select to authenticated
  using (socle.current_role() in ('admin', 'medecin'));

create policy consultations_medicales_select_division_staff on scolarite.consultations_medicales
  for select to authenticated
  using (
    socle.current_role() in ('chef_division', 'instructeur')
    and division_id = socle.current_division()
  );

create policy consultations_medicales_select_self on scolarite.consultations_medicales
  for select to authenticated
  using (
    exists (
      select 1 from scolarite.apprenants a
      where a.id = consultations_medicales.apprenant_id
        and a.profile_id = auth.uid()
    )
  );

-- écriture : admin (partout), chef de division (sa division, pour
-- enregistrer les autorisations), médecin (partout, pour démarrer/
-- terminer les consultations et saisir ses prescriptions).
create policy consultations_medicales_write_admin on scolarite.consultations_medicales
  for all to authenticated
  using (socle.current_role() = 'admin')
  with check (socle.current_role() = 'admin');

create policy consultations_medicales_write_chef_division on scolarite.consultations_medicales
  for all to authenticated
  using (socle.current_role() = 'chef_division' and division_id = socle.current_division())
  with check (socle.current_role() = 'chef_division' and division_id = socle.current_division());

create policy consultations_medicales_write_medecin on scolarite.consultations_medicales
  for all to authenticated
  using (socle.current_role() = 'medecin')
  with check (socle.current_role() = 'medecin');

create trigger audit_consultations_medicales
  after insert or update or delete on scolarite.consultations_medicales
  for each row execute function socle.audit_trigger();

grant select, insert, update, delete on scolarite.consultations_medicales to authenticated;
