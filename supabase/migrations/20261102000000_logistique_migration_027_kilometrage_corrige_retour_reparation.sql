-- ============================================================================
-- LOGISTIQUE (ERP ENSOA) — migration 027 : correction unique du kilométrage,
-- pannes décelées en réparation
--
-- Migration propre à l'application unifiée. À appliquer avec `supabase db
-- push`, ou collée dans l'éditeur SQL de Supabase.
-- ============================================================================

-- Le kilométrage suit les missions ; on ne le saisit pas. Mais une erreur de
-- saisie à l'enregistrement du véhicule doit pouvoir se corriger — une fois,
-- depuis la fiche. La date de cette correction marque qu'elle a eu lieu.
alter table logistique.vehicule
  add column if not exists kilometrage_corrige_le timestamptz;

-- Une correction faite ne se défait pas : sans ce garde-fou, il suffirait de
-- remettre la date à nul pour en obtenir une seconde.
create or replace function logistique.kilometrage_corrige_une_fois()
returns trigger
language plpgsql
as $$
begin
  if old.kilometrage_corrige_le is not null
     and new.kilometrage_corrige_le is distinct from old.kilometrage_corrige_le
  then
    raise exception 'Le kilométrage de ce véhicule a déjà été corrigé.';
  end if;
  return new;
end;
$$;

drop trigger if exists kilometrage_corrige_une_fois on logistique.vehicule;
create trigger kilometrage_corrige_une_fois
  before update of kilometrage_corrige_le on logistique.vehicule
  for each row execute function logistique.kilometrage_corrige_une_fois();

-- Une panne décelée pendant une réparation, et laissée en l'état, garde la
-- trace de la réparation qui l'a découverte.
alter table logistique.panne
  add column if not exists reparation_id bigint
  references logistique.reparation(id);
