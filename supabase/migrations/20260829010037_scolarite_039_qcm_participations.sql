-- ============================================================================
-- SCOLARITÉ (ENSOA GSES) — repris de 039_qcm_participations.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- Migration : composition des QCM par les élèves et calcul des notes.
--
-- Barème de l'école, appliqué à chaque proposition cochée : bonne réponse
-- +1, mauvaise −1, proposition laissée de côté 0. Une question vaut donc
-- autant de points qu'elle compte de bonnes réponses, et la note d'un
-- devoir — la somme de ces maxima — peut être négative.
--
-- Deux partis pris tiennent tout le reste :
--
-- 1. L'élève ne doit jamais pouvoir lire `qcm_propositions.correcte` : il
--    connaîtrait les réponses avant de composer, et l'application n'y
--    pourrait rien — il suffirait d'observer les échanges réseau. La table
--    est donc fermée aux élèves, et le sujet leur est servi par une
--    fonction qui en retire la colonne.
--
-- 2. La note n'est jamais calculée ni transmise par le client : elle est
--    établie côté base au moment de la remise, à partir des propositions
--    cochées. Un élève ne peut pas s'attribuer une note.

create table scolarite.qcm_participations (
  id uuid primary key default gen_random_uuid(),
  devoir_id uuid not null references scolarite.cours (id) on delete cascade,
  apprenant_id uuid not null references scolarite.apprenants (id) on delete cascade,
  note integer,
  bareme integer,
  terminee_at timestamptz,
  created_at timestamptz not null default now(),
  -- Une seule composition par élève et par devoir : on ne repasse pas un
  -- QCM pour améliorer sa note.
  unique (devoir_id, apprenant_id)
);

create index qcm_participations_devoir_idx
  on scolarite.qcm_participations (devoir_id);

create table scolarite.qcm_reponses (
  id uuid primary key default gen_random_uuid(),
  participation_id uuid not null
    references scolarite.qcm_participations (id) on delete cascade,
  proposition_id uuid not null
    references scolarite.qcm_propositions (id) on delete cascade,
  unique (participation_id, proposition_id)
);

alter table scolarite.qcm_participations enable row level security;
alter table scolarite.qcm_reponses enable row level security;

-- L'élève voit sa propre copie ; l'encadrement voit celles de sa division.
create policy qcm_participations_select on scolarite.qcm_participations
  for select to authenticated
  using (
    exists (
      select 1 from scolarite.apprenants a
      where a.id = qcm_participations.apprenant_id
        and (
          a.profile_id = auth.uid()
          or socle.current_role() = 'admin'
          or (
            socle.current_role() in ('chef_division', 'instructeur')
            and a.division_id = socle.current_division()
          )
        )
    )
  );

create policy qcm_reponses_select on scolarite.qcm_reponses
  for select to authenticated
  using (
    exists (
      select 1 from scolarite.qcm_participations p
      where p.id = qcm_reponses.participation_id
    )
  );

-- Aucune politique d'écriture : les copies ne sont créées que par la
-- fonction de remise ci-dessous, qui seule sait calculer la note.

grant select on scolarite.qcm_participations, scolarite.qcm_reponses to authenticated;

-- Les propositions se ferment aux élèves : elles portent la réponse.
drop policy if exists qcm_propositions_all on scolarite.qcm_propositions;

create policy qcm_propositions_encadrement on scolarite.qcm_propositions
  for all to authenticated
  using (socle.current_role() <> 'eleve_stagiaire')
  with check (socle.current_role() <> 'eleve_stagiaire');

-- Le sujet tel que l'élève le reçoit : les questions et leurs propositions,
-- sans la colonne qui dit laquelle est juste.
create function scolarite.qcm_sujet(p_devoir_id uuid)
returns table (
  question_id uuid,
  question_ordre integer,
  enonce text,
  proposition_id uuid,
  proposition_ordre integer,
  texte text
)
language sql
security definer
set search_path = scolarite, socle, public
as $$
  select q.id, q.ordre, q.enonce, p.id, p.ordre, p.texte
  from scolarite.qcm_questions q
  join scolarite.qcm_propositions p on p.question_id = q.id
  where q.devoir_id = p_devoir_id
    -- Le devoir doit être celui de la classe/stage de l'appelant : la
    -- fonction contourne RLS, c'est donc ici que le cloisonnement se fait.
    and exists (
      select 1
      from scolarite.cours c
      join scolarite.apprenants a on a.classe_id = c.classe_id
      where c.id = p_devoir_id
        and a.profile_id = auth.uid()
    )
  order by q.ordre, p.ordre;
$$;

grant execute on function scolarite.qcm_sujet(uuid) to authenticated;

-- Remise de la copie : l'élève envoie les propositions qu'il a cochées, la
-- base établit la note. Rien de ce que le client envoie n'influe sur le
-- barème.
create function scolarite.qcm_remettre(
  p_devoir_id uuid,
  p_propositions uuid[]
)
returns table (note integer, bareme integer)
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
  -- proposition qui n'appartient pas à ce devoir est ignorée : elle ne peut
  -- ni rapporter ni coûter.
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

create trigger audit_qcm_participations
  after insert or update or delete on scolarite.qcm_participations
  for each row execute function socle.audit_trigger();
