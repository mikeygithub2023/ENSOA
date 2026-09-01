-- ============================================================================
-- SCOLARITÉ (ENSOA GSES) — repris de 040_qcm_remettre_correction.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- Migration : corrige la remise d'une copie de QCM.
--
-- `qcm_remettre` déclarait ses colonnes de sortie `note` et `bareme` — les
-- noms mêmes des colonnes de `qcm_participations` qu'elle renseigne. En
-- PL/pgSQL, les paramètres de sortie sont des variables en portée : dans
-- l'insertion, Postgres ne savait plus si `note` désignait la variable ou la
-- colonne, et refusait la requête pour ambiguïté. L'élève ne pouvait donc
-- pas valider son devoir.
--
-- Les colonnes de sortie prennent des noms qui n'existent nulle part
-- ailleurs. Le corps de la fonction est repris à l'identique.

drop function if exists scolarite.qcm_remettre(uuid, uuid[]);

create function scolarite.qcm_remettre(
  p_devoir_id uuid,
  p_propositions uuid[]
)
returns table (note_obtenue integer, bareme_total integer)
language plpgsql
security definer
set search_path = scolarite, socle, public
as $$
declare
  v_apprenant_id uuid;
  v_participation_id uuid;
  v_note integer;
  v_bareme integer;
begin
  select a.id into v_apprenant_id
  from scolarite.apprenants a
  join scolarite.cours c on c.classe_id = a.classe_id
  where a.profile_id = auth.uid() and c.id = p_devoir_id;

  if v_apprenant_id is null then
    raise exception 'Ce devoir ne vous est pas destiné.';
  end if;

  if exists (
    select 1 from scolarite.qcm_participations
    where devoir_id = p_devoir_id and apprenant_id = v_apprenant_id
  ) then
    raise exception 'Vous avez déjà composé ce devoir.';
  end if;

  -- Points maximum : une bonne réponse rapporte un point.
  select count(*) into v_bareme
  from scolarite.qcm_questions q
  join scolarite.qcm_propositions p on p.question_id = q.id
  where q.devoir_id = p_devoir_id and p.correcte;

  -- Chaque proposition cochée compte +1 si elle est juste, −1 sinon. Une
  -- proposition étrangère à ce devoir est ignorée : elle ne peut ni
  -- rapporter ni coûter.
  select coalesce(sum(case when p.correcte then 1 else -1 end), 0)
    into v_note
  from scolarite.qcm_propositions p
  join scolarite.qcm_questions q on q.id = p.question_id
  where q.devoir_id = p_devoir_id
    and p.id = any(p_propositions);

  insert into scolarite.qcm_participations (
    devoir_id, apprenant_id, note, bareme, terminee_at
  )
  values (p_devoir_id, v_apprenant_id, v_note, v_bareme, now())
  returning id into v_participation_id;

  insert into scolarite.qcm_reponses (participation_id, proposition_id)
  select v_participation_id, p.id
  from scolarite.qcm_propositions p
  join scolarite.qcm_questions q on q.id = p.question_id
  where q.devoir_id = p_devoir_id and p.id = any(p_propositions);

  return query select v_note, v_bareme;
end;
$$;

grant execute on function scolarite.qcm_remettre(uuid, uuid[]) to authenticated;
