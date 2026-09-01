-- ============================================================================
-- SCOLARITÉ (ENSOA GSES) — repris de 022_volet_sante.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- Migration : volet santé — distingue les consultations de routine (déjà
-- gérées) des consultations d'urgence (le médecin les crée directement,
-- sans autorisation préalable, et peut les clore dans la foulée), ajoute
-- les examens demandés en texte libre, et introduit la gestion des
-- médicaments (catalogue + stock unique pour toute l'école, "le point")
-- prescrits lors d'une consultation.

alter table scolarite.consultations_medicales
  add column type text not null default 'routine' check (type in ('routine', 'urgence'));

alter table scolarite.consultations_medicales
  add column examens_demandes text;

-- Catalogue des médicaments avec un stock unique pour toute l'école — géré
-- par l'administrateur et le médecin.
create table scolarite.medicaments (
  id uuid primary key default gen_random_uuid(),
  nom text not null,
  unite text,
  stock integer not null default 0 check (stock >= 0),
  created_at timestamptz not null default now(),
  unique (nom)
);

alter table scolarite.medicaments enable row level security;

create policy medicaments_all_admin_medecin on scolarite.medicaments
  for all to authenticated
  using (socle.current_role() in ('admin', 'medecin'))
  with check (socle.current_role() in ('admin', 'medecin'));

create trigger audit_medicaments
  after insert or update or delete on scolarite.medicaments
  for each row execute function socle.audit_trigger();

grant select, insert, update, delete on scolarite.medicaments to authenticated;

-- Ligne d'ordonnance : un médicament prescrit lors d'une consultation.
create table scolarite.ordonnance_lignes (
  id uuid primary key default gen_random_uuid(),
  consultation_id uuid not null references scolarite.consultations_medicales (id) on delete cascade,
  medicament_id uuid not null references scolarite.medicaments (id),
  quantite integer not null check (quantite > 0),
  posologie text,
  created_at timestamptz not null default now()
);

create index ordonnance_lignes_consultation_idx on scolarite.ordonnance_lignes (consultation_id);

alter table scolarite.ordonnance_lignes enable row level security;

create policy ordonnance_lignes_all_admin_medecin on scolarite.ordonnance_lignes
  for all to authenticated
  using (socle.current_role() in ('admin', 'medecin'))
  with check (socle.current_role() in ('admin', 'medecin'));

-- L'apprenant concerné peut voir ses propres lignes d'ordonnance, comme
-- pour la consultation elle-même.
create policy ordonnance_lignes_select_self on scolarite.ordonnance_lignes
  for select to authenticated
  using (
    exists (
      select 1 from scolarite.consultations_medicales c
      join scolarite.apprenants a on a.id = c.apprenant_id
      where c.id = ordonnance_lignes.consultation_id
        and a.profile_id = auth.uid()
    )
  );

create trigger audit_ordonnance_lignes
  after insert or update or delete on scolarite.ordonnance_lignes
  for each row execute function socle.audit_trigger();

grant select, insert, update, delete on scolarite.ordonnance_lignes to authenticated;

-- Décompte automatique du stock du médicament quand une ligne
-- d'ordonnance est ajoutée ("défalqué du point") ; restitution si la
-- ligne est supprimée (ex. le médecin annule une prescription). Un
-- decompte qui ferait passer le stock sous zéro échoue la transaction.
create function scolarite.apply_ordonnance_stock_delta()
returns trigger
language plpgsql
security definer
set search_path = scolarite, socle, public
as $$
begin
  if tg_op = 'INSERT' then
    update scolarite.medicaments set stock = stock - new.quantite where id = new.medicament_id;
    if (select stock from scolarite.medicaments where id = new.medicament_id) < 0 then
      raise exception 'Stock insuffisant pour ce médicament';
    end if;
    return new;
  elsif tg_op = 'DELETE' then
    update scolarite.medicaments set stock = stock + old.quantite where id = old.medicament_id;
    return old;
  end if;
  return null;
end;
$$;

create trigger ordonnance_lignes_stock_insert
  after insert on scolarite.ordonnance_lignes
  for each row execute function scolarite.apply_ordonnance_stock_delta();

create trigger ordonnance_lignes_stock_delete
  after delete on scolarite.ordonnance_lignes
  for each row execute function scolarite.apply_ordonnance_stock_delta();
