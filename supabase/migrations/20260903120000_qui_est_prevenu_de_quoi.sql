-- ============================================================================
-- Qui est prévenu de quoi.
--
-- Jusqu'ici une seule chose déclenchait une notification : la demande de
-- suppression d'une note. Le commandement en attend une vingtaine d'autres,
-- réparties selon ce que chacun a la charge de savoir.
--
-- Tout se joue en base, par déclencheurs, et non dans l'application. Trois
-- raisons : une notification part quelle que soit la voie par laquelle la
-- ligne a été écrite — l'application, une fonction serveur, une correction à
-- la main ; elle est dans la même transaction que l'événement, donc jamais
-- envoyée pour une écriture qui échoue ensuite ; et la règle se lit ici d'un
-- seul tenant plutôt qu'éparpillée dans trente écrans.
--
-- LA PORTÉE COMPTE AUTANT QUE LE RÔLE. Un commandant de division n'est
-- prévenu que pour SA division, un commandant de promotion et un commandant
-- de brigade que pour LEUR promotion. Sans cela, chaque absence sonnerait
-- chez tout le monde et plus personne ne regarderait ses notifications.
-- ============================================================================

-- ============================================================================
-- 1. À QUI — les destinataires, résolus une fois pour toutes
-- ============================================================================

-- Un compte désactivé ne reçoit rien : la notification resterait non lue
-- pour l'éternité et fausserait le compteur de celui qui reprendra le poste.
create or replace function socle.les_administrateurs()
returns setof uuid
language sql security definer stable
set search_path = socle, public
as $$
  select id from socle.profiles where role = 'admin' and actif;
$$;

create or replace function socle.par_role_logistique(p_role text)
returns setof uuid
language sql security definer stable
set search_path = socle, public
as $$
  select id from socle.profiles
  where role_logistique = p_role::socle.user_role and actif;
$$;

-- Les commandants dont relève une phase : celui de sa division, celui de sa
-- promotion, et — si on le demande — celui de sa brigade.
create or replace function scolarite.commandants_de_la_classe(
  p_classe_id uuid,
  p_avec_brigade boolean default false
)
returns setof uuid
language sql security definer stable
set search_path = scolarite, socle, public
as $$
  select p.id
  from socle.profiles p
  join scolarite.classes c on c.id = p_classe_id
  where p.actif
    and (
      (p.role = 'chef_division' and p.division_id = c.division_id)
      or (
        p.role = 'commandant_promotion'
        and p.promotion_id is not null
        and p.promotion_id = c.promotion_id
      )
      or (
        p_avec_brigade
        and p.role = 'commandant_brigade'
        and p.promotion_id is not null
        and p.promotion_id = c.promotion_id
      )
    );
$$;

grant execute on function socle.les_administrateurs() to authenticated;
grant execute on function socle.par_role_logistique(text) to authenticated;
grant execute on function scolarite.commandants_de_la_classe(uuid, boolean)
  to authenticated;

-- ============================================================================
-- 2. COMMENT — un seul point d'écriture
-- ============================================================================
-- `type` sert à l'icône et à la couleur côté application : « carburant »,
-- « maintenance », « armement » ont la leur, tout le reste tombe sur
-- « systeme ».
create or replace function socle.notifier(
  p_destinataires uuid[],
  p_type text,
  p_titre text,
  p_message text
)
returns void
language sql security definer
set search_path = socle, public
as $$
  insert into socle.notifications (profile_id, type, title, message)
  select distinct d, p_type, p_titre, p_message
  from unnest(p_destinataires) as d
  where d is not null;
$$;

-- Le nom d'un élève, tel qu'on le dit — pour que le message se lise sans
-- avoir à ouvrir l'écran.
create or replace function scolarite.nom_de_l_apprenant(p_id uuid)
returns text
language sql security definer stable
set search_path = scolarite, public
as $$
  select coalesce(trim(prenom || ' ' || nom), 'un élève')
  from scolarite.apprenants where id = p_id;
$$;

-- ============================================================================
-- 3. LA SCOLARITÉ
-- ============================================================================

-- --- Une absence : l'administrateur, et le commandement de la phase --------
create or replace function scolarite.notifier_absence()
returns trigger language plpgsql security definer
set search_path = scolarite, socle, public
as $$
begin
  perform socle.notifier(
    array(select socle.les_administrateurs())
      || array(select scolarite.commandants_de_la_classe(new.classe_id)),
    'systeme',
    'Absence enregistrée',
    scolarite.nom_de_l_apprenant(new.apprenant_id)
      || ' est porté absent du ' || to_char(new.date_debut, 'DD/MM/YYYY')
      || ' au ' || to_char(new.date_fin, 'DD/MM/YYYY') || '.'
  );
  return new;
end $$;

drop trigger if exists notifier_absence on scolarite.absences;
create trigger notifier_absence after insert on scolarite.absences
for each row execute function scolarite.notifier_absence();

-- --- Une consultation : le commandement toujours, l'urgence plus largement -
create or replace function scolarite.notifier_consultation()
returns trigger language plpgsql security definer
set search_path = scolarite, socle, public
as $$
declare
  urgence boolean := (new.type = 'urgence');
  qui uuid[];
begin
  -- Le commandant de brigade ne suit pas les consultations de routine ; une
  -- urgence, si — un élève évacué, il doit le savoir sans délai.
  qui := array(
    select scolarite.commandants_de_la_classe(new.classe_id, urgence)
  );
  if urgence then
    qui := qui || array(select socle.les_administrateurs());
  end if;

  perform socle.notifier(
    qui,
    'systeme',
    case when urgence then 'Consultation d''URGENCE' else 'Consultation médicale' end,
    scolarite.nom_de_l_apprenant(new.apprenant_id)
      || case when urgence
           then ' est présenté en urgence au service de santé.'
           else ' est présenté au service de santé le '
                || to_char(new.date_souhaitee, 'DD/MM/YYYY') || '.'
         end
  );
  return new;
end $$;

drop trigger if exists notifier_consultation on scolarite.consultations_medicales;
create trigger notifier_consultation
after insert on scolarite.consultations_medicales
for each row execute function scolarite.notifier_consultation();

-- --- Le traitement d'un consultant : le commandement de la phase -----------
create or replace function scolarite.notifier_consultation_traitee()
returns trigger language plpgsql security definer
set search_path = scolarite, socle, public
as $$
begin
  if new.statut = 'terminee' and old.statut is distinct from 'terminee' then
    perform socle.notifier(
      array(select scolarite.commandants_de_la_classe(new.classe_id)),
      'systeme',
      'Consultation traitée',
      scolarite.nom_de_l_apprenant(new.apprenant_id)
        || ' a été reçu par le service de santé.'
    );
  end if;
  return new;
end $$;

drop trigger if exists notifier_consultation_traitee
  on scolarite.consultations_medicales;
create trigger notifier_consultation_traitee
after update on scolarite.consultations_medicales
for each row execute function scolarite.notifier_consultation_traitee();

-- --- La suite d'une demande de suppression de note -------------------------
-- Celui qui a demandé doit savoir ce qu'il en est advenu. On prévient le
-- demandeur lui-même : c'est lui qui attend la réponse, quel que soit son
-- poste.
create or replace function scolarite.notifier_suite_demande_suppression()
returns trigger language plpgsql security definer
set search_path = scolarite, socle, public
as $$
begin
  -- Rejet : la marque s'efface, la note reste.
  if tg_op = 'UPDATE'
     and old.deletion_requested_at is not null
     and new.deletion_requested_at is null then
    perform socle.notifier(
      array[old.deletion_requested_by],
      'systeme',
      'Demande de suppression rejetée',
      'La note dont vous aviez demandé la suppression est conservée.'
    );
  end if;
  return new;
end $$;

drop trigger if exists notifier_suite_demande_suppression on scolarite.notes;
create trigger notifier_suite_demande_suppression
after update on scolarite.notes
for each row execute function scolarite.notifier_suite_demande_suppression();

create or replace function scolarite.notifier_suppression_note()
returns trigger language plpgsql security definer
set search_path = scolarite, socle, public
as $$
begin
  if old.deletion_requested_by is not null then
    perform socle.notifier(
      array[old.deletion_requested_by],
      'systeme',
      'Suppression validée',
      'La note dont vous aviez demandé la suppression a été supprimée.'
    );
  end if;
  return old;
end $$;

drop trigger if exists notifier_suppression_note on scolarite.notes;
create trigger notifier_suppression_note before delete on scolarite.notes
for each row execute function scolarite.notifier_suppression_note();

-- --- Le service de santé : dépenses et réapprovisionnements ---------------
create or replace function scolarite.notifier_depense()
returns trigger language plpgsql security definer
set search_path = scolarite, socle, public
as $$
begin
  perform socle.notifier(
    array(select socle.les_administrateurs()),
    'systeme',
    'Dépense enregistrée',
    'Une dépense de ' || new.categorie || ' a été portée au '
      || to_char(new.date_depense, 'DD/MM/YYYY') || '.'
  );
  return new;
end $$;

drop trigger if exists notifier_depense on scolarite.depenses;
create trigger notifier_depense after insert on scolarite.depenses
for each row execute function scolarite.notifier_depense();

create or replace function scolarite.notifier_reapprovisionnement()
returns trigger language plpgsql security definer
set search_path = scolarite, socle, public
as $$
begin
  perform socle.notifier(
    array(select socle.les_administrateurs()),
    'systeme',
    'Réapprovisionnement demandé',
    'La pharmacie demande un réapprovisionnement, daté du '
      || to_char(new.date_demande, 'DD/MM/YYYY') || '.'
  );
  return new;
end $$;

drop trigger if exists notifier_reapprovisionnement
  on scolarite.demandes_reapprovisionnement;
create trigger notifier_reapprovisionnement
after insert on scolarite.demandes_reapprovisionnement
for each row execute function scolarite.notifier_reapprovisionnement();

-- ============================================================================
-- 4. LE SOUTIEN TECHNIQUE
-- ============================================================================

create or replace function logistique.immatriculation(p_vehicule_id bigint)
returns text
language sql security definer stable
set search_path = logistique, public
as $$
  select coalesce(immatriculation, 'un véhicule')
  from logistique.vehicule where id = p_vehicule_id;
$$;

-- --- Le parc ---------------------------------------------------------------
create or replace function logistique.notifier_reparation()
returns trigger language plpgsql security definer
set search_path = logistique, socle, public
as $$
begin
  perform socle.notifier(
    array(select socle.les_administrateurs())
      || array(select socle.par_role_logistique('chef_soutien_technique')),
    'maintenance',
    'Véhicule en réparation',
    logistique.immatriculation(new.vehicule_id) || ' est entré en réparation.'
  );
  return new;
end $$;

drop trigger if exists notifier_reparation on logistique.reparation;
create trigger notifier_reparation after insert on logistique.reparation
for each row execute function logistique.notifier_reparation();

create or replace function logistique.notifier_hors_service()
returns trigger language plpgsql security definer
set search_path = logistique, socle, public
as $$
begin
  if new.etat = 'hors_service' and old.etat is distinct from 'hors_service' then
    perform socle.notifier(
      array(select socle.les_administrateurs()),
      'maintenance',
      'Véhicule hors service',
      new.immatriculation || ' est déclaré hors service.'
    );
  end if;
  return new;
end $$;

drop trigger if exists notifier_hors_service on logistique.vehicule;
create trigger notifier_hors_service after update on logistique.vehicule
for each row execute function logistique.notifier_hors_service();

create or replace function logistique.notifier_vidange()
returns trigger language plpgsql security definer
set search_path = logistique, socle, public
as $$
begin
  perform socle.notifier(
    array(select socle.par_role_logistique('chef_soutien_technique')),
    'maintenance',
    'Vidange enregistrée',
    logistique.immatriculation(new.vehicule_id) || ' a été vidangé.'
  );
  return new;
end $$;

drop trigger if exists notifier_vidange on logistique.vidange;
create trigger notifier_vidange after insert on logistique.vidange
for each row execute function logistique.notifier_vidange();

create or replace function logistique.notifier_mouvement()
returns trigger language plpgsql security definer
set search_path = logistique, socle, public
as $$
begin
  perform socle.notifier(
    array(select socle.par_role_logistique('chef_soutien_technique')),
    'maintenance',
    'Mouvement de véhicule',
    logistique.immatriculation(new.vehicule_id) || ' — ' || new.objet || '.'
  );
  return new;
end $$;

drop trigger if exists notifier_mouvement on logistique.mouvement;
create trigger notifier_mouvement after insert on logistique.mouvement
for each row execute function logistique.notifier_mouvement();

-- --- Le carburant ----------------------------------------------------------
create or replace function logistique.notifier_distribution()
returns trigger language plpgsql security definer
set search_path = logistique, socle, public
as $$
begin
  perform socle.notifier(
    array(select socle.les_administrateurs())
      || array(select socle.par_role_logistique('chef_soutien_technique')),
    'carburant',
    'Distribution de carburant',
    new.qte_percue || ' L de ' || new.type_carburant || ' servis à '
      || coalesce(new.destinataire, 'un bénéficiaire') || '.'
  );
  return new;
end $$;

drop trigger if exists notifier_distribution on logistique.distribution;
create trigger notifier_distribution after insert on logistique.distribution
for each row execute function logistique.notifier_distribution();

create or replace function logistique.notifier_depotage()
returns trigger language plpgsql security definer
set search_path = logistique, socle, public
as $$
begin
  perform socle.notifier(
    array(select socle.les_administrateurs()),
    'carburant',
    'Dépotage de soute',
    new.quantite_recue || ' L de ' || new.type_carburant || ' reçus en soute.'
  );
  return new;
end $$;

drop trigger if exists notifier_depotage on logistique.depotage;
create trigger notifier_depotage after insert on logistique.depotage
for each row execute function logistique.notifier_depotage();

-- --- L'armement ------------------------------------------------------------
create or replace function logistique.notifier_dotation_arme()
returns trigger language plpgsql security definer
set search_path = logistique, socle, public
as $$
begin
  perform socle.notifier(
    array(select socle.par_role_logistique('chef_soutien_technique')),
    'armement',
    'Bon d''arme établi',
    'Une arme a été remise à ' || new.beneficiaire_matricule || '.'
  );
  return new;
end $$;

drop trigger if exists notifier_dotation_arme on logistique.dotation_arme;
create trigger notifier_dotation_arme after insert on logistique.dotation_arme
for each row execute function logistique.notifier_dotation_arme();

-- --- L'officier adjoint ----------------------------------------------------
create or replace function logistique.notifier_activite()
returns trigger language plpgsql security definer
set search_path = logistique, socle, public
as $$
begin
  perform socle.notifier(
    array(select socle.les_administrateurs()),
    'activite',
    'Activité créée',
    new.titre || ' a été inscrite au programme.'
  );
  return new;
end $$;

drop trigger if exists notifier_activite on logistique.activite;
create trigger notifier_activite after insert on logistique.activite
for each row execute function logistique.notifier_activite();

-- Une tâche terminée attend d'être validée par l'officier adjoint ; une fois
-- validée, elle remonte à l'administrateur. Deux moments, deux destinataires.
create or replace function logistique.notifier_tache()
returns trigger language plpgsql security definer
set search_path = logistique, socle, public
as $$
begin
  if new.statut = 'terminee' and old.statut is distinct from 'terminee' then
    perform socle.notifier(
      array(select socle.par_role_logistique('officier_adjoint')),
      'activite',
      'Tâche à valider',
      new.description || ' — le service déclare avoir terminé.'
    );
  elsif new.statut = 'validee' and old.statut is distinct from 'validee' then
    perform socle.notifier(
      array(select socle.les_administrateurs()),
      'activite',
      'Tâche validée',
      new.description || ' a été validée.'
    );
  end if;
  return new;
end $$;

drop trigger if exists notifier_tache on logistique.tache_activite;
create trigger notifier_tache after update on logistique.tache_activite
for each row execute function logistique.notifier_tache();

-- ============================================================================
-- Contrôle : tous les déclencheurs de notification en place.
-- ============================================================================
select event_object_schema as schema, event_object_table as "table",
       trigger_name, action_timing, event_manipulation
from information_schema.triggers
where trigger_name like 'notifier_%'
order by 1, 2, 3;
