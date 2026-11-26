-- ============================================================================
-- Les activités se corrigent et s'effacent ; une tâche va à une personne.
--
-- 1. SUPPRIMER UNE ACTIVITÉ emporte ses tâches. La clé étrangère de
--    `tache_activite` refusait jusqu'ici la suppression ; elle passe en
--    cascade. Ceux qui avaient une tâche encore ouverte en sont prévenus.
--
-- 2. UNE TÂCHE VA :
--    * à un service (l'un des quatre d'origine, ou un service créé) ;
--    * à un service ET à une personne de ce service ;
--    * ou à une personne de l'école, sans service.
--    La personne est un compte (`socle.profiles`) : elle doit pouvoir voir
--    sa tâche et la déclarer faite.
--
-- Le modifier d'une activité (titre, date, lieu, description) ne demande
-- rien de neuf : la politique « activite ecriture » (Officier Adjoint) et
-- « activite_admin_ecriture » couvrent déjà la mise à jour.
-- ============================================================================

-- --- 1. La suppression en cascade -------------------------------------------
-- La contrainte est retrouvée par ce qu'elle relie, non par son nom : un nom
-- différent laisserait l'ancienne en place, et elle bloquerait toujours.
do $$
declare c record;
begin
  for c in
    select conname from pg_constraint
    where conrelid = 'logistique.tache_activite'::regclass
      and confrelid = 'logistique.activite'::regclass
      and contype = 'f'
  loop
    execute format(
      'alter table logistique.tache_activite drop constraint %I', c.conname);
  end loop;
end $$;

alter table logistique.tache_activite
  add constraint tache_activite_activite_id_fkey
  foreign key (activite_id) references logistique.activite(id)
  on delete cascade;

-- --- 2. La personne désignée -----------------------------------------------
alter table logistique.tache_activite
  add column if not exists assigne_a uuid
    references socle.profiles(id) on delete set null,
  -- Recopié par le déclencheur : un chef de service n'a pas le droit de lire
  -- toutes les fiches, mais il doit lire le nom de qui fait la tâche. Gardé
  -- aussi quand le compte disparaît : la tâche dit encore à qui elle allait.
  add column if not exists assigne_nom text not null default '';

create index if not exists tache_activite_assigne_idx
  on logistique.tache_activite (assigne_a)
  where assigne_a is not null;

-- Au plus un service ; et un destinataire au moins, service ou personne.
alter table logistique.tache_activite
  drop constraint if exists tache_activite_destinataire_unique;
alter table logistique.tache_activite
  add constraint tache_activite_destinataire_unique check (
    (acteur is not null)::int + (profil_personnalise_id is not null)::int <= 1
    and (
      acteur is not null
      or profil_personnalise_id is not null
      or assigne_a is not null
      or assigne_nom <> ''
    )
  );

-- --- Qui est d'un service ---------------------------------------------------
-- Les comptes qui travaillent pour un service : ce sont eux qu'on peut
-- désigner dans une tâche confiée à ce service.
create or replace function logistique.est_du_service(
  p_compte uuid,
  p_acteur text,
  p_profil_personnalise_id uuid
)
returns boolean
language sql
security definer
stable
set search_path = logistique, socle, public
as $$
  select exists (
    select 1 from socle.profiles
    where id = p_compte
      and actif
      and (
        (p_profil_personnalise_id is not null
           and profil_personnalise_id = p_profil_personnalise_id)
        or (p_acteur = 'st' and role_logistique::text in
              ('chef_soutien_technique', 'soutien_petrolier'))
        or (p_acteur in ('garage', 'armurerie', 'sante')
              and role_logistique::text = p_acteur)
      )
  );
$$;

-- --- Ce que l'application ne décide pas -------------------------------------
create or replace function logistique.preparer_tache_activite()
returns trigger
language plpgsql
security definer
set search_path = logistique, socle, public
as $$
begin
  if new.assigne_a is not null then
    if tg_op = 'INSERT' or new.assigne_a is distinct from old.assigne_a
       or new.acteur is distinct from old.acteur
       or new.profil_personnalise_id is distinct from old.profil_personnalise_id
    then
      if not exists (
        select 1 from socle.profiles where id = new.assigne_a and actif
      ) then
        raise exception 'Cette personne n''a plus de compte actif.'
          using errcode = 'check_violation';
      end if;
      if (new.acteur is not null or new.profil_personnalise_id is not null)
         and not logistique.est_du_service(
           new.assigne_a, new.acteur, new.profil_personnalise_id)
      then
        raise exception 'Cette personne n''appartient pas au service choisi.'
          using errcode = 'check_violation';
      end if;
    end if;

    select trim(coalesce(grade || ' ', '') || nom || ' ' || prenom)
      into new.assigne_nom
    from socle.profiles where id = new.assigne_a;
    new.assigne_nom := coalesce(new.assigne_nom, '');

  elsif tg_op = 'INSERT'
     or new.acteur is not null
     or new.profil_personnalise_id is not null then
    -- Sans personne, pas de nom. Seule exception : le compte d'une tâche
    -- confiée à une personne seule a disparu (`on delete set null`) — son
    -- nom reste, sans quoi la tâche ne dirait plus à qui elle allait.
    new.assigne_nom := '';
  end if;
  return new;
end $$;

drop trigger if exists preparer_tache_activite on logistique.tache_activite;
create trigger preparer_tache_activite
before insert or update on logistique.tache_activite
for each row execute function logistique.preparer_tache_activite();

-- --- Qui est prévenu --------------------------------------------------------
-- Une personne désignée est prévenue nommément ; sinon, tout le service.
create or replace function logistique.destinataires_de_la_tache(
  p_acteur text,
  p_profil_personnalise_id uuid,
  p_assigne_a uuid
)
returns setof uuid
language sql
security definer
stable
set search_path = logistique, socle, public
as $$
  select p_assigne_a where p_assigne_a is not null
  union
  select d from logistique.destinataires_de_la_tache(
    p_acteur, p_profil_personnalise_id) d
  where p_assigne_a is null;
$$;

create or replace function logistique.notifier_tache_assignee()
returns trigger
language plpgsql
security definer
set search_path = logistique, socle, public
as $$
declare v_titre text;
begin
  select titre into v_titre
  from logistique.activite where id = new.activite_id;

  perform socle.notifier(
    array(
      select logistique.destinataires_de_la_tache(
        new.acteur, new.profil_personnalise_id, new.assigne_a)
    ),
    'activite',
    'Nouvelle tâche assignée',
    coalesce(v_titre || ' — ', '') || new.description
  );
  return new;
end $$;

create or replace function logistique.notifier_statut_tache()
returns trigger
language plpgsql
security definer
set search_path = logistique, socle, public
as $$
declare v_titre text;
begin
  select titre into v_titre
  from logistique.activite where id = new.activite_id;

  -- Une tâche redonnée à quelqu'un d'autre : le nouveau venu l'apprend.
  if new.assigne_a is not null
     and new.assigne_a is distinct from old.assigne_a
     and new.statut = 'a_faire' then
    perform socle.notifier(
      array[new.assigne_a],
      'activite',
      'Nouvelle tâche assignée',
      coalesce(v_titre || ' — ', '') || new.description
    );
  end if;

  if new.statut = old.statut then
    return new;
  end if;

  if new.statut = 'terminee' then
    -- C'est l'Officier Adjoint qui valide : lui seul a besoin de le savoir.
    perform socle.notifier(
      array(select socle.par_role_logistique('officier_adjoint')),
      'activite',
      'Tâche terminée — à valider',
      coalesce(v_titre || ' — ', '') || new.description
    );
  elsif new.statut = 'validee' then
    perform socle.notifier(
      array(
        select logistique.destinataires_de_la_tache(
          new.acteur, new.profil_personnalise_id, new.assigne_a)
      ),
      'activite',
      'Tâche validée',
      coalesce(v_titre || ' — ', '') || new.description
    );
  end if;
  return new;
end $$;

-- Une activité effacée : ceux qui avaient encore une tâche à y faire
-- l'apprennent, faute de quoi elle disparaîtrait de leur liste sans un mot.
create or replace function logistique.notifier_activite_supprimee()
returns trigger
language plpgsql
security definer
set search_path = logistique, socle, public
as $$
begin
  perform socle.notifier(
    array(
      select distinct d
      from logistique.tache_activite t,
        lateral logistique.destinataires_de_la_tache(
          t.acteur, t.profil_personnalise_id, t.assigne_a) d
      where t.activite_id = old.id
        and t.statut in ('a_faire', 'terminee')
    ),
    'activite',
    'Activité supprimée',
    old.titre || ' — ses tâches sont retirées.'
  );
  return old;
end $$;

drop trigger if exists notifier_activite_supprimee on logistique.activite;
create trigger notifier_activite_supprimee
before delete on logistique.activite
for each row execute function logistique.notifier_activite_supprimee();

-- --- Ce que la personne désignée voit et fait --------------------------------
-- Les politiques permissives s'additionnent : celles des services restent.
drop policy if exists "tache select assigne" on logistique.tache_activite;
create policy "tache select assigne" on logistique.tache_activite
  for select to authenticated using (assigne_a = auth.uid());

-- Elle déclare sa tâche faite ; elle ne peut pas la donner à un autre.
drop policy if exists "tache update assigne" on logistique.tache_activite;
create policy "tache update assigne" on logistique.tache_activite
  for update to authenticated
  using (assigne_a = auth.uid())
  with check (assigne_a = auth.uid());

-- --- La liste où l'on choisit la personne -----------------------------------
-- L'Officier Adjoint ne lit pas tous les comptes (RLS de `socle.profiles`) ;
-- cette fonction lui donne ce qu'il faut pour désigner quelqu'un, et rien
-- de plus. À qui n'organise pas les activités, elle ne rend rien.
create or replace function logistique.personnes_pour_les_taches()
returns table (
  id uuid,
  nom text,
  role_logistique text,
  profil_personnalise_id uuid
)
language sql
security definer
stable
set search_path = logistique, socle, public
as $$
  select p.id,
         trim(coalesce(p.grade || ' ', '') || p.nom || ' ' || p.prenom),
         p.role_logistique::text,
         p.profil_personnalise_id
  from socle.profiles p
  where p.actif
    and (socle.est_administrateur()
         or socle.current_user_role()::text = 'officier_adjoint')
  order by p.nom, p.prenom;
$$;

revoke all on function logistique.personnes_pour_les_taches() from public;
grant execute on function logistique.personnes_pour_les_taches()
  to authenticated;

notify pgrst, 'reload schema';

-- ============================================================================
-- Contrôle : une ligne, cascade = true, et 2 politiques « assigne ».
-- ============================================================================
select
  (select confdeltype = 'c' from pg_constraint
    where conrelid = 'logistique.tache_activite'::regclass
      and conname = 'tache_activite_activite_id_fkey') as cascade,
  (select count(*) from pg_policies
    where schemaname = 'logistique' and tablename = 'tache_activite'
      and policyname like '%assigne') as politiques_assigne;
