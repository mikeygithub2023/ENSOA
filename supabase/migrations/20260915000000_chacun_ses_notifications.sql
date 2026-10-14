-- ============================================================================
-- Chacun ses notifications.
--
-- Une notification adressée à un rôle était UNE SEULE LIGNE, partagée par
-- tous ceux qui portent ce rôle. `read` étant une colonne de cette ligne, le
-- premier qui la lisait l'éteignait pour les autres : le chef du garage
-- ouvrait l'application à sept heures, et son adjoint ne saurait jamais
-- qu'un véhicule avait atteint son seuil de vidange.
--
-- Le bouton « tout marquer comme lu » n'a rien créé de ce défaut, mais il
-- l'a rendu visible : trente lectures d'un coup, c'est trente notifications
-- éteintes chez les collègues du même rôle.
--
-- Désormais, une notification appartient à une personne. Un message destiné
-- à un service devient autant de lignes qu'il y a de gens dans ce service,
-- et chacun éteint la sienne.
--
-- CE QUE CELA COÛTE. Prévenir un service de huit personnes écrit huit
-- lignes au lieu d'une. Sur une table qui en compte cent trente-neuf après
-- des mois de service, c'est sans objet.
--
-- CE QUE CELA RAPPORTE, OUTRE L'ESSENTIEL. La notification poussée devient
-- juste : le serveur recevait `role_cible` et devait retrouver lui-même à
-- qui l'envoyer ; il reçoit maintenant un destinataire. Et les deux
-- politiques qui ouvraient une ligne à tout un rôle disparaissent — une
-- notification ne se lit et ne se marque plus que par celui qu'elle vise.
-- ============================================================================

-- --- 1. Les lignes partagées deviennent nominatives ------------------------
-- Le déclencheur d'envoi poussé est suspendu le temps du versement : sans
-- cela, deux messages vieux de plusieurs jours sonneraient sur toutes les
-- tablettes du garage et du soutien pétrolier.
alter table socle.notifications disable trigger push_notification_on_insert;

-- Celles qui visaient un rôle.
insert into socle.notifications (
  profile_id, type, title, message, note_id, read, created_at,
  apprenant_id, demande_reapprovisionnement_id, cours_id
)
select p.id, n.type, n.title, n.message, n.note_id, n.read, n.created_at,
       n.apprenant_id, n.demande_reapprovisionnement_id, n.cours_id
from socle.notifications n
join socle.profiles p
  on p.role_logistique = n.role_cible and p.actif
where n.profile_id is null and n.role_cible is not null;

-- Celles qui ne visaient personne : elles s'adressaient à toute l'école.
insert into socle.notifications (
  profile_id, type, title, message, note_id, read, created_at,
  apprenant_id, demande_reapprovisionnement_id, cours_id
)
select p.id, n.type, n.title, n.message, n.note_id, n.read, n.created_at,
       n.apprenant_id, n.demande_reapprovisionnement_id, n.cours_id
from socle.notifications n
cross join socle.profiles p
where n.profile_id is null and n.role_cible is null and p.actif;

delete from socle.notifications where profile_id is null;

alter table socle.notifications enable trigger push_notification_on_insert;

-- --- 2. Une notification a désormais toujours un destinataire --------------
-- La contrainte vaut mieux qu'une convention : c'est elle qui empêchera
-- qu'une ligne sans destinataire réapparaisse un jour, invisible à tous
-- puisque plus aucune politique ne la montre.
alter table socle.notifications alter column profile_id set not null;

drop policy if exists notifications_select_role on socle.notifications;
drop policy if exists notifications_update_role on socle.notifications;

-- `role_cible` reste : elle dit à quel titre on a été prévenu, ce qui se
-- relit utilement. Elle ne décide plus rien.
comment on column socle.notifications.role_cible is
  'Le rôle au titre duquel le destinataire a été prévenu. Informatif : la '
  'visibilité se règle sur profile_id seul.';

-- ============================================================================
-- 3. Ce que l'application faisait, la base le fait
--
-- Deux notifications de service partaient jusqu'ici du client, par une
-- insertion directe portant `role_cible`. Elles ne peuvent plus l'être, et
-- il ne faut pas leur rouvrir une porte : une fonction « prévenir tout un
-- service » appelable depuis l'application, c'est très exactement le
-- hameçonnage que la migration du 10 septembre a refermé — n'importe quel
-- compte adressant « votre mot de passe expire » à toute une unité, dans le
-- canal officiel de l'école.
--
-- Or ces deux messages sont des conséquences d'une écriture en base. Leur
-- place est dans un déclencheur, qui fane nominativement et que personne ne
-- peut appeler à la main.
-- ============================================================================

-- --- Le seuil de vidange franchi -------------------------------------------
create or replace function logistique.notifier_seuil_vidange()
returns trigger
language plpgsql
security definer
set search_path = logistique, socle, public
as $$
declare v_designation text;
begin
  -- Au franchissement seulement. Sans cette condition, chaque relevé
  -- kilométrique d'un véhicule en retard de vidange reprévient tout le
  -- monde, et l'alerte finit par ne plus être lue.
  if not (new.kilometrage >= new.kilometrage_vidange_prochaine
          and old.kilometrage < old.kilometrage_vidange_prochaine) then
    return new;
  end if;

  select m.marque || ' ' || mo.modele into v_designation
  from logistique.type_vhl t
  join logistique.modele_vhl mo on mo.id = t.modele_id
  join logistique.marque_vhl m on m.id = mo.marque_id
  where t.id = new.type_vhl_id;

  perform socle.notifier(
    array(
      select socle.par_role_logistique('chef_soutien_technique')
      union
      select socle.par_role_logistique('garage')
    ),
    'maintenance',
    'Vidange à prévoir',
    new.immatriculation
      || coalesce(' (' || v_designation || ')', '')
      || ' a atteint son seuil de vidange — '
      || new.kilometrage || ' km.'
  );
  return new;
end $$;

drop trigger if exists notifier_seuil_vidange on logistique.vehicule;
create trigger notifier_seuil_vidange
after update on logistique.vehicule
for each row execute function logistique.notifier_seuil_vidange();

-- --- Le retour au camp -----------------------------------------------------
create or replace function logistique.notifier_retour_au_camp()
returns trigger
language plpgsql
security definer
set search_path = logistique, socle, public
as $$
begin
  if not (new.etat = 'termine' and old.etat is distinct from 'termine') then
    return new;
  end if;

  perform socle.notifier(
    array(
      select socle.par_role_logistique('chef_soutien_technique')
      union
      select socle.par_role_logistique('garage')
    ),
    'maintenance',
    'Véhicule de retour au camp',
    logistique.immatriculation(new.vehicule_id)
      || ' est rentré au camp'
      || coalesce(' — ' || new.km_arrivee || ' km', '')
      || '.'
  );
  return new;
end $$;

drop trigger if exists notifier_retour_au_camp on logistique.mouvement;
create trigger notifier_retour_au_camp
after update on logistique.mouvement
for each row execute function logistique.notifier_retour_au_camp();

-- ============================================================================
-- Contrôle : doit retourner 0 ligne.
-- Une notification sans destinataire, ou une politique qui ouvrirait encore
-- une ligne à tout un rôle.
-- ============================================================================
select 'notification orpheline' as defaut, count(*)::text as detail
from socle.notifications where profile_id is null
having count(*) > 0
union all
select 'politique de role restante', policyname
from pg_policies
where schemaname = 'socle' and tablename = 'notifications'
  and coalesce(qual, '') like '%role_cible%';
