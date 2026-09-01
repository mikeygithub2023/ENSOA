-- ============================================================================
-- SCOLARITÉ (ENSOA GSES) — repris de 055_note_sportive_materialisee.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- Migration : la note d'une épreuve sportive rejoint la table `notes`.
--
-- La migration 052 sait CALCULER la note d'un apprenant à une épreuve
-- (`note_epreuve`), mais ce résultat ne vivait nulle part : il fallait
-- appeler la fonction pour le connaître. Or tout ce qui fait une moyenne
-- dans l'application — la note d'un module, le bulletin, les statistiques
-- de la phase — lit `notes`, et rien d'autre. Un module Sport serait donc
-- resté « non classé » partout, quelles que soient les performances
-- enregistrées.
--
-- Plutôt que d'apprendre le sport à chacun de ces calculs, on matérialise :
-- dès qu'une performance ou un barème change, la note correspondante est
-- écrite dans `notes` comme n'importe quelle autre. Le reste de
-- l'application continue d'ignorer que le sport existe.
--
-- La note reste néanmoins calculée, jamais saisie : elle est réécrite à
-- chaque changement, et effacée quand elle n'est plus calculable (barème
-- absent pour ce sexe, sexe non renseigné, performance supprimée). Un
-- apprenant sans note à une épreuve n'y est pas classé — il n'y prend pas
-- zéro.

-- --- 1. La synchronisation d'une note --------------------------------------

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

  if v_note is null then
    delete from scolarite.notes
    where sous_module_id = p_sous_module_id
      and apprenant_id = p_apprenant_id;
    return;
  end if;

  -- `previous_note` reste vide : elle signale une note reprise à la main,
  -- ce qu'une note calculée n'est jamais. L'afficher comme « Note
  -- modifiée » à chaque recalcul du barème n'apprendrait rien.
  insert into scolarite.notes (
    controle_id,
    apprenant_id,
    sous_module_id,
    note
  )
  values (v_module_id, p_apprenant_id, p_sous_module_id, v_note)
  on conflict (apprenant_id, sous_module_id) where sous_module_id is not null
  do update set
    note = excluded.note,
    updated_at = now();
end;
$$;

revoke execute on function scolarite.sync_note_sportive(uuid, uuid) from public;

-- Toutes les notes d'une épreuve — après un changement de barème, chaque
-- performance déjà enregistrée vaut potentiellement une autre note.
create or replace function scolarite.resync_notes_epreuve(p_sous_module_id uuid)
returns void
language plpgsql
security definer
set search_path = scolarite, socle, public
as $$
declare
  v_apprenant uuid;
begin
  for v_apprenant in
    select apprenant_id
    from scolarite.performances_sportives
    where sous_module_id = p_sous_module_id
  loop
    perform scolarite.sync_note_sportive(p_sous_module_id, v_apprenant);
  end loop;
end;
$$;

revoke execute on function scolarite.resync_notes_epreuve(uuid) from public;

-- --- 2. Les déclencheurs ----------------------------------------------------

-- Une performance saisie, corrigée ou retirée.
create or replace function scolarite.trg_performance_sportive()
returns trigger
language plpgsql
security definer
set search_path = scolarite, socle, public
as $$
begin
  if tg_op = 'DELETE' then
    delete from scolarite.notes
    where sous_module_id = old.sous_module_id
      and apprenant_id = old.apprenant_id;
    return old;
  end if;

  -- Une performance déplacée d'une épreuve ou d'un apprenant à l'autre
  -- laisserait sinon une note orpheline derrière elle.
  if tg_op = 'UPDATE'
     and (old.sous_module_id is distinct from new.sous_module_id
          or old.apprenant_id is distinct from new.apprenant_id) then
    delete from scolarite.notes
    where sous_module_id = old.sous_module_id
      and apprenant_id = old.apprenant_id;
  end if;

  perform scolarite.sync_note_sportive(new.sous_module_id, new.apprenant_id);
  return new;
end;
$$;

drop trigger if exists sync_note_performance on scolarite.performances_sportives;
create trigger sync_note_performance
  after insert or update or delete on scolarite.performances_sportives
  for each row execute function scolarite.trg_performance_sportive();

-- Un palier de barème ajouté, corrigé ou retiré : toutes les notes de
-- l'épreuve sont à refaire.
create or replace function scolarite.trg_bareme_palier()
returns trigger
language plpgsql
security definer
set search_path = scolarite, socle, public
as $$
begin
  if tg_op = 'DELETE' then
    perform scolarite.resync_notes_epreuve(old.sous_module_id);
    return old;
  end if;

  if tg_op = 'UPDATE'
     and old.sous_module_id is distinct from new.sous_module_id then
    perform scolarite.resync_notes_epreuve(old.sous_module_id);
  end if;

  perform scolarite.resync_notes_epreuve(new.sous_module_id);
  return new;
end;
$$;

drop trigger if exists sync_notes_bareme on scolarite.bareme_paliers;
create trigger sync_notes_bareme
  after insert or update or delete on scolarite.bareme_paliers
  for each row execute function scolarite.trg_bareme_palier();

-- Le sexe de l'apprenant décide du barème qui s'applique : le corriger
-- change toutes ses notes sportives.
create or replace function scolarite.trg_apprenant_sexe()
returns trigger
language plpgsql
security definer
set search_path = scolarite, socle, public
as $$
declare
  v_epreuve uuid;
begin
  if old.sexe is not distinct from new.sexe then
    return new;
  end if;

  for v_epreuve in
    select sous_module_id
    from scolarite.performances_sportives
    where apprenant_id = new.id
  loop
    perform scolarite.sync_note_sportive(v_epreuve, new.id);
  end loop;

  return new;
end;
$$;

drop trigger if exists sync_notes_sexe on scolarite.apprenants;
create trigger sync_notes_sexe
  after update of sexe on scolarite.apprenants
  for each row execute function scolarite.trg_apprenant_sexe();

-- --- 3. Reprise de l'existant ----------------------------------------------
-- Les performances déjà saisies n'ont jamais produit de note : on les
-- rattrape ici, une fois.

do $$
declare
  v_performance record;
begin
  for v_performance in
    select sous_module_id, apprenant_id from scolarite.performances_sportives
  loop
    perform scolarite.sync_note_sportive(
      v_performance.sous_module_id,
      v_performance.apprenant_id
    );
  end loop;
end;
$$;
