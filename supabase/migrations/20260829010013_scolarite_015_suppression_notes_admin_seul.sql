-- ============================================================================
-- SCOLARITÉ (ENSOA GSES) — repris de 015_suppression_notes_admin_seul.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- Migration : la suppression d'une note est réservée à l'administrateur.
--
-- Un chef de division peut modifier une note et voir l'indicateur "Note
-- modifiée" apparaître (la valeur précédente est conservée) — mais s'il
-- pouvait supprimer puis ressaisir la note, il contournerait ce suivi.
-- La politique "for all" du chef de division est donc scindée : il garde
-- l'insertion et la modification, mais perd la suppression.

drop policy if exists notes_write_chef_division on scolarite.notes;

create policy notes_insert_chef_division on scolarite.notes
  for insert to authenticated
  with check (
    exists (
      select 1 from scolarite.controles c
      where c.id = notes.controle_id
        and socle.current_role() = 'chef_division'
        and c.division_id = socle.current_division()
    )
  );

create policy notes_update_chef_division on scolarite.notes
  for update to authenticated
  using (
    exists (
      select 1 from scolarite.controles c
      where c.id = notes.controle_id
        and socle.current_role() = 'chef_division'
        and c.division_id = socle.current_division()
    )
  )
  with check (
    exists (
      select 1 from scolarite.controles c
      where c.id = notes.controle_id
        and socle.current_role() = 'chef_division'
        and c.division_id = socle.current_division()
    )
  );
