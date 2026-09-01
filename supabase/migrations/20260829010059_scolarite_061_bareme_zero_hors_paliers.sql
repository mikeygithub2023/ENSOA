-- ============================================================================
-- SCOLARITÉ (ENSOA GSES) — repris de 061_bareme_zero_hors_paliers.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- Migration : en deçà du dernier palier, la note est zéro.
--
-- La migration 060 rendait `null` pour une performance qui ne passait aucun
-- seuil, et l'écran affichait « hors barème ». C'était une échappatoire :
-- un apprenant plus lent que le dernier palier a bien couru, il a bien été
-- évalué, et ne pas le classer revenait à l'écarter de la moyenne — donc à
-- le favoriser. Un barème qui s'arrête à « moins de 30 min » dit
-- implicitement que 31 minutes ne valent rien : c'est zéro, pas une
-- absence de note.
--
-- À l'autre bout, rien ne change et rien n'a besoin de changer : une
-- performance meilleure que le seuil le plus serré passe ce seuil et reçoit
-- sa note — 20 dans un barème qui plafonne à 20.
--
-- Reste un cas où `null` garde tout son sens : quand l'activité n'a AUCUN
-- palier pour ce sexe. Là, rien n'a été barémé, et donner zéro
-- sanctionnerait l'apprenant d'un oubli de paramétrage. Il reste non
-- classé, et l'écran le signale pour qu'on complète le barème.

create or replace function scolarite.note_sportive(
  p_activite_id uuid,
  p_sexe text,
  p_performance numeric
)
returns numeric
language plpgsql
stable
security definer
set search_path = scolarite, socle, public
as $$
declare
  v_meilleur text;
  v_note numeric;
  v_paliers integer;
begin
  if p_sexe is null or p_performance is null then
    return null;
  end if;

  select meilleur into v_meilleur
  from scolarite.activites_sportives
  where id = p_activite_id;

  if v_meilleur is null then
    return null;
  end if;

  if v_meilleur = 'minimum' then
    -- Un temps : le seuil le plus serré que la performance passe encore.
    select note into v_note
    from scolarite.bareme_paliers
    where activite_id = p_activite_id
      and sexe = p_sexe
      and p_performance < performance
    order by performance asc
    limit 1;
  else
    -- Des répétitions, une distance : le seuil le plus exigeant atteint.
    select note into v_note
    from scolarite.bareme_paliers
    where activite_id = p_activite_id
      and sexe = p_sexe
      and p_performance >= performance
    order by performance desc
    limit 1;
  end if;

  if v_note is not null then
    return v_note;
  end if;

  -- Aucun seuil passé. Deux causes très différentes : pas de barème du
  -- tout, ou une performance en deçà du dernier palier.
  select count(*) into v_paliers
  from scolarite.bareme_paliers
  where activite_id = p_activite_id and sexe = p_sexe;

  if v_paliers = 0 then
    return null;
  end if;

  return 0;
end;
$$;

-- Les notes calculées sous l'ancienne règle sont à refaire : celles qui
-- manquaient faute de seuil passé valent désormais zéro.
do $$
declare
  v_activite uuid;
begin
  for v_activite in select id from scolarite.activites_sportives
  loop
    perform scolarite.resync_notes_activite(v_activite);
  end loop;
end;
$$;
