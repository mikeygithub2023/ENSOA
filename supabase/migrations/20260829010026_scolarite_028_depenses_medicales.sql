-- ============================================================================
-- SCOLARITÉ (ENSOA GSES) — repris de 028_depenses_medicales.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- Migration : dépenses du volet médical. Deux natures de dépense, d'où
-- la colonne `type` :
--   * 'service'      — besoins courants du service médical (consommables,
--                      approvisionnement de la pharmacie, matériel,
--                      entretien...) : aucun patient rattaché ;
--   * 'consultation' — dépense engagée pour un patient précis à la suite
--                      d'une consultation (analyse, imagerie, médicament
--                      acheté à l'extérieur, hospitalisation externe,
--                      évacuation sanitaire...) : toujours rattachée à la
--                      consultation qui l'a motivée.
-- La contrainte `depenses_rattachement` garantit cette exclusivité : une
-- dépense de service n'a jamais de consultation, une dépense de
-- consultation en a toujours une.
--
-- `montant` est un entier : le franc CFA n'a pas de subdivision en usage,
-- inutile d'introduire des décimales (et les erreurs d'arrondi qui vont
-- avec) dans un état comptable.
--
-- La clé étrangère est en `on delete restrict` : une consultation déjà
-- engagée financièrement ne doit pas pouvoir disparaître et emporter la
-- trace comptable avec elle (la suppression d'une consultation n'est de
-- toute façon offerte que sur celles encore en attente).

create table scolarite.depenses (
  id uuid primary key default gen_random_uuid(),
  date_depense date not null default current_date,
  type text not null check (type in ('service', 'consultation')),
  categorie text not null check (
    categorie in (
      -- Dépenses du service
      'fournitures',
      'approvisionnement_pharmacie',
      'materiel',
      'entretien',
      'transport_service',
      -- Dépenses liées à une consultation
      'analyse',
      'imagerie',
      'medicament',
      'hospitalisation_externe',
      'consultation_externe',
      'evacuation_sanitaire',
      -- Commune aux deux
      'autre'
    )
  ),
  libelle text not null,
  montant integer not null check (montant > 0),
  beneficiaire text,
  reference text,
  observations text,
  consultation_id uuid references scolarite.consultations_medicales (id) on delete restrict,
  created_at timestamptz not null default now(),
  created_by uuid references socle.profiles (id) default auth.uid(),
  constraint depenses_rattachement check (
    (type = 'consultation' and consultation_id is not null)
    or (type = 'service' and consultation_id is null)
  )
);

create index depenses_date_idx on scolarite.depenses (date_depense desc);
create index depenses_consultation_idx on scolarite.depenses (consultation_id);

alter table scolarite.depenses enable row level security;

-- Même portée que le reste du volet santé : l'administrateur et le médecin
-- (rôle global, non rattaché à une division) gèrent les dépenses.
create policy depenses_all_admin_medecin on scolarite.depenses
  for all to authenticated
  using (socle.current_role() in ('admin', 'medecin'))
  with check (socle.current_role() in ('admin', 'medecin'));

create trigger audit_depenses
  after insert or update or delete on scolarite.depenses
  for each row execute function socle.audit_trigger();

grant select, insert, update, delete on scolarite.depenses to authenticated;
