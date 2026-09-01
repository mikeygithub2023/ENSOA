-- ============================================================================
-- SCOLARITÉ (ENSOA GSES) — repris de 062_note_sportive_modifiee.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- Migration : une note sportive qui change garde trace de sa valeur
-- précédente.
--
-- La migration 055 laissait `previous_note` vide pour les notes sportives,
-- au motif qu'une note calculée n'est pas une reprise à la main. C'était
-- regarder le mécanisme plutôt que l'usage : du point de vue de
-- l'encadrement, la note a bien changé, et savoir ce qu'elle valait avant
-- a exactement la même valeur de contrôle que pour une note saisie. Une
-- performance corrigée après coup doit se voir.
--
-- On aligne donc le sport sur le reste : à chaque recalcul qui change la
-- note — performance corrigée, barème repris, sexe rectifié — l'ancienne
-- valeur passe dans `previous_note`, et l'écran affiche « Note modifiée ».
--
-- Un recalcul qui retombe sur la même note ne touche à rien : ni horodatage
-- ni marque. Sans cela, reprendre un palier sans conséquence marquerait
-- toute une phase comme modifiée.

create or replace function scolarite.sync_note_sportive(
  p_sous_module_id uuid,
  p_apprenant_id uuid
)
returns void
language plpgsql
security definer
set search_path = scolarite, socle, public
as $$
declare
  v_module_id uuid;
  v_note numeric;
  v_ancienne record;
begin
  select sm.module_id into v_module_id
  from scolarite.sous_modules sm
  where sm.id = p_sous_module_id;

  -- Le sous-module a disparu (cascade en cours) : il n'y a plus de note à
  -- tenir à jour, et la note elle-même part avec lui.
  if v_module_id is null then
    return;
  end if;

  v_note := scolarite.note_epreuve(p_sous_module_id, p_apprenant_id);

  select id, note into v_ancienne
  from scolarite.notes
  where sous_module_id = p_sous_module_id
    and apprenant_id = p_apprenant_id;

  if v_note is null then
    delete from scolarite.notes
    where sous_module_id = p_sous_module_id
      and apprenant_id = p_apprenant_id;
    return;
  end if;

  if v_ancienne.id is null then
    insert into scolarite.notes (
      controle_id,
      apprenant_id,
      sous_module_id,
      note
    )
    values (v_module_id, p_apprenant_id, p_sous_module_id, v_note);
    return;
  end if;

  -- Même note : on ne touche à rien, pour ne pas marquer « modifiée » une
  -- note qui ne l'est pas.
  if v_ancienne.note is not distinct from v_note then
    return;
  end if;

  update scolarite.notes
  set note = v_note,
      previous_note = v_ancienne.note,
      updated_at = now()
  where id = v_ancienne.id;
end;
$$;

revoke execute on function scolarite.sync_note_sportive(uuid, uuid) from public;
