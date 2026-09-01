-- ============================================================================
-- SCOLARITÉ (ENSOA GSES) — repris de 041_qcm_note_reservee.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- Migration : la note d'un QCM ne revient plus à l'élève.
--
-- Un élève qui connaît sa note peut la rapprocher de ses réponses et en
-- déduire lesquelles étaient justes — puis les transmettre à ses camarades
-- qui n'ont pas encore composé. Masquer la note dans l'application ne
-- suffirait pas : il suffirait d'observer les échanges réseau. Elle ne doit
-- donc jamais lui parvenir.
--
-- L'élève garde le droit de savoir qu'il a composé, et quand : c'est ce
-- qu'il lui faut pour ne pas recommencer, et rien de plus.
--
-- Le personnel, lui, voit tout : c'est l'objet de l'écran « Résultats ».

-- La copie n'est plus lisible que par l'encadrement.
drop policy if exists qcm_participations_select on scolarite.qcm_participations;

create policy qcm_participations_select_encadrement
  on scolarite.qcm_participations
  for select to authenticated
  using (
    socle.current_role() = 'admin'
    or (
      socle.current_role() in ('chef_division', 'instructeur')
      and exists (
        select 1 from scolarite.apprenants a
        where a.id = qcm_participations.apprenant_id
          and a.division_id = socle.current_division()
      )
    )
  );

-- Les réponses suivent : la policy s'adosse aux participations visibles, qui
-- ne le sont plus pour l'élève.

-- Ce que l'élève peut savoir de ses propres compositions : lesquelles, et
-- quand. Pas la note.
create function scolarite.qcm_mes_compositions()
returns table (devoir_id uuid, terminee_at timestamptz)
language sql
security definer
set search_path = scolarite, socle, public
as $$
  select p.devoir_id, p.terminee_at
  from scolarite.qcm_participations p
  join scolarite.apprenants a on a.id = p.apprenant_id
  where a.profile_id = auth.uid();
$$;

grant execute on function scolarite.qcm_mes_compositions() to authenticated;

-- La remise ne renvoie plus la note : elle confirme seulement que la copie
-- est enregistrée.
drop function if exists scolarite.qcm_remettre(uuid, uuid[]);

create function scolarite.qcm_remettre(
  p_devoir_id uuid,
  p_propositions uuid[]
)
returns void
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
  -- proposition étrangère à ce devoir est ignorée.
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
end;
$$;

grant execute on function scolarite.qcm_remettre(uuid, uuid[]) to authenticated;
