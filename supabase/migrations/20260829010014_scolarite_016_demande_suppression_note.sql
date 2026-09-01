-- ============================================================================
-- SCOLARITÉ (ENSOA GSES) — repris de 016_demande_suppression_note.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- Migration : un non-administrateur ne supprime plus une note directement
-- (verrouillé depuis la migration 015) — il déclenche une demande de
-- suppression. La note est marquée "Suppression demandée" et tous les
-- administrateurs reçoivent une notification ; seul un administrateur peut
-- ensuite confirmer (suppression réelle) ou rejeter (annule la demande) la
-- demande.

alter table scolarite.notes add column deletion_requested_at timestamptz;
alter table scolarite.notes
  add column deletion_requested_by uuid references socle.profiles (id);

-- Table générique de notifications par destinataire — réutilisable pour
-- d'autres types futurs, pas seulement les demandes de suppression de note.
create table socle.notifications (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references socle.profiles (id) on delete cascade,
  type text not null,
  title text not null,
  message text not null,
  note_id uuid references scolarite.notes (id) on delete cascade,
  read boolean not null default false,
  created_at timestamptz not null default now()
);

create index notifications_profile_idx on socle.notifications (profile_id);

alter table socle.notifications enable row level security;

create policy notifications_select_self on socle.notifications
  for select to authenticated
  using (profile_id = auth.uid());

create policy notifications_update_self on socle.notifications
  for update to authenticated
  using (profile_id = auth.uid())
  with check (profile_id = auth.uid());

create policy notifications_delete_self on socle.notifications
  for delete to authenticated
  using (profile_id = auth.uid());

-- Pas de politique d'insertion cliente : les notifications ne sont créées
-- que par le trigger ci-dessous (security definer, même schéma que
-- audit_trigger), pour tous les profils admin.
create function scolarite.notify_admins_on_deletion_request()
returns trigger
language plpgsql
security definer
set search_path = scolarite, socle, public
as $$
declare
  requester_nom text;
  matiere_nom text;
  apprenant_nom text;
begin
  if new.deletion_requested_at is not null and old.deletion_requested_at is null then
    select trim(prenom || ' ' || nom) into requester_nom
    from socle.profiles where id = new.deletion_requested_by;

    select nom into matiere_nom from scolarite.matieres where id = new.matiere_id;
    select trim(prenom || ' ' || nom) into apprenant_nom
    from scolarite.apprenants where id = new.apprenant_id;

    insert into socle.notifications (profile_id, type, title, message, note_id)
    select
      p.id,
      'note_deletion_request',
      'Suppression de note demandée',
      coalesce(requester_nom, 'Un utilisateur') || ' demande la suppression de la note de '
        || coalesce(apprenant_nom, 'un apprenant') || ' en ' || coalesce(matiere_nom, 'une matière') || '.',
      new.id
    from socle.profiles p
    where p.role = 'admin';
  end if;

  return new;
end;
$$;

create trigger notify_admins_on_note_deletion_request
  after update on scolarite.notes
  for each row execute function scolarite.notify_admins_on_deletion_request();

grant select, insert, update, delete on socle.notifications to authenticated;
