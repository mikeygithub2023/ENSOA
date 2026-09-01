-- ============================================================================
-- SCOLARITÉ (ENSOA GSES) — repris de 043_resultats_eleve.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- Migration : les résultats scolaires vus par l'élève.
--
-- Ni sa moyenne ni son rang ne peuvent être calculés depuis son téléphone :
--   * le rang suppose de comparer sa moyenne à celles de ses camarades, que
--     l'élève n'a pas le droit de lire — et ne doit pas avoir ;
--   * les coefficients des matières (`matiere_modules`) sont réservés à
--     l'encadrement.
--
-- Deux fonctions `security definer` font donc le calcul côté base et ne
-- rendent que ce qui concerne l'appelant : ses notes, sa moyenne, son rang,
-- et les moyennes de promotion — des agrégats, jamais la note d'un
-- camarade.
--
-- La règle de calcul est celle du bulletin (voir `moyennes.dart`) : un
-- module porte une note directe, un contrôle continu ou un examen agrège ses
-- notes par matière au prorata des coefficients, et une évaluation sans note
-- laisse l'apprenant « non classé » — jamais un zéro.

-- Note d'un apprenant à une évaluation, ou NULL s'il n'y est pas classé.
create function scolarite.note_au_controle(p_apprenant uuid, p_controle uuid)
returns numeric
language sql
stable
security definer
set search_path = scolarite, socle, public
as $$
  select case
    when (select c.type from scolarite.controles c where c.id = p_controle) = 'module'
      then (
        select n.note from scolarite.notes n
        where n.controle_id = p_controle and n.apprenant_id = p_apprenant
        limit 1
      )
    else (
      select sum(n.note * coalesce(mm.coefficient, 1))
           / nullif(sum(coalesce(mm.coefficient, 1)), 0)
      from scolarite.notes n
      left join scolarite.matiere_modules mm
        on mm.matiere_id = n.matiere_id
       and mm.classe_id = (
             select c.classe_id from scolarite.controles c where c.id = p_controle
           )
      where n.controle_id = p_controle and n.apprenant_id = p_apprenant
    )
  end;
$$;

-- Moyenne générale d'un apprenant : les évaluations où il est classé,
-- pondérées par leur coefficient.
create function scolarite.moyenne_apprenant(p_apprenant uuid)
returns numeric
language sql
stable
security definer
set search_path = scolarite, socle, public
as $$
  with lignes as (
    select c.coefficient, scolarite.note_au_controle(p_apprenant, c.id) as note
    from scolarite.controles c
    where c.classe_id = (
      select a.classe_id from scolarite.apprenants a where a.id = p_apprenant
    )
  )
  select sum(note * coefficient) / nullif(sum(coefficient), 0)
  from lignes
  where note is not null;
$$;

-- Le relevé de l'élève : une ligne par évaluation, sa note en regard de la
-- moyenne de sa promotion.
create function scolarite.mes_resultats()
returns table (
  evaluation uuid,
  intitule text,
  nature text,
  poids numeric,
  ma_note numeric,
  moyenne_promotion numeric,
  nombre_classes integer
)
language sql
security definer
set search_path = scolarite, socle, public
as $$
  with moi as (
    select a.id, a.classe_id
    from scolarite.apprenants a
    where a.profile_id = auth.uid()
  ),
  camarades as (
    select a.id from scolarite.apprenants a
    join moi on a.classe_id = moi.classe_id
  )
  select
    c.id,
    c.libelle,
    c.type,
    c.coefficient,
    scolarite.note_au_controle((select id from moi), c.id),
    (
      select avg(scolarite.note_au_controle(cam.id, c.id))
      from camarades cam
      where scolarite.note_au_controle(cam.id, c.id) is not null
    ),
    (
      select count(*)::integer
      from camarades cam
      where scolarite.note_au_controle(cam.id, c.id) is not null
    )
  from scolarite.controles c
  join moi on c.classe_id = moi.classe_id
  order by c.created_at desc;
$$;

grant execute on function scolarite.mes_resultats() to authenticated;

-- Sa place dans la promotion. Seuls les apprenants effectivement classés
-- comptent : un camarade sans aucune note n'est ni devant ni derrière.
create function scolarite.mon_classement()
returns table (
  ma_moyenne numeric,
  moyenne_promotion numeric,
  rang integer,
  effectif_classe integer
)
language sql
security definer
set search_path = scolarite, socle, public
as $$
  with moi as (
    select a.id, a.classe_id
    from scolarite.apprenants a
    where a.profile_id = auth.uid()
  ),
  moyennes as (
    select a.id, scolarite.moyenne_apprenant(a.id) as moyenne
    from scolarite.apprenants a
    join moi on a.classe_id = moi.classe_id
  ),
  classes as (
    select * from moyennes where moyenne is not null
  )
  select
    (select moyenne from moyennes where id = (select id from moi)),
    (select avg(moyenne) from classes),
    (
      select count(*)::integer + 1
      from classes
      where moyenne > (select moyenne from moyennes where id = (select id from moi))
    ),
    (select count(*)::integer from classes);
$$;

grant execute on function scolarite.mon_classement() to authenticated;
