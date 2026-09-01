-- ============================================================================
-- LOGISTIQUE (ERP ENSOA) — repris de migration_008_armement_epi.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- ============================================================================
-- Extension du module Armement : référentiel des types d'arme (au lieu d'une
-- saisie libre) et nouveau domaine "Équipement de protection individuelle"
-- (EPI), géré en stock comme les munitions.
-- ============================================================================

create table logistique.type_arme (
  id bigint generated always as identity primary key,
  libelle text unique not null
);

alter table logistique.type_arme enable row level security;
create policy "type_arme lecture" on logistique.type_arme for select using (auth.role() = 'authenticated');
create policy "type_arme ecriture" on logistique.type_arme for all using (
  socle.current_user_role() in ('armurerie', 'chef_soutien_technique')
);

insert into logistique.type_arme (libelle) values
  ('Fusil d''assaut'), ('Pistolet automatique'), ('Mitrailleuse'), ('Fusil de précision'), ('Lance-roquettes');

-- --- Équipement de protection individuelle (EPI) ---------------------------

create table logistique.equipement_protection (
  id bigint generated always as identity primary key,
  libelle text not null,
  quantite_disponible integer not null default 0,
  seuil_critique integer not null default 0
);

alter table logistique.equipement_protection enable row level security;
create policy "epi acces" on logistique.equipement_protection for all using (
  socle.current_user_role() in ('armurerie', 'chef_soutien_technique')
);

-- Attribution individuelle d'un EPI (miroir de dotation_arme), pour le suivi
-- nominatif (qui a quel gilet/casque...), optionnel selon le besoin réel.
create table logistique.dotation_equipement (
  id bigint generated always as identity primary key,
  equipement_id bigint references logistique.equipement_protection(id) not null,
  beneficiaire_matricule text not null,
  date_remise timestamptz not null default now(),
  date_retour_effective timestamptz,
  remise_par uuid references socle.profiles(id) not null,
  motif text
);

alter table logistique.dotation_equipement enable row level security;
create policy "dotation_epi acces" on logistique.dotation_equipement for all using (
  socle.current_user_role() in ('armurerie', 'chef_soutien_technique')
);
