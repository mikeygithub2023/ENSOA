-- ============================================================================
-- SCOLARITÉ (ENSOA GSES) — repris de 003_fiche_signaletique_et_diplomes.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- Migration : étend `apprenants` avec les rubriques de la fiche
-- signalétique (DFS) et ajoute le catalogue de diplômes (relation
-- many-to-many, un apprenant peut cumuler plusieurs diplômes).
--
-- Le matricule devient facultatif : obligatoire pour un stagiaire, pas pour
-- un élève (règle appliquée côté client). Postgres autorise plusieurs NULL
-- sous une contrainte unique, donc la contrainte existante reste valide.

alter table scolarite.apprenants alter column matricule drop not null;

alter table scolarite.apprenants
  add column if not exists grade text,
  add column if not exists telephone text,
  add column if not exists ethnie text,
  add column if not exists date_naissance date,
  add column if not exists lieu_naissance text,
  add column if not exists situation_matrimoniale text,
  add column if not exists nombre_enfants integer,
  add column if not exists nom_pere text,
  add column if not exists nom_mere text,
  add column if not exists contact text,
  add column if not exists email text,
  add column if not exists urgence_nom text,
  add column if not exists urgence_lien text,
  add column if not exists urgence_contact text,
  add column if not exists taille_cm numeric(5, 1),
  add column if not exists poids_kg numeric(5, 1),
  add column if not exists groupe_sanguin text,
  add column if not exists qualification text,
  add column if not exists permis_conduire text;

-- ----------------------------------------------------------------------------
-- Diplômes : catalogue global extensible + association many-to-many avec
-- les apprenants.
-- ----------------------------------------------------------------------------
create table scolarite.diplomes (
  id uuid primary key default gen_random_uuid(),
  nom text not null unique,
  created_at timestamptz not null default now()
);

-- id de substitution (et non une clé primaire composite) pour que
-- audit_trigger() — qui référence toujours `rec.id` — fonctionne sans
-- adaptation, comme pour matiere_modules.
create table scolarite.apprenant_diplomes (
  id uuid primary key default gen_random_uuid(),
  apprenant_id uuid not null references scolarite.apprenants (id) on delete cascade,
  diplome_id uuid not null references scolarite.diplomes (id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (apprenant_id, diplome_id)
);

create index apprenant_diplomes_apprenant_idx on scolarite.apprenant_diplomes (apprenant_id);

alter table scolarite.diplomes enable row level security;
alter table scolarite.apprenant_diplomes enable row level security;

-- diplomes : lecture par tout utilisateur authentifié ; ajout au catalogue
-- par tout le personnel habilité à enregistrer un élève/stagiaire (pas de
-- update/delete pour l'instant, le catalogue ne fait que s'étendre).
create policy diplomes_select on scolarite.diplomes
  for select to authenticated
  using (true);

create policy diplomes_insert_staff on scolarite.diplomes
  for insert to authenticated
  with check (socle.current_role() in ('admin', 'chef_division', 'instructeur', 'medecin'));

create trigger audit_diplomes
  after insert or update or delete on scolarite.diplomes
  for each row execute function socle.audit_trigger();

-- apprenant_diplomes : mêmes droits que sur l'apprenant concerné (lecture
-- élargie au staff de sa division, écriture réservée à admin/chef de
-- division de la division de l'apprenant).
create policy apprenant_diplomes_select on scolarite.apprenant_diplomes
  for select to authenticated
  using (
    exists (
      select 1 from scolarite.apprenants a
      where a.id = apprenant_diplomes.apprenant_id
        and (
          socle.current_role() in ('admin', 'medecin')
          or (socle.current_role() in ('chef_division', 'instructeur') and a.division_id = socle.current_division())
          or a.profile_id = auth.uid()
        )
    )
  );

create policy apprenant_diplomes_write_admin on scolarite.apprenant_diplomes
  for all to authenticated
  using (socle.current_role() = 'admin')
  with check (socle.current_role() = 'admin');

create policy apprenant_diplomes_write_chef_division on scolarite.apprenant_diplomes
  for all to authenticated
  using (
    exists (
      select 1 from scolarite.apprenants a
      where a.id = apprenant_diplomes.apprenant_id
        and socle.current_role() = 'chef_division'
        and a.division_id = socle.current_division()
    )
  )
  with check (
    exists (
      select 1 from scolarite.apprenants a
      where a.id = apprenant_diplomes.apprenant_id
        and socle.current_role() = 'chef_division'
        and a.division_id = socle.current_division()
    )
  );

create trigger audit_apprenant_diplomes
  after insert or update or delete on scolarite.apprenant_diplomes
  for each row execute function socle.audit_trigger();

grant select, insert, update, delete on scolarite.diplomes, scolarite.apprenant_diplomes to authenticated;
