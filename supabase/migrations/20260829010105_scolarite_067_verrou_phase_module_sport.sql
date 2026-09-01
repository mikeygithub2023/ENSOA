-- ============================================================================
-- SCOLARITÉ (ENSOA GSES) — repris de 067_verrou_phase_module_sport.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- Migration : le verrou de phase ne doit pas empêcher de créer la phase.
--
-- La migration 066 interdit toute écriture dans une phase close ou
-- verrouillée. Elle interdisait du même coup la création d'une deuxième
-- phase : insérer une phase déclenche la création de son module Sport
-- (migration 056), et cette phase-là est verrouillée par construction —
-- la précédente n'est pas encore clôturée. Ajouter une phase à une
-- promotion échouait donc, avec un message parlant du verrou alors qu'on
-- ne faisait que créer.
--
-- Le module Sport est une pièce de structure, pas une saisie : il naît et
-- meurt avec sa phase, personne ne le crée ni ne le supprime à la main. Le
-- verrouiller n'apportait aucune garantie — ce qui compte, ce sont ses
-- séances et les performances qu'on y consigne, déjà verrouillées de leur
-- côté.

create or replace function scolarite.trg_phase_ouverte_controle()
returns trigger
language plpgsql
security definer
set search_path = scolarite, socle, public
as $$
declare
  v_ligne record;
begin
  v_ligne := coalesce(new, old);

  -- Le module Sport suit sa phase et n'est jamais saisi : il échappe au
  -- verrou, sans quoi on ne pourrait plus créer de phase verrouillée.
  if v_ligne.type = 'sport' then
    return v_ligne;
  end if;

  perform scolarite.exiger_phase_ouverte(v_ligne.classe_id);
  return v_ligne;
end;
$$;

drop trigger if exists phase_ouverte on scolarite.controles;
create trigger phase_ouverte
  before insert or update or delete on scolarite.controles
  for each row execute function scolarite.trg_phase_ouverte_controle();
