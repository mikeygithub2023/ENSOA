-- ============================================================================
-- LOGISTIQUE (ERP ENSOA) — repris de migration_003_repartitions.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- ============================================================================
-- Migration : la RÉPARTITION devient une entité à part entière (elle peut
-- exister dans plusieurs soutes à la fois), pas un simple libellé sur la
-- ligne soute_type_stock. Remplace toute version précédente de ce fichier
-- que vous auriez déjà exécutée — celle-ci est idempotente (peut être relancée
-- sans risque, y compris après l'ancienne version).
-- À exécuter dans Supabase → SQL Editor, après migration_002.
-- ============================================================================

-- --- Table des répartitions ---------------------------------------------------
create table if not exists logistique.repartition (
  id bigint generated always as identity primary key,
  libelle text not null unique
);

alter table logistique.repartition enable row level security;

drop policy if exists "repartition select" on logistique.repartition;
create policy "repartition select" on logistique.repartition for select using (auth.role() = 'authenticated');

-- Seul le Chef Soutien Technique gère la LISTE des répartitions (création) ;
-- le soutien pétrolier les utilise (dépotage/distribution) mais n'en crée pas.
drop policy if exists "repartition ecriture" on logistique.repartition;
create policy "repartition ecriture" on logistique.repartition
  for all using (socle.current_user_role() = 'chef_soutien_technique');

-- Seul le Chef Soutien Technique crée des soutes (le soutien pétrolier les
-- utilise mais n'en crée pas) — restreint la policy définie dans schema.sql.
drop policy if exists "soute ecriture" on logistique.soute;
create policy "soute ecriture" on logistique.soute
  for all using (socle.current_user_role() = 'chef_soutien_technique');

-- --- Lien répartition sur soute_type_stock (remplace l'éventuelle colonne libelle) --
alter table logistique.soute_type_stock add column if not exists repartition_id bigint references logistique.repartition(id);
alter table logistique.soute_type_stock drop column if exists libelle;

-- --- Données réelles : Soute Bouaké avec ses 3 répartitions --------------------
insert into logistique.repartition (libelle) values ('BA1'), ('CA1'), ('CA2'), ('Général')
  on conflict (libelle) do nothing;


-- Le dépotage (réception de carburant) est réservé au Chef Soutien Technique ;
-- le soutien pétrolier (rôle "ST") ne fait que des distributions.
drop policy if exists "depotage ecriture" on logistique.depotage;
create policy "depotage ecriture" on logistique.depotage
  for all using (socle.current_user_role() = 'chef_soutien_technique');
