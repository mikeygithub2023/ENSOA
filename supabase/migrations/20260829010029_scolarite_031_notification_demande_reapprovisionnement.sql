-- ============================================================================
-- SCOLARITÉ (ENSOA GSES) — repris de 031_notification_demande_reapprovisionnement.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- Migration : prévenir l'administrateur dès qu'une demande de
-- réapprovisionnement de la pharmacie est établie.
--
-- Même mécanique que les demandes de suppression (migrations 016 et 020) :
-- un trigger `security definer` insère une notification par administrateur.
-- La table `notifications` n'a toujours aucune politique d'insertion
-- cliente — elle n'est alimentée que par ces triggers.
--
-- Contrairement aux demandes de suppression, celle-ci est purement
-- informative : il n'y a rien à confirmer ni à rejeter, l'administrateur
-- consulte la fiche dans la rubrique « Demandes de réapprovisionnement » de
-- la pharmacie.

alter table socle.notifications
  add column demande_reapprovisionnement_id uuid
    references scolarite.demandes_reapprovisionnement (id) on delete cascade;

create function scolarite.notify_admins_on_demande_reapprovisionnement()
returns trigger
language plpgsql
security definer
set search_path = scolarite, socle, public
as $$
declare
  demandeur_nom text;
begin
  select trim(prenom || ' ' || nom) into demandeur_nom
  from socle.profiles where id = new.created_by;

  -- Les lignes de la fiche sont insérées après celle-ci : le nombre de
  -- médicaments commandés n'est pas encore connu ici, et n'est donc pas
  -- repris dans le message.
  insert into socle.notifications (
    profile_id, type, title, message, demande_reapprovisionnement_id
  )
  select
    p.id,
    'demande_reapprovisionnement',
    'Demande de réapprovisionnement',
    coalesce(demandeur_nom, 'Le service médical')
      || ' a établi une demande de réapprovisionnement de la pharmacie datée du '
      || to_char(new.date_demande, 'DD/MM/YYYY') || '.',
    new.id
  from socle.profiles p
  where p.role = 'admin';

  return new;
end;
$$;

create trigger notify_admins_on_demande_reapprovisionnement
  after insert on scolarite.demandes_reapprovisionnement
  for each row execute function scolarite.notify_admins_on_demande_reapprovisionnement();
