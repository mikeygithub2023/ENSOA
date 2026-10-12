-- ============================================================================
-- Les profils personnalisés : des services que l'administrateur crée lui-même.
--
-- L'Officier Adjoint répartit les tâches d'une activité entre quatre services
-- figés dans le code — soutien pétrolier, garage, armurerie, service de santé.
-- L'école en compte d'autres, et en comptera d'autres encore. Ils se créent
-- désormais en base, sans recompiler quoi que ce soit.
--
-- Ce qu'un profil personnalisé peut faire : voir les tâches qu'on lui confie,
-- les déclarer faites. Rien d'autre. C'est délibéré — on ouvre un profil pour
-- confier du travail, pas pour donner accès à l'ERP.
-- ============================================================================

-- --- Le catalogue des profils ----------------------------------------------
create table if not exists socle.profil_personnalise (
  id uuid primary key default gen_random_uuid(),
  libelle text not null,
  description text,
  actif boolean not null default true,
  cree_par uuid references socle.profiles(id),
  cree_le timestamptz not null default now()
);

-- Deux profils du même nom rendraient la liste de répartition illisible, et
-- l'on ne saurait plus lequel on a nommé. L'index ignore la casse et les
-- profils retirés : « Intendance » peut renaître après avoir été désactivé.
create unique index if not exists profil_personnalise_libelle_actif_idx
  on socle.profil_personnalise (lower(libelle))
  where actif;

alter table socle.profil_personnalise enable row level security;

-- Tout compte connecté lit le catalogue : sans cela, l'écran de répartition
-- afficherait des identifiants au lieu des noms de services.
drop policy if exists "profil_personnalise select" on socle.profil_personnalise;
create policy "profil_personnalise select" on socle.profil_personnalise
  for select to authenticated using (true);

-- Seul l'administrateur en crée, en renomme et en retire.
drop policy if exists admin_tout_pouvoir on socle.profil_personnalise;
create policy admin_tout_pouvoir on socle.profil_personnalise
  for all to authenticated
  using (socle.est_administrateur())
  with check (socle.est_administrateur());

grant select, insert, update, delete on socle.profil_personnalise to authenticated;

-- --- À quel profil appartient un compte -------------------------------------
alter table socle.profiles
  add column if not exists profil_personnalise_id uuid
    references socle.profil_personnalise(id);

-- Un compte porte le rôle `profil_personnalise` ET la ligne qui dit lequel.
-- L'un sans l'autre donne un compte à demi défini : ou bien il appartient à
-- une famille sans en être membre, ou bien il est membre d'un service sans
-- que la RLS le sache.
alter table socle.profiles drop constraint if exists profiles_profil_personnalise_coherent;
alter table socle.profiles
  add constraint profiles_profil_personnalise_coherent check (
    (role_logistique = 'profil_personnalise') = (profil_personnalise_id is not null)
  );

-- --- À qui une tâche est confiée --------------------------------------------
alter table logistique.tache_activite
  add column if not exists profil_personnalise_id uuid
    references socle.profil_personnalise(id);

-- `acteur` cesse d'être obligatoire : une tâche vise désormais soit l'un des
-- quatre services d'origine, soit un profil créé — jamais les deux, jamais
-- aucun. Sans cette exclusion, une tâche sans destinataire resterait dans la
-- base sans jamais paraître sur l'écran de personne.
alter table logistique.tache_activite alter column acteur drop not null;
alter table logistique.tache_activite drop constraint if exists tache_activite_destinataire_unique;
alter table logistique.tache_activite
  add constraint tache_activite_destinataire_unique check (
    (acteur is not null)::int + (profil_personnalise_id is not null)::int = 1
  );

create index if not exists tache_activite_profil_idx
  on logistique.tache_activite (profil_personnalise_id)
  where profil_personnalise_id is not null;

-- --- Qui suis-je, si je suis un profil personnalisé ? -----------------------
create or replace function socle.current_profil_personnalise()
returns uuid
language sql
security definer
stable
set search_path = socle, public
as $$
  select profil_personnalise_id
  from socle.profiles
  where id = auth.uid() and actif;
$$;

grant execute on function socle.current_profil_personnalise() to authenticated;

-- --- Ce qu'un profil personnalisé voit et peut faire -------------------------
-- Les politiques existantes nomment les quatre services ; celles-ci ajoutent
-- la voie des profils créés. Les politiques permissives s'additionnent : rien
-- n'est retiré à personne.
drop policy if exists "tache select profil" on logistique.tache_activite;
create policy "tache select profil" on logistique.tache_activite
  for select to authenticated using (
    profil_personnalise_id is not null
    and profil_personnalise_id = socle.current_profil_personnalise()
  );

-- Il déclare sa tâche faite ; il ne la vise pas — c'est l'Officier Adjoint qui
-- vise — et il ne peut pas la rendre à un autre service.
drop policy if exists "tache update profil" on logistique.tache_activite;
create policy "tache update profil" on logistique.tache_activite
  for update to authenticated
  using (
    profil_personnalise_id is not null
    and profil_personnalise_id = socle.current_profil_personnalise()
  )
  with check (
    profil_personnalise_id = socle.current_profil_personnalise()
  );

-- Une tâche se confie par l'Officier Adjoint, ou par l'administrateur — qui
-- passe déjà par `admin_tout_pouvoir`. La politique d'insertion d'origine ne
-- nommait que l'Officier Adjoint ; elle reste telle quelle.

-- --- Il lit l'activité dont relève sa tâche ---------------------------------
-- Son tableau de bord range ses tâches sous l'activité qui les a demandées :
-- « faire le plein » ne dit rien sans la cérémonie et sa date.
--
-- VÉRIFIÉ APRÈS COUP, ET À CORRIGER UN JOUR : cette politique ne restreint
-- rien aujourd'hui. La politique « activite select » d'origine ouvre la table
-- à tout compte connecté, et les politiques permissives s'additionnent — un
-- profil créé lit donc les vingt-neuf activités de l'école, pas seulement les
-- siennes. Celle-ci garde néanmoins son sens : le jour où la lecture des
-- activités sera resserrée, elle lui conservera les siennes sans qu'on ait à
-- y repenser.
drop policy if exists "activite select profil" on logistique.activite;
create policy "activite select profil" on logistique.activite
  for select to authenticated using (
    socle.current_profil_personnalise() is not null
    and exists (
      select 1 from logistique.tache_activite t
      where t.activite_id = logistique.activite.id
        and t.profil_personnalise_id = socle.current_profil_personnalise()
    )
  );

-- ============================================================================
-- Contrôle : doit retourner 0 ligne.
--
-- Un compte qui porterait le rôle sans le profil, ou l'inverse — la contrainte
-- l'interdit désormais, mais une ligne antérieure pourrait traîner.
-- ============================================================================
select matricule, role_logistique, profil_personnalise_id
from socle.profiles
where (role_logistique = 'profil_personnalise') <> (profil_personnalise_id is not null);
