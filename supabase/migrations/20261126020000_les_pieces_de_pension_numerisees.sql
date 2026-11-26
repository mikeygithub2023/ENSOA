-- ============================================================================
-- Les pièces du dossier de pension, numérisées.
--
-- Cocher « présente » disait qu'on avait vu la pièce ; on la garde
-- désormais : un scan (PDF, JPEG ou PNG, 10 Mo au plus) se joint à la ligne
-- du dossier, et se revoit depuis l'écran.
--
-- LE FICHIER SE RANGE SOUS `<apprenant>/<pièce>.<extension>`, dans un dépôt
-- privé. Le chemin dit à qui il appartient : la RLS du stockage le lit pour
-- donner exactement les droits du dossier de pension — le voir comme on
-- voit la ligne, le déposer comme on l'écrit (administrateur, chef de
-- division sur son effectif).
--
-- Rejouable.
-- ============================================================================

alter table scolarite.dossiers_pension
  add column if not exists fichier_path text,
  add column if not exists fichier_nom text;

comment on column scolarite.dossiers_pension.fichier_path is
  'Chemin du scan dans le dépôt dossiers-pension : <apprenant>/<pièce>.<ext>.';

insert into storage.buckets
  (id, name, public, file_size_limit, allowed_mime_types)
values (
  'dossiers-pension', 'dossiers-pension', false, 10485760,
  array['application/pdf', 'image/jpeg', 'image/png']
)
on conflict (id) do update
  set public = false,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- Le militaire dont relève un fichier, lu dans son chemin. Nul si le chemin
-- ne commence pas par un identifiant : la politique refuse alors, au lieu
-- d'échouer sur une conversion.
create or replace function scolarite.apprenant_du_fichier_pension(p_nom text)
returns uuid
language sql
immutable
as $$
  select case
    when split_part(p_nom, '/', 1)
         ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    then split_part(p_nom, '/', 1)::uuid
  end;
$$;

grant execute on function scolarite.apprenant_du_fichier_pension(text)
  to authenticated;

-- --- Voir : comme on voit la ligne du dossier -------------------------------
drop policy if exists dossiers_pension_fichiers_select on storage.objects;
create policy dossiers_pension_fichiers_select on storage.objects
  for select to authenticated
  using (
    bucket_id = 'dossiers-pension'
    and (
      socle.current_role() = 'admin'
      or socle.est_administrateur()
      or (
        socle.current_role() in ('chef_division', 'instructeur')
        and scolarite.releve_de_ma_division(
          scolarite.apprenant_du_fichier_pension(name))
      )
      or scolarite.commande_l_apprenant(
        scolarite.apprenant_du_fichier_pension(name))
      or exists (
        select 1 from scolarite.apprenants a
        where a.id = scolarite.apprenant_du_fichier_pension(name)
          and a.profile_id = auth.uid()
      )
    )
  );

-- --- Déposer, remplacer, retirer : comme on écrit la ligne -----------------
drop policy if exists dossiers_pension_fichiers_insert on storage.objects;
create policy dossiers_pension_fichiers_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'dossiers-pension'
    and (
      socle.current_role() = 'admin'
      or socle.est_administrateur()
      or (
        socle.current_role() = 'chef_division'
        and scolarite.releve_de_ma_division(
          scolarite.apprenant_du_fichier_pension(name))
      )
    )
  );

drop policy if exists dossiers_pension_fichiers_update on storage.objects;
create policy dossiers_pension_fichiers_update on storage.objects
  for update to authenticated
  using (
    bucket_id = 'dossiers-pension'
    and (
      socle.current_role() = 'admin'
      or socle.est_administrateur()
      or (
        socle.current_role() = 'chef_division'
        and scolarite.releve_de_ma_division(
          scolarite.apprenant_du_fichier_pension(name))
      )
    )
  );

drop policy if exists dossiers_pension_fichiers_delete on storage.objects;
create policy dossiers_pension_fichiers_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'dossiers-pension'
    and (
      socle.current_role() = 'admin'
      or socle.est_administrateur()
      or (
        socle.current_role() = 'chef_division'
        and scolarite.releve_de_ma_division(
          scolarite.apprenant_du_fichier_pension(name))
      )
    )
  );

notify pgrst, 'reload schema';

-- ============================================================================
-- Contrôle : une ligne — le dépôt privé, et 4 politiques.
-- ============================================================================
select
  (select public from storage.buckets where id = 'dossiers-pension')
    as depot_public,
  (select count(*) from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and policyname like 'dossiers_pension_fichiers_%') as politiques,
  (select count(*) from information_schema.columns
    where table_schema = 'scolarite' and table_name = 'dossiers_pension'
      and column_name in ('fichier_path', 'fichier_nom')) as colonnes;
