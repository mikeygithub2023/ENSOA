-- ============================================================================
-- SCOLARITÉ (ENSOA GSES) — repris de 023_medicaments_pharmacie.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- Migration : la section Médicaments se comporte comme un vrai logiciel de
-- pharmacie — date de péremption + seuil d'alerte stock bas configurable
-- par médicament, et un journal des mouvements de stock (entrées/sorties)
-- qui devient la SEULE source de vérité pour le stock : `medicaments.stock`
-- n'est plus jamais modifié directement, seulement via l'insertion d'un
-- mouvement (déclenchant lui-même l'ajustement, voir le trigger plus bas).

alter table scolarite.medicaments add column date_peremption date;
alter table scolarite.medicaments
  add column seuil_alerte integer not null default 10 check (seuil_alerte >= 0);

create table scolarite.mouvements_stock (
  id uuid primary key default gen_random_uuid(),
  medicament_id uuid not null references scolarite.medicaments (id) on delete cascade,
  type text not null check (type in ('entree', 'sortie')),
  quantite integer not null check (quantite > 0),
  motif text not null,
  consultation_id uuid references scolarite.consultations_medicales (id) on delete set null,
  auteur_id uuid references socle.profiles (id),
  created_at timestamptz not null default now()
);

create index mouvements_stock_medicament_idx on scolarite.mouvements_stock (medicament_id);

alter table scolarite.mouvements_stock enable row level security;

create policy mouvements_stock_all_admin_medecin on scolarite.mouvements_stock
  for all to authenticated
  using (socle.current_role() in ('admin', 'medecin'))
  with check (socle.current_role() in ('admin', 'medecin'));

create trigger audit_mouvements_stock
  after insert or update or delete on scolarite.mouvements_stock
  for each row execute function socle.audit_trigger();

grant select, insert, update, delete on scolarite.mouvements_stock to authenticated;

-- Applique le mouvement au stock du médicament dès son insertion — c'est
-- l'unique point d'ajustement du stock désormais.
create function scolarite.apply_stock_movement()
returns trigger
language plpgsql
security definer
set search_path = scolarite, socle, public
as $$
begin
  if new.type = 'entree' then
    update scolarite.medicaments set stock = stock + new.quantite where id = new.medicament_id;
  else
    update scolarite.medicaments set stock = stock - new.quantite where id = new.medicament_id;
    if (select stock from scolarite.medicaments where id = new.medicament_id) < 0 then
      raise exception 'Stock insuffisant pour ce médicament';
    end if;
  end if;
  return new;
end;
$$;

create trigger mouvements_stock_apply
  after insert on scolarite.mouvements_stock
  for each row execute function scolarite.apply_stock_movement();

-- Les triggers de la migration 022 modifiaient directement medicaments.stock
-- à chaque ordonnance — ils enregistrent désormais un mouvement à la place,
-- qui déclenche à son tour l'ajustement ci-dessus (traçabilité complète,
-- y compris pour les prescriptions).
drop trigger if exists ordonnance_lignes_stock_insert on scolarite.ordonnance_lignes;
drop trigger if exists ordonnance_lignes_stock_delete on scolarite.ordonnance_lignes;
drop function if exists scolarite.apply_ordonnance_stock_delta();

create function scolarite.record_ordonnance_mouvement()
returns trigger
language plpgsql
security definer
set search_path = scolarite, socle, public
as $$
begin
  if tg_op = 'INSERT' then
    insert into scolarite.mouvements_stock (medicament_id, type, quantite, motif, consultation_id, auteur_id)
    values (new.medicament_id, 'sortie', new.quantite, 'Prescription', new.consultation_id, auth.uid());
    return new;
  elsif tg_op = 'DELETE' then
    insert into scolarite.mouvements_stock (medicament_id, type, quantite, motif, consultation_id, auteur_id)
    values (old.medicament_id, 'entree', old.quantite, 'Annulation de prescription', old.consultation_id, auth.uid());
    return old;
  end if;
  return null;
end;
$$;

create trigger ordonnance_lignes_record_mouvement_insert
  after insert on scolarite.ordonnance_lignes
  for each row execute function scolarite.record_ordonnance_mouvement();

create trigger ordonnance_lignes_record_mouvement_delete
  after delete on scolarite.ordonnance_lignes
  for each row execute function scolarite.record_ordonnance_mouvement();
