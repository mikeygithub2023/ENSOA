-- ============================================================================
-- SCOLARITÉ (ENSOA GSES) — repris de 060_bareme_par_paliers.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- Migration : le barème se lit par paliers, non par interpolation.
--
-- La migration 052 traitait les paliers comme les points d'une droite et
-- interpolait entre eux : à mi-chemin de 24′→20 et 30′→12, un coureur
-- obtenait 16. Ce n'est pas ainsi que se lit un barème militaire. Un barème
-- énonce des seuils :
--
--     moins de 24 min → 20
--     moins de 26 min → 18
--     moins de 28 min → 16
--     moins de 30 min → 12
--
-- 25′30″ vaut donc 18 — la note du premier seuil que la performance passe —
-- et non 19 ou 17. La note ne varie pas à l'intérieur d'un intervalle :
-- c'est tout l'intérêt d'un palier.
--
-- La colonne `performance` de `bareme_paliers` change donc de sens : elle
-- ne désigne plus un point de référence mais un SEUIL, lu selon le sens de
-- l'activité —
--
--   `minimum` (un temps) : la note du plus petit seuil que la performance
--                          passe, soit performance < seuil ;
--   `maximum` (des répétitions, une distance) : la note du plus grand seuil
--                          atteint, soit performance >= seuil.
--
-- Hors barème — plus lent que le dernier seuil, ou en deçà du premier — la
-- fonction rend `null` plutôt que d'inventer un zéro. L'apprenant n'est
-- alors pas classé à cette séance, et l'écran le signale : c'est au barème
-- d'être complété, pas au calcul de trancher à la place de l'école.

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
    -- Un temps : on cherche le seuil le plus serré que la performance
    -- passe encore. « Moins de 26 min » est passé par 25′30″, « moins de
    -- 24 » ne l'est pas : la note est celle du seuil 26.
    select note into v_note
    from scolarite.bareme_paliers
    where activite_id = p_activite_id
      and sexe = p_sexe
      and p_performance < performance
    order by performance asc
    limit 1;
  else
    -- Des répétitions, une distance : on cherche le seuil le plus exigeant
    -- que la performance atteigne.
    select note into v_note
    from scolarite.bareme_paliers
    where activite_id = p_activite_id
      and sexe = p_sexe
      and p_performance >= performance
    order by performance desc
    limit 1;
  end if;

  return v_note;
end;
$$;

-- Les notes déjà calculées l'ont été par interpolation : elles ne valent
-- plus. On les refait toutes, barème par barème.
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
