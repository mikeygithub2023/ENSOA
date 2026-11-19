-- La quatrième division, et le découpage des promotions en sections.
--
-- Deux manques, relevés le même jour sur l'écran des Ressources humaines.
--
-- ---------------------------------------------------------------------------
-- 1. La Division de Commandement et Logistique
--
-- L'école en compte quatre, le référentiel n'en portait que trois. Celle-ci
-- ne ressemble pas aux autres : elle n'a ni promotion ni stage, parce
-- qu'elle n'instruit personne — elle regroupe le personnel de l'école, de
-- son commandement à ses services.
--
-- Ce personnel reçoit la même fiche que les élèves, et pour la même raison :
-- la prise d'armes du matin compte toute l'école, cadres compris ; une
-- permission, une consultation, une absence se tiennent de la même façon
-- pour un adjudant que pour un élève. Plutôt qu'une seconde table qui
-- redirait la première en moins bien — et qu'il faudrait rebrancher sur
-- chacun des quatre registres —, le type d'apprenant s'ouvre à « personnel ».
--
-- Ce que ce personnel n'a pas : ni promotion, ni phase, ni section, ni
-- note. Il n'est pas en formation. La contrainte le dit, pour que personne
-- ne l'inscrive par mégarde à un cursus.
--
-- ---------------------------------------------------------------------------
-- 2. Les sections
--
-- Une promotion de deux cents élèves ne se commande pas d'un bloc : elle se
-- répartit en sections. La section s'attache à la **promotion**, pas à la
-- phase : l'élève entre en section et la garde du FCB jusqu'à sa sortie,
-- tandis que les phases se succèdent sous lui. C'est aussi ce que dit déjà
-- la migration 065 — la promotion rattache, la phase situe.
--
-- L'arbre devient :
--
--   division
--     ├── promotion
--     │     ├── phase      (où l'élève se trouve aujourd'hui)
--     │     └── section    (avec qui il sert, du premier au dernier jour)
--     └── stage
--
-- Un stage n'a pas de sections : il n'a pas non plus de promotion.
-- ===========================================================================


-- --- 1. La division ---------------------------------------------------------
insert into socle.divisions (code, nom, ordre)
values (
  'commandement_logistique',
  'Division de Commandement et Logistique',
  4
)
on conflict (code) do nothing;


-- --- 2. Le personnel --------------------------------------------------------
alter table scolarite.apprenants drop constraint if exists apprenants_type_check;

alter table scolarite.apprenants
  add constraint apprenants_type_check
  check (type in ('eleve', 'stagiaire', 'personnel'));


-- --- 3. Les sections --------------------------------------------------------
create table if not exists scolarite.sections (
  id uuid primary key default gen_random_uuid(),
  promotion_id uuid not null
    references scolarite.promotions (id) on delete cascade,
  nom text not null,
  -- Les sections se nomment « 1ère », « 2ème »… : le tri alphabétique les
  -- mettrait dans le désordre dès la dixième. L'ordre est donc explicite,
  -- comme pour les divisions.
  ordre integer not null default 0,
  created_at timestamptz not null default now(),
  unique (promotion_id, nom)
);

create index if not exists sections_promotion_idx
  on scolarite.sections (promotion_id);

alter table scolarite.sections enable row level security;

-- La section se lit comme sa promotion : portée globale pour
-- l'administrateur et le médecin, sa division pour les autres, sa promotion
-- pour le commandant qui la tient.
drop policy if exists sections_select on scolarite.sections;
create policy sections_select on scolarite.sections
  for select to authenticated
  using (
    socle.current_role() in ('admin', 'medecin')
    or exists (
      select 1 from scolarite.promotions p
      where p.id = sections.promotion_id
        and (
          p.division_id = socle.current_division()
          or p.id = socle.current_promotion()
        )
    )
  );

drop policy if exists sections_write_admin on scolarite.sections;
create policy sections_write_admin on scolarite.sections
  for all to authenticated
  using (socle.current_role() = 'admin')
  with check (socle.current_role() = 'admin');

drop policy if exists sections_write_chef_division on scolarite.sections;
create policy sections_write_chef_division on scolarite.sections
  for all to authenticated
  using (
    socle.current_role() = 'chef_division'
    and exists (
      select 1 from scolarite.promotions p
      where p.id = sections.promotion_id
        and p.division_id = socle.current_division()
    )
  )
  with check (
    socle.current_role() = 'chef_division'
    and exists (
      select 1 from scolarite.promotions p
      where p.id = sections.promotion_id
        and p.division_id = socle.current_division()
    )
  );

-- Répartir sa promotion en sections est le travail même du commandant de
-- promotion et du commandant de brigade : ils les créent et les tiennent,
-- sur la leur et sur elle seule.
drop policy if exists sections_write_commandant on scolarite.sections;
create policy sections_write_commandant on scolarite.sections
  for all to authenticated
  using (
    socle.current_role() in ('commandant_brigade', 'commandant_promotion')
    and sections.promotion_id = socle.current_promotion()
  )
  with check (
    socle.current_role() in ('commandant_brigade', 'commandant_promotion')
    and sections.promotion_id = socle.current_promotion()
  );

drop trigger if exists audit_sections on scolarite.sections;
create trigger audit_sections
  after insert or update or delete on scolarite.sections
  for each row execute function socle.audit_trigger();


-- --- 4. L'élève dans sa section ---------------------------------------------
-- `on delete set null` : supprimer une section ne supprime pas ses élèves.
-- Ils reviennent « sans section », et on les répartit à nouveau.
alter table scolarite.apprenants
  add column if not exists section_id uuid
    references scolarite.sections (id) on delete set null;

create index if not exists apprenants_section_idx
  on scolarite.apprenants (section_id);

-- Le personnel n'est pas en formation : ni phase, ni promotion, ni section.
-- Écrit en contrainte plutôt qu'en convention, pour qu'un import maladroit
-- ne puisse pas inscrire le commandant de l'école au FCB.
alter table scolarite.apprenants
  drop constraint if exists apprenants_personnel_hors_cursus;

alter table scolarite.apprenants
  add constraint apprenants_personnel_hors_cursus check (
    type <> 'personnel'
    or (classe_id is null and promotion_id is null and section_id is null)
  );

-- Une section appartient à une promotion ; l'élève qui la porte doit être
-- inscrit dans la même. Deux cas se présentent, et ils ne se traitent pas
-- de la même façon :
--
--   · on désigne une section qui n'est pas celle de sa promotion — c'est
--     une erreur de saisie, et elle se refuse ;
--   · l'élève change de promotion sous une section restée en place — alors
--     la section ne peut plus le suivre, et on la retire sans bruit plutôt
--     que de bloquer un changement de phase légitime.
create or replace function scolarite.trg_apprenant_section()
returns trigger
language plpgsql
as $$
declare
  v_promotion uuid;
begin
  if new.section_id is null then
    return new;
  end if;

  select promotion_id into v_promotion
  from scolarite.sections where id = new.section_id;

  if v_promotion is not distinct from new.promotion_id then
    return new;
  end if;

  if tg_op = 'INSERT' or new.section_id is distinct from old.section_id then
    raise exception
      'La section choisie ne relève pas de la promotion de cet apprenant.';
  end if;

  new.section_id := null;
  return new;
end;
$$;

-- Le nom compte : les déclencheurs `before` s'exécutent dans l'ordre
-- alphabétique, et celui-ci doit passer APRÈS
-- `apprenant_suit_sa_promotion`, qui pose `promotion_id` d'après la phase.
-- « tient » vient après « suit ».
drop trigger if exists apprenant_tient_sa_section on scolarite.apprenants;
create trigger apprenant_tient_sa_section
  before insert or update of section_id, classe_id, promotion_id
  on scolarite.apprenants
  for each row execute function scolarite.trg_apprenant_section();

comment on table scolarite.sections is
  'Le découpage d''une promotion en sections. L''élève y entre à '
  'l''incorporation et y reste : les phases se succèdent, la section non.';
