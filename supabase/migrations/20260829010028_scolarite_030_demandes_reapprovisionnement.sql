-- ============================================================================
-- SCOLARITÉ (ENSOA GSES) — repris de 030_demandes_reapprovisionnement.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- Migration : fiches de demande de réapprovisionnement de la pharmacie.
--
-- Le médecin coche les médicaments à commander et saisit les quantités ;
-- la validation enregistre la demande et ses lignes, puis la fiche est
-- imprimée pour le circuit papier.
--
-- Une demande ne touche pas au stock : elle exprime un besoin, elle ne
-- constate pas une entrée. Le stock ne bouge toujours qu'en réaction à un
-- `mouvements_stock` (voir la migration 023), au moment de la réception
-- effective.
--
-- `stock_au_moment_de_la_demande` fige le stock constaté à la saisie plutôt
-- que de le relire depuis `medicaments` : la fiche réimprimée des mois plus
-- tard doit montrer la situation qui a motivé la commande, pas celle du
-- jour où on la rouvre.

create table scolarite.demandes_reapprovisionnement (
  id uuid primary key default gen_random_uuid(),
  date_demande date not null default current_date,
  observations text,
  created_at timestamptz not null default now(),
  created_by uuid references socle.profiles (id) default auth.uid()
);

create index demandes_reapprovisionnement_date_idx
  on scolarite.demandes_reapprovisionnement (date_demande desc);

alter table scolarite.demandes_reapprovisionnement enable row level security;

create policy demandes_reapprovisionnement_all_admin_medecin
  on scolarite.demandes_reapprovisionnement
  for all to authenticated
  using (socle.current_role() in ('admin', 'medecin'))
  with check (socle.current_role() in ('admin', 'medecin'));

create trigger audit_demandes_reapprovisionnement
  after insert or update or delete on scolarite.demandes_reapprovisionnement
  for each row execute function socle.audit_trigger();

grant select, insert, update, delete
  on scolarite.demandes_reapprovisionnement to authenticated;

-- Une ligne par médicament demandé. `unique (demande_id, medicament_id)`
-- interdit de demander deux fois le même médicament sur une même fiche :
-- les quantités doivent être cumulées sur une seule ligne.
create table scolarite.demandes_reapprovisionnement_lignes (
  id uuid primary key default gen_random_uuid(),
  demande_id uuid not null
    references scolarite.demandes_reapprovisionnement (id) on delete cascade,
  medicament_id uuid not null references scolarite.medicaments (id),
  quantite_demandee integer not null check (quantite_demandee > 0),
  stock_au_moment_de_la_demande integer not null,
  unique (demande_id, medicament_id)
);

create index demandes_reapprovisionnement_lignes_demande_idx
  on scolarite.demandes_reapprovisionnement_lignes (demande_id);

alter table scolarite.demandes_reapprovisionnement_lignes enable row level security;

create policy demandes_reapprovisionnement_lignes_all_admin_medecin
  on scolarite.demandes_reapprovisionnement_lignes
  for all to authenticated
  using (socle.current_role() in ('admin', 'medecin'))
  with check (socle.current_role() in ('admin', 'medecin'));

create trigger audit_demandes_reapprovisionnement_lignes
  after insert or update or delete on scolarite.demandes_reapprovisionnement_lignes
  for each row execute function socle.audit_trigger();

grant select, insert, update, delete
  on scolarite.demandes_reapprovisionnement_lignes to authenticated;
