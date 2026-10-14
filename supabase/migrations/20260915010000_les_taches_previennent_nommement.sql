-- ============================================================================
-- Les notifications de tâche partent de la base, et nommément.
--
-- Trois messages du suivi des activités étaient encore écrits par
-- l'application : « Nouvelle tâche assignée », « Tâche terminée — à
-- valider », « Tâche validée ». Deux défauts s'y cumulaient.
--
-- LE PREMIER EST CELUI QU'ON CORRIGE PARTOUT ICI : adressés à un rôle, ils
-- n'écrivaient qu'une ligne pour tout un service. Le premier qui la lisait
-- l'éteignait pour ses collègues.
--
-- LE SECOND EST PLUS SÉRIEUX : ILS NE PARTAIENT PLUS DU TOUT. Depuis le
-- durcissement du 10 septembre, `notifications_insert` n'autorise qu'à
-- s'écrire à soi-même, ou à l'administrateur d'écrire à qui il veut.
-- L'Officier Adjoint n'est ni l'un ni l'autre : ses trois notifications
-- étaient refusées par la base. Le chef de service ne recevait plus rien
-- quand on lui confiait une tâche, et l'Officier Adjoint rien quand elle
-- était terminée.
--
-- On ne rouvre pas la politique pour autant : une application capable
-- d'adresser un message à tout un service, c'est le hameçonnage que cette
-- migration-là avait refermé. Ces trois messages sont des conséquences
-- d'une écriture dans `tache_activite` ; leur place est dans un
-- déclencheur, qui fane nominativement et que personne n'appelle à la main.
-- ============================================================================

-- --- À qui une tâche s'adresse ---------------------------------------------
-- Soit l'un des quatre services d'origine, soit les comptes d'un profil
-- créé — jamais les deux : la contrainte `tache_activite_destinataire_unique`
-- s'en porte garante.
--
-- Viser le rôle `profil_personnalise` ne marcherait pas : tous les profils
-- créés le partagent, et prévenir « le profil personnalisé » reviendrait à
-- prévenir l'intendance pour une tâche confiée à la popote.
create or replace function logistique.destinataires_de_la_tache(
  p_acteur text,
  p_profil_personnalise_id uuid
)
returns setof uuid
language sql
security definer
stable
set search_path = logistique, socle, public
as $$
  select id from socle.profiles
  where actif
    and (
      (p_profil_personnalise_id is not null
         and profil_personnalise_id = p_profil_personnalise_id)
      or (p_acteur is not null and role_logistique = case p_acteur
            when 'st' then 'chef_soutien_technique'
            when 'garage' then 'garage'
            when 'armurerie' then 'armurerie'
            when 'sante' then 'sante'
          end::socle.user_role)
    );
$$;

-- --- Une tâche confiée ------------------------------------------------------
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
        new.acteur, new.profil_personnalise_id)
    ),
    'activite',
    'Nouvelle tâche assignée',
    coalesce(v_titre || ' — ', '') || new.description
  );
  return new;
end $$;

drop trigger if exists notifier_tache_assignee on logistique.tache_activite;
create trigger notifier_tache_assignee
after insert on logistique.tache_activite
for each row execute function logistique.notifier_tache_assignee();

-- --- Une tâche terminée, puis validée ---------------------------------------
-- Les deux changements d'état tiennent dans un seul déclencheur : c'est la
-- même colonne qui bouge, et les séparer obligerait à lire deux fonctions
-- pour savoir qui est prévenu de quoi.
create or replace function logistique.notifier_statut_tache()
returns trigger
language plpgsql
security definer
set search_path = logistique, socle, public
as $$
declare v_titre text;
begin
  if new.statut = old.statut then
    return new;
  end if;

  select titre into v_titre
  from logistique.activite where id = new.activite_id;

  if new.statut = 'terminee' then
    -- C'est l'Officier Adjoint qui valide : lui seul a besoin de le savoir.
    perform socle.notifier(
      array(select socle.par_role_logistique('officier_adjoint')),
      'activite',
      'Tâche terminée — à valider',
      coalesce(v_titre || ' — ', '') || new.description
    );
  elsif new.statut = 'validee' then
    -- Et le service qui l'a faite apprend qu'elle est acceptée.
    perform socle.notifier(
      array(
        select logistique.destinataires_de_la_tache(
          new.acteur, new.profil_personnalise_id)
      ),
      'activite',
      'Tâche validée',
      coalesce(v_titre || ' — ', '') || new.description
    );
  end if;
  return new;
end $$;

drop trigger if exists notifier_statut_tache on logistique.tache_activite;
create trigger notifier_statut_tache
after update on logistique.tache_activite
for each row execute function logistique.notifier_statut_tache();

-- ============================================================================
-- Contrôle : doit retourner 0 ligne.
-- Un acteur de tâche que la résolution des destinataires ne saurait pas
-- traduire en rôle — il ne préviendrait personne, en silence.
-- ============================================================================
select distinct acteur
from logistique.tache_activite
where acteur is not null
  and acteur not in ('st', 'garage', 'armurerie', 'sante');
