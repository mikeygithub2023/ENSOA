-- ============================================================================
-- SCOLARITÉ (ENSOA GSES) — repris de 045_notification_devoir_eleves.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- Migration : prévenir les élèves d'une classe/stage qu'un devoir les
-- attend.
--
-- Même mécanique que les notifications déjà en place (migrations 016, 020 et
-- 031) : un trigger `security definer` insère une ligne par destinataire.
-- `notifications` n'a toujours aucune politique d'insertion cliente — elle
-- n'est alimentée que par ces triggers, et chacun ne lit que les siennes.
--
-- Le trigger ne porte pas sur la création du devoir mais sur sa première
-- question. Un devoir se crée en deux temps : la fiche d'abord, le QCM
-- ensuite. Prévenir dès la fiche enverrait l'élève vers un devoir vide ;
-- on attend donc qu'il ait quelque chose à composer.
--
-- L'auteur reprend son QCM autant de fois qu'il le veut : l'éditeur efface
-- les questions et les réinsère à chaque enregistrement, d'où la garde qui
-- vérifie qu'aucune notification ne porte déjà sur ce devoir. La classe
-- n'est prévenue qu'une fois.

alter table socle.notifications
  add column cours_id uuid references scolarite.cours (id) on delete cascade;

create index notifications_cours_idx on socle.notifications (cours_id);

create function scolarite.notify_eleves_on_devoir()
returns trigger
language plpgsql
security definer
set search_path = scolarite, socle, public
as $$
declare
  devoir scolarite.cours%rowtype;
  matiere_nom text;
begin
  select * into devoir from scolarite.cours where id = new.devoir_id;

  -- Une question orpheline ou rattachée à autre chose qu'un devoir ne
  -- concerne personne.
  if devoir.id is null or devoir.type <> 'devoir' then
    return new;
  end if;

  if exists (
    select 1 from socle.notifications n where n.cours_id = devoir.id
  ) then
    return new;
  end if;

  select m.nom into matiere_nom
  from scolarite.matieres m where m.id = devoir.matiere_id;

  -- Seuls les apprenants dotés d'un espace élève sont destinataires : les
  -- autres n'ont pas de profil auquel adresser la notification.
  insert into socle.notifications (
    profile_id, type, title, message, cours_id
  )
  select
    a.profile_id,
    'devoir',
    'Nouveau devoir',
    'Le devoir « ' || devoir.titre || ' »'
      || coalesce(' (' || matiere_nom || ')', '')
      || ' vous a été donné'
      || coalesce(
           ', à composer avant le '
             || to_char(devoir.date_remise, 'DD/MM/YYYY'),
           ''
         )
      || '.',
    devoir.id
  from scolarite.apprenants a
  where a.classe_id = devoir.classe_id
    and a.profile_id is not null;

  return new;
end;
$$;

create trigger notify_eleves_on_devoir
  after insert on scolarite.qcm_questions
  for each row execute function scolarite.notify_eleves_on_devoir();
