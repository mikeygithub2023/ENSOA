-- ============================================================================
-- SCOLARITÉ (ENSOA GSES) — repris de 020_demande_suppression_apprenant.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- Migration : comme pour les notes (016), un non-administrateur ne supprime
-- plus un apprenant directement — il déclenche une demande de suppression,
-- qui notifie tous les administrateurs. Seul un administrateur peut ensuite
-- confirmer (suppression réelle) ou rejeter (annule la demande) la demande.
-- La suppression directe reste réservée à l'administrateur (comme la
-- migration 015 pour les notes) : la politique "for all" du chef de
-- division est scindée en insertion + modification seulement.

alter table scolarite.apprenants add column deletion_requested_at timestamptz;
alter table scolarite.apprenants
  add column deletion_requested_by uuid references socle.profiles (id);

drop policy if exists apprenants_write_chef_division on scolarite.apprenants;

create policy apprenants_insert_chef_division on scolarite.apprenants
  for insert to authenticated
  with check (
    socle.current_role() = 'chef_division'
    and division_id = socle.current_division()
  );

create policy apprenants_update_chef_division on scolarite.apprenants
  for update to authenticated
  using (
    socle.current_role() = 'chef_division'
    and division_id = socle.current_division()
  )
  with check (
    socle.current_role() = 'chef_division'
    and division_id = socle.current_division()
  );

alter table socle.notifications
  add column apprenant_id uuid references scolarite.apprenants (id) on delete cascade;

create function scolarite.notify_admins_on_apprenant_deletion_request()
returns trigger
language plpgsql
security definer
set search_path = scolarite, socle, public
as $$
declare
  requester_nom text;
  apprenant_nom text;
begin
  if new.deletion_requested_at is not null and old.deletion_requested_at is null then
    select trim(prenom || ' ' || nom) into requester_nom
    from socle.profiles where id = new.deletion_requested_by;

    apprenant_nom := trim(new.prenom || ' ' || new.nom);

    insert into socle.notifications (profile_id, type, title, message, apprenant_id)
    select
      p.id,
      'apprenant_deletion_request',
      'Suppression d''apprenant demandée',
      coalesce(requester_nom, 'Un utilisateur') || ' demande la suppression de la fiche de '
        || coalesce(apprenant_nom, 'un apprenant') || '.',
      new.id
    from socle.profiles p
    where p.role = 'admin';
  end if;

  return new;
end;
$$;

create trigger notify_admins_on_apprenant_deletion_request
  after update on scolarite.apprenants
  for each row execute function scolarite.notify_admins_on_apprenant_deletion_request();
