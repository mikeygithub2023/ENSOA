-- ============================================================================
-- SOCLE UNIFIÉ — une seule identité pour les deux modules.
--
-- Le point de la fusion : un même militaire n'a qu'un compte, qu'il relève
-- de la scolarité, du soutien technique, ou des deux. Un adjudant peut être
-- instructeur ET tenir l'armurerie.
--
-- Les deux familles de rôles sont conservées côte à côte plutôt que fondues
-- en une seule énumération. Ce n'est pas de la paresse : les ~100 politiques
-- RLS des deux bases interrogent `current_role()` et `current_user_role()`.
-- En gardant les deux fonctions — chacune lisant sa colonne — aucune
-- politique n'a besoin d'être retouchée. Or une politique mal retranscrite,
-- c'est le dossier médical d'un élève ouvert au garage. On ne les touche pas.
--
-- Un rôle nul signifie « cet agent ne relève pas de ce module » : les
-- politiques du module ne lui accordent alors rien.
-- ============================================================================

-- --- 1. Le rôle scolarité devient facultatif -------------------------------
-- Il était `not null default 'instructeur'`. Laissé tel quel, tout agent du
-- soutien technique naîtrait instructeur — et hériterait d'un droit de
-- lecture sur les apprenants de sa division. Personne ne reçoit un rôle
-- qu'on ne lui a pas donné.
alter table socle.profiles alter column role drop default;
alter table socle.profiles alter column role drop not null;

comment on column socle.profiles.role is
  'Rôle scolarité. Nul si l''agent ne relève que du soutien technique.';

-- --- 2. Rôles du soutien technique -----------------------------------------
create type socle.user_role as enum (
  'chef_soutien_technique',
  'soutien_petrolier',
  'garage',
  'armurerie',
  'poste_police',
  'officier_adjoint',
  'sante',
  'administrateur'
);

alter table socle.profiles
  add column role_logistique socle.user_role,
  add column matricule text unique,
  add column actif boolean not null default true;

comment on column socle.profiles.role_logistique is
  'Rôle soutien technique. Nul si l''agent ne relève que de la scolarité.';
comment on column socle.profiles.matricule is
  'Identifiant militaire — c''est avec lui qu''on se connecte, pas avec l''email.';

-- `nom_complet` était une colonne de la base logistique ; ici elle se calcule
-- à partir de nom/prénom, qui restent la seule vérité.
alter table socle.profiles
  add column nom_complet text
    generated always as (btrim(prenom || ' ' || nom)) stored;

-- --- 3. Organisation du soutien technique ----------------------------------
-- L'organigramme est commun : les divisions de l'école (créées par le module
-- scolarité) et les services/cellules du soutien technique cohabitent dans
-- le socle. Un profil peut être rattaché aux deux.
create table socle.service (
  id bigint generated always as identity primary key,
  libelle text not null
);

create table socle.cellule (
  id bigint generated always as identity primary key,
  libelle text not null,
  service_id bigint references socle.service(id)
);

alter table socle.profiles
  add column cellule_id bigint references socle.cellule(id);

-- --- 4. Le rôle logistique de l'utilisateur connecté -----------------------
-- security definer : la fonction doit lire `profiles` sans repasser par la
-- RLS de `profiles`, sinon le lookup de son propre rôle boucle sur lui-même.
create function socle.current_user_role()
returns socle.user_role
language sql
security definer
stable
set search_path = socle, public
as $$
  select role_logistique from socle.profiles where id = auth.uid();
$$;

-- --- 5. Droits sur le socle -------------------------------------------------
grant select, insert, update, delete on socle.service, socle.cellule to authenticated;
grant usage, select on all sequences in schema socle to authenticated;
