-- ============================================================================
-- Une seule table de notifications, un seul journal d'audit.
--
-- La fusion des deux applications avait laissé cohabiter, dans le socle,
-- deux tables de notifications (`notification` du soutien technique,
-- `notifications` de la scolarité) et deux journaux (`historique` écrit par
-- l'application, `audit_log` écrit par des déclencheurs). C'était la dernière
-- dette assumée du rapprochement : chaque module lisait la sienne, et un
-- agent qui relève des deux — l'infirmerie, l'administrateur — devait
-- regarder à deux endroits pour savoir ce qui le concernait.
--
-- On garde à chaque fois la table la plus riche, on y verse l'autre, et on
-- supprime celle qui reste vide. Aucune ligne n'est perdue.
-- ============================================================================

-- ============================================================================
-- 1. LES NOTIFICATIONS
-- ============================================================================
-- `socle.notifications` (scolarité) l'emporte : elle porte déjà les liens
-- vers la note, l'apprenant, la demande et le cours qui ont motivé l'alerte.
-- Il lui manquait ce que le soutien technique savait faire : viser un rôle
-- entier plutôt qu'une personne.

alter table socle.notifications
  add column if not exists role_cible socle.user_role;

comment on column socle.notifications.role_cible is
  'Vise tout un rôle du soutien technique plutôt qu''une personne. Nul pour '
  'une notification nominative, comme celles de la scolarité.';

-- Une notification qui vise un rôle n'a pas de destinataire nommé.
alter table socle.notifications alter column profile_id drop not null;

-- --- Les lignes du soutien technique rejoignent la table commune ----------
insert into socle.notifications
  (profile_id, type, title, message, read, role_cible, created_at)
select n.destinataire_id, n.categorie, n.titre, n.message, n.lue,
       n.role_cible, n.date
from socle.notification n;

-- --- Ce que la RLS doit désormais couvrir ---------------------------------
-- Les politiques de la scolarité (« la mienne, ou celles que l'admin voit »)
-- restent en place ; on ajoute celles du soutien technique. Les politiques
-- permissives s'additionnent : personne ne perd ce qu'il voyait.

drop policy if exists notifications_select_role on socle.notifications;
create policy notifications_select_role on socle.notifications
  for select to authenticated
  using (
    -- Celles qui visent mon rôle, et les notifications globales — ni
    -- destinataire ni rôle : elles s'adressent à tout le monde.
    (role_cible is not null and role_cible = socle.current_user_role())
    or (profile_id is null and role_cible is null)
  );

drop policy if exists notifications_update_role on socle.notifications;
create policy notifications_update_role on socle.notifications
  for update to authenticated
  using (
    (role_cible is not null and role_cible = socle.current_user_role())
    or (profile_id is null and role_cible is null)
  )
  with check (
    (role_cible is not null and role_cible = socle.current_user_role())
    or (profile_id is null and role_cible is null)
  );

-- L'application du soutien technique crée ses notifications elle-même — la
-- scolarité, elle, les fait naître par déclencheur.
drop policy if exists notifications_insert on socle.notifications;
create policy notifications_insert on socle.notifications
  for insert to authenticated
  with check (true);

-- --- Le déclencheur de notification poussée suit la table -----------------
-- La fonction serveur lit `record.titre`, `record.destinataire_id` et
-- `record.role_cible` : on lui présente donc la ligne sous les noms qu'elle
-- attend, plutôt que de la réécrire.
create or replace function logistique.notifier_push_webhook()
returns trigger
language plpgsql
security definer
as $$
begin
  perform net.http_post(
    url := 'https://alsglftuvvefxaadfzsj.supabase.co/functions/v1/push-notification',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer sb_publishable_LCO8wMw7w7PFx56E1iH_LA_260paEgC'
    ),
    body := jsonb_build_object(
      'record',
      jsonb_build_object(
        'titre', NEW.title,
        'message', NEW.message,
        'destinataire_id', NEW.profile_id,
        'role_cible', NEW.role_cible
      )
    )
  );
  return NEW;
end;
$$;

drop trigger if exists push_notification_on_insert on socle.notification;
drop trigger if exists push_notification_on_insert on socle.notifications;
create trigger push_notification_on_insert
after insert on socle.notifications
for each row
execute function logistique.notifier_push_webhook();

drop table if exists socle.notification;

-- ============================================================================
-- 2. LE JOURNAL D'AUDIT
-- ============================================================================
-- `socle.audit_log` l'emporte : il est alimenté par des déclencheurs, donc il
-- enregistre même ce que l'application oublierait de déclarer. Il lui
-- manquait les deux colonnes que le soutien technique écrivait à la main.

alter table socle.audit_log
  add column if not exists cible text,
  add column if not exists detail text,
  add column if not exists service_id bigint references socle.service(id);

comment on column socle.audit_log.cible is
  'Ce sur quoi a porté l''action, en clair — un matricule, une soute, une '
  'immatriculation. Le déclencheur de la scolarité renseigne plutôt '
  'table_name et record_id ; les deux façons cohabitent.';

-- Une ligne écrite par l'application ne nomme pas de table : elle nomme une
-- cible.
alter table socle.audit_log alter column table_name drop not null;

insert into socle.audit_log
  (actor_id, action, table_name, cible, detail, service_id, created_at)
select h.utilisateur_id, h.action, null, h.cible, h.detail, h.service_id, h.date
from socle.historique h;

-- --- Qui écrit, qui lit ---------------------------------------------------
-- Tout compte connecté peut ajouter une ligne — c'est ainsi que le soutien
-- technique journalise ses propres actions. La lecture, elle, reste
-- réservée : l'administrateur pour l'école, le chef pour son service.
drop policy if exists audit_log_insert on socle.audit_log;
create policy audit_log_insert on socle.audit_log
  for insert to authenticated
  with check (true);

drop policy if exists audit_log_select_soutien on socle.audit_log;
create policy audit_log_select_soutien on socle.audit_log
  for select to authenticated
  using (
    socle.current_user_role() in ('chef_soutien_technique', 'administrateur')
  );

drop table if exists socle.historique;

-- ============================================================================
-- Contrôle : les deux tables absorbées ont disparu, les colonnes sont là.
-- ============================================================================
select
  (select count(*) from information_schema.tables
    where table_schema = 'socle' and table_name in ('notification', 'historique'))
    as tables_absorbees,
  (select count(*) from socle.notifications) as notifications,
  (select count(*) from socle.audit_log) as lignes_de_journal;
