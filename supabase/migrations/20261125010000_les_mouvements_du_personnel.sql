-- ============================================================================
-- Les mouvements du personnel.
--
-- Un militaire de l'école ne reste pas immobile : on l'affecte, on le mute
-- d'un service à l'autre, on le met à la disposition d'une autre formation,
-- on le reverse dans une autre unité, il revient. Jusqu'ici la fiche n'en
-- gardait que l'état du jour — la dernière position lue dans l'état
-- nominatif — et rien de ce qui y avait mené.
--
-- LES CINQ MOUVEMENTS
--   affectation          il rejoint l'école, ou y est affecté à un service ;
--   mutation             il change de service au sein de l'école ;
--   mise_a_disposition   il est prêté à une autre formation, et reste des
--                        nôtres : il compte dans l'effectif ;
--   reversement          il quitte l'école pour une autre unité. Sa fiche
--                        est gardée — on pourra la supprimer plus tard —,
--                        mais il ne compte plus dans l'effectif ;
--   retour               il reprend son service à l'école, après une mise à
--                        disposition ou un reversement.
--
-- Chaque mouvement s'écrit une fois et ne se réécrit pas : c'est un
-- journal. La fiche, elle, suit — le déclencheur porte le mouvement sur le
-- statut, la position, le service et l'unité, et garde dans la ligne ce qui
-- était vrai juste avant. Le journal ne tient que le personnel : un élève
-- change de phase, pas de service.
--
-- À EXÉCUTER UNE FOIS dans Supabase → SQL Editor. Rejouable sans dégât.
-- ============================================================================

-- ============================================================================
-- 1. LA FICHE : UN STATUT DE PLUS, ET L'UNITÉ
-- ============================================================================
-- « Reversé » rejoint actif, radié, diplômé, suspendu. La contrainte d'origine
-- est anonyme (déclarée sur la colonne) : on la retrouve par sa définition
-- plutôt que de parier sur son nom.
do $$
declare
  c record;
begin
  for c in
    select con.conname
    from pg_constraint con
    join pg_class t on t.oid = con.conrelid
    join pg_namespace n on n.oid = t.relnamespace
    where n.nspname = 'scolarite'
      and t.relname = 'apprenants'
      and con.contype = 'c'
      and pg_get_constraintdef(con.oid) ilike '%statut%'
      and pg_get_constraintdef(con.oid) ilike '%suspendu%'
  loop
    execute format('alter table scolarite.apprenants drop constraint %I',
                   c.conname);
  end loop;
end $$;

alter table scolarite.apprenants
  add constraint apprenants_statut_check
  check (statut in ('actif', 'radie', 'diplome', 'suspendu', 'reverse'));

alter table scolarite.apprenants
  add column if not exists unite text;

comment on column scolarite.apprenants.unite is
  'L''unité d''appartenance, colonne UNITES de l''état nominatif DORH. '
  'ENSOA pour le personnel de l''école ; l''unité d''accueil pour un '
  'militaire reversé. Nulle pour les élèves et les stagiaires.';

update scolarite.apprenants
set unite = 'ENSOA'
where type = 'personnel' and unite is null;

-- ============================================================================
-- 2. LE JOURNAL
-- ============================================================================
create table if not exists scolarite.mouvements_personnel (
  id uuid primary key default gen_random_uuid(),

  apprenant_id uuid not null
    references scolarite.apprenants (id) on delete cascade,

  nature text not null check (nature in (
    'affectation', 'mutation', 'mise_a_disposition', 'reversement', 'retour'
  )),

  date_effet date not null,

  -- Le service où il va : le nouveau service pour une affectation, une
  -- mutation ou un retour ; la formation d'accueil pour une mise à
  -- disposition.
  service_apres text,

  -- L'unité qui le reçoit, pour un reversement.
  unite_accueil text,

  -- Le texte qui l'ordonne : décision, note de service, message.
  reference text,

  observation text,

  -- Ce qui était vrai juste avant, relevé par le déclencheur : la fiche
  -- change, le journal garde d'où l'on venait.
  statut_avant text,
  position_avant text,
  service_avant text,
  unite_avant text,

  created_at timestamptz not null default now(),
  cree_par uuid references socle.profiles (id),

  constraint mouvement_mutation_dit_ou
    check (nature <> 'mutation'
           or length(trim(coalesce(service_apres, ''))) > 0),
  constraint mouvement_mise_a_disposition_dit_ou
    check (nature <> 'mise_a_disposition'
           or length(trim(coalesce(service_apres, ''))) > 0),
  constraint mouvement_reversement_dit_ou
    check (nature <> 'reversement'
           or length(trim(coalesce(unite_accueil, ''))) > 0)
);

create index if not exists mouvements_personnel_apprenant_idx
  on scolarite.mouvements_personnel (apprenant_id, date_effet desc);

-- ============================================================================
-- 3. LE MOUVEMENT PORTÉ SUR LA FICHE
-- ============================================================================
-- `security definer` : celui qui inscrit le mouvement a le droit de
-- l'inscrire (la RLS du journal l'a vérifié), et la fiche doit suivre même
-- si sa propre politique d'écriture sur `apprenants` est plus étroite.
create or replace function scolarite.porter_mouvement_personnel()
returns trigger
language plpgsql
security definer
set search_path = scolarite, socle, public
as $$
declare
  fiche scolarite.apprenants%rowtype;
begin
  select * into fiche from scolarite.apprenants where id = new.apprenant_id;

  if not found then
    raise exception 'Ce militaire est introuvable.';
  end if;
  if fiche.type <> 'personnel' then
    raise exception
      'Les mouvements ne se tiennent que pour le personnel de l''école.';
  end if;

  new.cree_par := coalesce(auth.uid(), new.cree_par);
  new.statut_avant := fiche.statut;
  new.position_avant := fiche.position_statutaire;
  new.service_avant := fiche.service_affectation;
  new.unite_avant := fiche.unite;
  new.service_apres := nullif(trim(new.service_apres), '');
  new.unite_accueil := nullif(trim(new.unite_accueil), '');

  case new.nature
    when 'affectation', 'retour' then
      update scolarite.apprenants set
        statut = 'actif',
        position_statutaire = 'PERSONNEL AU SERVICE',
        unite = 'ENSOA',
        service_affectation = coalesce(new.service_apres, service_affectation)
      where id = new.apprenant_id;
    when 'mutation' then
      update scolarite.apprenants set
        service_affectation = new.service_apres
      where id = new.apprenant_id;
    when 'mise_a_disposition' then
      update scolarite.apprenants set
        statut = 'actif',
        position_statutaire = 'MIS A DISPOSITION',
        service_affectation = new.service_apres
      where id = new.apprenant_id;
    when 'reversement' then
      update scolarite.apprenants set
        statut = 'reverse',
        unite = new.unite_accueil
      where id = new.apprenant_id;
  end case;

  return new;
end $$;

drop trigger if exists porter_mouvement_personnel
  on scolarite.mouvements_personnel;
create trigger porter_mouvement_personnel
  before insert on scolarite.mouvements_personnel
  for each row execute function scolarite.porter_mouvement_personnel();

-- ============================================================================
-- 4. QUI VOIT QUOI, QUI ÉCRIT QUOI
-- ============================================================================
-- Comme le dossier de pension : l'administrateur partout, le chef de
-- division et l'instructeur sur l'effectif de leur division, l'intéressé
-- sur son propre cas. Inscrire : l'administrateur, et le chef de division
-- sur son effectif — c'est le chef du bureau RH de la DCL. Effacer :
-- l'administrateur seul, et cela ne défait pas la fiche. Réécrire : personne.
alter table scolarite.mouvements_personnel enable row level security;

drop policy if exists mouvements_personnel_select_admin
  on scolarite.mouvements_personnel;
create policy mouvements_personnel_select_admin
  on scolarite.mouvements_personnel
  for select to authenticated
  using (socle.current_role() = 'admin' or socle.est_administrateur());

drop policy if exists mouvements_personnel_select_division
  on scolarite.mouvements_personnel;
create policy mouvements_personnel_select_division
  on scolarite.mouvements_personnel
  for select to authenticated
  using (
    socle.current_role() in ('chef_division', 'instructeur')
    and scolarite.releve_de_ma_division(apprenant_id)
  );

drop policy if exists mouvements_personnel_select_self
  on scolarite.mouvements_personnel;
create policy mouvements_personnel_select_self
  on scolarite.mouvements_personnel
  for select to authenticated
  using (
    exists (
      select 1 from scolarite.apprenants a
      where a.id = mouvements_personnel.apprenant_id
        and a.profile_id = auth.uid()
    )
  );

drop policy if exists mouvements_personnel_insert_admin
  on scolarite.mouvements_personnel;
create policy mouvements_personnel_insert_admin
  on scolarite.mouvements_personnel
  for insert to authenticated
  with check (socle.current_role() = 'admin' or socle.est_administrateur());

drop policy if exists mouvements_personnel_insert_division
  on scolarite.mouvements_personnel;
create policy mouvements_personnel_insert_division
  on scolarite.mouvements_personnel
  for insert to authenticated
  with check (
    socle.current_role() = 'chef_division'
    and scolarite.releve_de_ma_division(apprenant_id)
  );

drop policy if exists mouvements_personnel_delete_admin
  on scolarite.mouvements_personnel;
create policy mouvements_personnel_delete_admin
  on scolarite.mouvements_personnel
  for delete to authenticated
  using (socle.current_role() = 'admin' or socle.est_administrateur());

-- ============================================================================
-- 5. JOURNAL D'AUDIT ET DROITS
-- ============================================================================
drop trigger if exists audit_mouvements_personnel
  on scolarite.mouvements_personnel;
create trigger audit_mouvements_personnel
  after insert or update or delete on scolarite.mouvements_personnel
  for each row execute function socle.audit_trigger();

grant select, insert, delete on scolarite.mouvements_personnel
  to authenticated;

notify pgrst, 'reload schema';

-- ============================================================================
-- Contrôle : une ligne, RLS active, 6 politiques ; puis le personnel par
-- unité (ENSOA partout tant qu'aucun reversement n'est inscrit).
-- ============================================================================
select
  c.relrowsecurity as rls_active,
  (select count(*) from pg_policies p
    where p.schemaname = 'scolarite'
      and p.tablename = 'mouvements_personnel') as politiques,
  (select count(*) from scolarite.apprenants
    where type = 'personnel' and unite = 'ENSOA') as personnel_ensoa
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'scolarite' and c.relname = 'mouvements_personnel';
