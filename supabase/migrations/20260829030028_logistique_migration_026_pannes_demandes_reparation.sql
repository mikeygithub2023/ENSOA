-- ============================================================================
-- LOGISTIQUE (ERP ENSOA) — migration 026 : pannes et demandes de réparation
--
-- Migration propre à l'application unifiée. À appliquer avec `supabase db
-- push`, ou collée dans l'éditeur SQL de Supabase.
-- ============================================================================

-- Une PANNE est un signalement attaché à un véhicule. Elle N'AFFECTE PAS son
-- état : un véhicule peut porter des pannes et rester disponible pour une
-- mission. Toutes les pannes ne justifient pas une mise en réparation
-- immédiate — c'est précisément ce que la demande, plus bas, vient trancher.
create type logistique.gravite_panne as enum ('legere', 'majeure', 'critique');

create table logistique.panne (
  id bigint generated always as identity primary key,
  vehicule_id bigint references logistique.vehicule(id) not null,
  description text not null,
  gravite logistique.gravite_panne not null default 'legere',
  date_signalement timestamptz not null default now(),
  signale_par uuid references socle.profiles(id) not null,
  -- Renseignée quand la panne est reprise dans une demande de réparation ;
  -- la contrainte est posée après la création de la table `demande_reparation`.
  demande_id bigint,
  resolue boolean not null default false
);

-- Une DEMANDE DE MISE EN RÉPARATION : la décision de réparer, prise au vu des
-- pannes. Elle est d'abord DEMANDÉE ; un supérieur la VALIDE (et c'est à ce
-- moment que le véhicule passe « en réparation » et qu'une réparation est
-- ouverte — logique portée côté application), ou la REFUSE.
create type logistique.statut_demande_reparation
  as enum ('demandee', 'validee', 'refusee');

create table logistique.demande_reparation (
  id bigint generated always as identity primary key,
  vehicule_id bigint references logistique.vehicule(id) not null,
  statut logistique.statut_demande_reparation not null default 'demandee',
  commentaire text,
  date_demande timestamptz not null default now(),
  demande_par uuid references socle.profiles(id) not null,
  date_decision timestamptz,
  decide_par uuid references socle.profiles(id),
  -- La réparation ouverte le jour de la validation ; nulle tant que la demande
  -- n'est pas validée.
  reparation_id bigint references logistique.reparation(id)
);

alter table logistique.panne
  add constraint panne_demande_fk
  foreign key (demande_id) references logistique.demande_reparation(id);

-- --- Politiques RLS ---------------------------------------------------------
-- Lecture ouverte à tout compte authentifié (comme le reste du parc).
-- Écriture — signaler une panne, ouvrir ou décider une demande — réservée au
-- garage, au chef du soutien technique et à l'administrateur.
alter table logistique.panne enable row level security;
alter table logistique.demande_reparation enable row level security;

create policy "panne select" on logistique.panne
  for select using (auth.role() = 'authenticated');
create policy "panne ecriture" on logistique.panne
  for all using (
    socle.current_user_role()
      in ('garage', 'chef_soutien_technique', 'administrateur')
  );

create policy "demande_reparation select" on logistique.demande_reparation
  for select using (auth.role() = 'authenticated');
create policy "demande_reparation ecriture" on logistique.demande_reparation
  for all using (
    socle.current_user_role()
      in ('garage', 'chef_soutien_technique', 'administrateur')
  );
