-- ============================================================================
-- Les tâches quotidiennes : la liste de chacun.
--
-- Les tâches d'activité vont à un service et suivent un cycle de validation
-- par l'Officier Adjoint. Celles-ci vont à une personne et se cochent, c'est
-- tout : elles ont donc leur propre table, plutôt qu'une `tache_activite` sans
-- activité où chaque colonne et chaque déclencheur devraient distinguer deux
-- cas.
--
-- QUI VOIT QUOI :
--   * chacun écrit ses propres tâches, et lui seul les lit : une liste
--     personnelle reste personnelle, y compris face à l'administrateur ;
--   * l'administrateur peut imputer une tâche à quelqu'un : il la suit, et la
--     personne imputée la coche sans pouvoir en changer le contenu.
-- ============================================================================

create table if not exists logistique.tache_quotidienne (
  id bigint generated always as identity primary key,
  description text not null check (length(trim(description)) > 0),
  echeance timestamptz,
  priorite text not null default 'normale'
    check (priorite in ('normale', 'importante', 'urgente')),
  assigne_a uuid not null references socle.profiles(id) on delete cascade,
  cree_par uuid references socle.profiles(id) on delete set null,
  -- Lus par le déclencheur : un agent n'a pas le droit de lire la fiche de
  -- celui qui lui impute une tâche, mais il doit pouvoir lire son nom.
  assigne_nom text not null default '',
  cree_par_nom text not null default '',
  terminee_le timestamptz,
  cree_le timestamptz not null default now()
);

create index if not exists tache_quotidienne_assigne_idx
  on logistique.tache_quotidienne (assigne_a);
create index if not exists tache_quotidienne_cree_par_idx
  on logistique.tache_quotidienne (cree_par);

grant select, insert, update, delete on logistique.tache_quotidienne
  to authenticated;

-- --- Ce que l'application ne décide pas -------------------------------------
create or replace function logistique.preparer_tache_quotidienne()
returns trigger
language plpgsql
security definer
set search_path = logistique, socle, public
as $$
begin
  if tg_op = 'INSERT' then
    new.cree_par := coalesce(auth.uid(), new.cree_par);
  else
    new.cree_par := old.cree_par;
    -- La personne imputée coche sa tâche ; elle n'en réécrit pas le contenu.
    if auth.uid() is distinct from old.cree_par
       and not socle.est_administrateur() then
      new.description := old.description;
      new.echeance := old.echeance;
      new.priorite := old.priorite;
      new.assigne_a := old.assigne_a;
    end if;
  end if;

  select trim(coalesce(grade || ' ', '') || nom || ' ' || prenom)
    into new.assigne_nom
  from socle.profiles where id = new.assigne_a;

  select trim(coalesce(grade || ' ', '') || nom || ' ' || prenom)
    into new.cree_par_nom
  from socle.profiles where id = new.cree_par;

  new.assigne_nom := coalesce(new.assigne_nom, '');
  new.cree_par_nom := coalesce(new.cree_par_nom, '');
  return new;
end $$;

drop trigger if exists preparer_tache_quotidienne
  on logistique.tache_quotidienne;
create trigger preparer_tache_quotidienne
before insert or update on logistique.tache_quotidienne
for each row execute function logistique.preparer_tache_quotidienne();

-- --- Qui est prévenu --------------------------------------------------------
-- Une tâche qu'on s'écrit à soi-même ne prévient personne.
create or replace function logistique.notifier_tache_quotidienne()
returns trigger
language plpgsql
security definer
set search_path = logistique, socle, public
as $$
begin
  if new.assigne_a is not distinct from new.cree_par then
    return new;
  end if;

  if tg_op = 'INSERT'
     or new.assigne_a is distinct from old.assigne_a then
    perform socle.notifier(
      array[new.assigne_a],
      'activite',
      'Nouvelle tâche imputée',
      new.description
    );
  elsif old.terminee_le is null and new.terminee_le is not null then
    perform socle.notifier(
      array[new.cree_par],
      'activite',
      'Tâche réalisée',
      new.assigne_nom || ' — ' || new.description
    );
  end if;
  return new;
end $$;

drop trigger if exists notifier_tache_quotidienne
  on logistique.tache_quotidienne;
create trigger notifier_tache_quotidienne
after insert or update on logistique.tache_quotidienne
for each row execute function logistique.notifier_tache_quotidienne();

-- --- Les droits -------------------------------------------------------------
alter table logistique.tache_quotidienne enable row level security;

drop policy if exists "tache quotidienne select" on logistique.tache_quotidienne;
create policy "tache quotidienne select" on logistique.tache_quotidienne
  for select to authenticated using (
    assigne_a = auth.uid()
    or cree_par = auth.uid()
    or (socle.est_administrateur() and assigne_a is distinct from cree_par)
  );

drop policy if exists "tache quotidienne insert" on logistique.tache_quotidienne;
create policy "tache quotidienne insert" on logistique.tache_quotidienne
  for insert to authenticated with check (
    socle.est_de_l_ecole()
    and cree_par = auth.uid()
    and (assigne_a = auth.uid() or socle.est_administrateur())
  );

drop policy if exists "tache quotidienne update" on logistique.tache_quotidienne;
create policy "tache quotidienne update" on logistique.tache_quotidienne
  for update to authenticated
  using (
    assigne_a = auth.uid()
    or cree_par = auth.uid()
    or (socle.est_administrateur() and assigne_a is distinct from cree_par)
  )
  with check (assigne_a = auth.uid() or socle.est_administrateur());

drop policy if exists "tache quotidienne delete" on logistique.tache_quotidienne;
create policy "tache quotidienne delete" on logistique.tache_quotidienne
  for delete to authenticated using (
    cree_par = auth.uid()
    or (socle.est_administrateur() and assigne_a is distinct from cree_par)
  );
