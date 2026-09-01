-- ============================================================================
-- SCOLARITÉ (ENSOA GSES) — repris de 026_antecedents_medicaux.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- Migration : antécédents médicaux de l'apprenant (allergies, maladies
-- chroniques, chirurgies, antécédents familiaux, traitement en cours) —
-- une fiche persistante par apprenant, distincte des consultations
-- ponctuelles, réservée à l'administrateur et au médecin (données
-- médicales sensibles, contrairement à la fiche signalétique générale).

create table scolarite.antecedents_medicaux (
  id uuid primary key default gen_random_uuid(),
  apprenant_id uuid not null unique references scolarite.apprenants (id) on delete cascade,
  allergies text,
  antecedents_pathologiques text,
  antecedents_chirurgicaux text,
  antecedents_familiaux text,
  traitement_en_cours text,
  observations text,
  updated_at timestamptz not null default now(),
  updated_by uuid references socle.profiles (id)
);

alter table scolarite.antecedents_medicaux enable row level security;

create policy antecedents_medicaux_all_admin_medecin on scolarite.antecedents_medicaux
  for all to authenticated
  using (socle.current_role() in ('admin', 'medecin'))
  with check (socle.current_role() in ('admin', 'medecin'));

-- L'apprenant concerné peut voir ses propres antécédents.
create policy antecedents_medicaux_select_self on scolarite.antecedents_medicaux
  for select to authenticated
  using (
    exists (
      select 1 from scolarite.apprenants a
      where a.id = antecedents_medicaux.apprenant_id
        and a.profile_id = auth.uid()
    )
  );

create trigger audit_antecedents_medicaux
  after insert or update or delete on scolarite.antecedents_medicaux
  for each row execute function socle.audit_trigger();

grant select, insert, update, delete on scolarite.antecedents_medicaux to authenticated;
