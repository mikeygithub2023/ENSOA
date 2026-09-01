-- ============================================================================
-- SCOLARITÉ (ENSOA GSES) — repris de 036_cours_ouverts_et_qcm.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- Migration : deux évolutions du module Cours.
--
-- 1. Le dépôt s'ouvre à tous les acteurs, plus seulement à l'encadrement :
--    un élève partage ses propres supports avec sa classe. Chacun dépose
--    dans ce qu'il voit — l'encadrement dans sa division, l'élève dans sa
--    classe — et ne modifie ou ne supprime que ce qu'il a lui-même déposé,
--    l'encadrement gardant la main sur tout ce qui relève de sa division.
--    Sans cette dernière réserve, n'importe quel élève effacerait le cours
--    d'un camarade.
--
-- 2. Un devoir devient un QCM : une suite de questions, chacune avec ses
--    propositions de réponse, dont une seule est la bonne.
--
--    Barème, fixé par l'école : +1 point par bonne réponse, −1 par mauvaise,
--    0 pour une question laissée sans réponse — s'abstenir n'est pas se
--    tromper. La note d'un devoir est donc sur autant de points qu'il compte
--    de questions.
--
--    `qcm_propositions_une_seule_correcte` fait respecter l'unicité de la
--    bonne réponse au niveau de la base : le barème ci-dessus n'a de sens
--    que si chaque question en a exactement une.

drop policy if exists cours_write_admin on scolarite.cours;
drop policy if exists cours_write_division_staff on scolarite.cours;

create policy cours_insert on scolarite.cours
  for insert to authenticated
  with check (
    socle.current_role() in ('admin', 'medecin')
    or (
      socle.current_role() in ('chef_division', 'instructeur')
      and division_id = socle.current_division()
    )
    or exists (
      select 1 from scolarite.apprenants a
      where a.profile_id = auth.uid()
        and a.classe_id = cours.classe_id
    )
  );

create policy cours_update on scolarite.cours
  for update to authenticated
  using (
    socle.current_role() = 'admin'
    or (
      socle.current_role() in ('chef_division', 'instructeur')
      and division_id = socle.current_division()
    )
    or created_by = auth.uid()
  );

create policy cours_delete on scolarite.cours
  for delete to authenticated
  using (
    socle.current_role() = 'admin'
    or (
      socle.current_role() in ('chef_division', 'instructeur')
      and division_id = socle.current_division()
    )
    or created_by = auth.uid()
  );

-- Les questions d'un devoir. `ordre` fixe la présentation : un QCM se lit
-- dans l'ordre où son auteur l'a composé, pas dans celui de la base.
create table scolarite.qcm_questions (
  id uuid primary key default gen_random_uuid(),
  devoir_id uuid not null references scolarite.cours (id) on delete cascade,
  ordre integer not null default 0,
  enonce text not null,
  created_at timestamptz not null default now()
);

create index qcm_questions_devoir_idx on scolarite.qcm_questions (devoir_id, ordre);

create table scolarite.qcm_propositions (
  id uuid primary key default gen_random_uuid(),
  question_id uuid not null references scolarite.qcm_questions (id) on delete cascade,
  ordre integer not null default 0,
  texte text not null,
  correcte boolean not null default false
);

create index qcm_propositions_question_idx
  on scolarite.qcm_propositions (question_id, ordre);

-- Une seule bonne réponse par question.
create unique index qcm_propositions_une_seule_correcte
  on scolarite.qcm_propositions (question_id)
  where correcte;

alter table scolarite.qcm_questions enable row level security;
alter table scolarite.qcm_propositions enable row level security;

-- Les questions et les propositions suivent le devoir : qui voit celui-ci
-- voit celles-là, qui peut le modifier peut les modifier. Inutile de
-- redire les règles de `cours`, il suffit de s'y adosser.
create policy qcm_questions_all on scolarite.qcm_questions
  for all to authenticated
  using (
    exists (select 1 from scolarite.cours c where c.id = qcm_questions.devoir_id)
  )
  with check (
    exists (select 1 from scolarite.cours c where c.id = qcm_questions.devoir_id)
  );

create policy qcm_propositions_all on scolarite.qcm_propositions
  for all to authenticated
  using (
    exists (
      select 1 from scolarite.qcm_questions q
      where q.id = qcm_propositions.question_id
    )
  )
  with check (
    exists (
      select 1 from scolarite.qcm_questions q
      where q.id = qcm_propositions.question_id
    )
  );

create trigger audit_qcm_questions
  after insert or update or delete on scolarite.qcm_questions
  for each row execute function socle.audit_trigger();

grant select, insert, update, delete
  on scolarite.qcm_questions, scolarite.qcm_propositions to authenticated;
