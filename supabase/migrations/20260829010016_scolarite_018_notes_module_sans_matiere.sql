-- ============================================================================
-- SCOLARITÉ (ENSOA GSES) — repris de 018_notes_module_sans_matiere.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- Migration : pour un contrôle de type "module", la note est liée
-- directement au module et à l'apprenant — pas de matière intermédiaire
-- (contrairement au contrôle continu/examen, où un même contrôle couvre
-- plusieurs matières). matiere_id devient donc optionnel.

alter table scolarite.notes alter column matiere_id drop not null;

-- La contrainte unique (controle_id, apprenant_id, matiere_id) ne détecte
-- jamais les doublons quand matiere_id est NULL (deux NULL ne sont jamais
-- égaux) : un index unique partiel couvre ce cas pour les notes de module.
create unique index notes_controle_apprenant_sans_matiere_uq
  on scolarite.notes (controle_id, apprenant_id)
  where matiere_id is null;

-- Le message de notification doit s'adapter : une note de module n'a pas
-- de matière, on utilise alors le libellé du contrôle (le module) à la
-- place.
create or replace function scolarite.notify_admins_on_deletion_request()
returns trigger
language plpgsql
security definer
set search_path = scolarite, socle, public
as $$
declare
  requester_nom text;
  matiere_nom text;
  apprenant_nom text;
  controle_libelle text;
  sujet text;
begin
  if new.deletion_requested_at is not null and old.deletion_requested_at is null then
    select trim(prenom || ' ' || nom) into requester_nom
    from socle.profiles where id = new.deletion_requested_by;

    select trim(prenom || ' ' || nom) into apprenant_nom
    from scolarite.apprenants where id = new.apprenant_id;

    if new.matiere_id is not null then
      select nom into matiere_nom from scolarite.matieres where id = new.matiere_id;
      sujet := 'en ' || coalesce(matiere_nom, 'une matière');
    else
      select libelle into controle_libelle from scolarite.controles where id = new.controle_id;
      sujet := 'pour le module ' || coalesce(controle_libelle, '');
    end if;

    insert into socle.notifications (profile_id, type, title, message, note_id)
    select
      p.id,
      'note_deletion_request',
      'Suppression de note demandée',
      coalesce(requester_nom, 'Un utilisateur') || ' demande la suppression de la note de '
        || coalesce(apprenant_nom, 'un apprenant') || ' ' || sujet || '.',
      new.id
    from socle.profiles p
    where p.role = 'admin';
  end if;

  return new;
end;
$$;
