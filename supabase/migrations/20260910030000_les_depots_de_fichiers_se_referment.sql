-- ============================================================================
-- Les dépôts de fichiers se referment.
--
-- FAILLE CORRIGÉE ICI — vérifiée contre la base : un compte sans privilège
-- voyait les 7 objets stockés.
--
-- Les deux dépôts n'avaient qu'un prédicat : le nom du dépôt.
--
--   for all to authenticated using (bucket_id = 'apprenant-photos')
--
-- Ni propriétaire, ni chemin, ni division. Et `for all` englobe `delete` :
-- **un élève pouvait effacer la photo de tous les apprenants de l'école**,
-- télécharger celles de tout le monde, ou déposer des fichiers arbitraires.
-- Le caractère privé du dépôt n'y changeait rien : il supprime l'URL
-- publique, pas la politique.
--
-- COMMENT ON S'Y PREND. Les fichiers sont nommés `<uuid>.<extension>` à la
-- racine du dépôt — l'identifiant de l'apprenant pour une photo, celui du
-- cours pour un document (`apprenants_repository.dart:352`,
-- `cours_repository.dart:107`). On retrouve donc la ligne parente, et on
-- s'adosse à SA politique plutôt que de réécrire le cloisonnement :
--
--   * voir une photo = voir la fiche de l'apprenant ;
--   * la remplacer ou l'effacer = commander cet apprenant.
--
-- `scolarite.apprenants` et `scolarite.cours` portent déjà des politiques
-- justes, par division et par phase. Les recopier ici, c'est se condamner à
-- les faire diverger ; le `exists` ci-dessous hérite des leurs, qui
-- s'appliquent puisque la politique s'évalue sous l'identité de l'appelant.
-- ============================================================================

-- --- Photos des apprenants --------------------------------------------------
drop policy if exists apprenant_photos_select on storage.objects;
drop policy if exists apprenant_photos_write on storage.objects;

create policy apprenant_photos_select on storage.objects
  for select to authenticated
  using (
    bucket_id = 'apprenant-photos'
    and exists (
      select 1 from scolarite.apprenants a
      where a.id::text = split_part(storage.objects.name, '.', 1)
    )
  );

create policy apprenant_photos_write on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'apprenant-photos'
    and scolarite.commande_l_apprenant(
      nullif(split_part(name, '.', 1), '')::uuid)
  );

create policy apprenant_photos_update on storage.objects
  for update to authenticated
  using (
    bucket_id = 'apprenant-photos'
    and scolarite.commande_l_apprenant(
      nullif(split_part(storage.objects.name, '.', 1), '')::uuid)
  );

create policy apprenant_photos_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'apprenant-photos'
    and scolarite.commande_l_apprenant(
      nullif(split_part(storage.objects.name, '.', 1), '')::uuid)
  );

-- --- Documents de cours -----------------------------------------------------
drop policy if exists cours_documents_select on storage.objects;
drop policy if exists cours_documents_write on storage.objects;

create policy cours_documents_select on storage.objects
  for select to authenticated
  using (
    bucket_id = 'cours-documents'
    and exists (
      select 1 from scolarite.cours c
      where c.id::text = split_part(storage.objects.name, '.', 1)
    )
  );

-- Déposer, remplacer, retirer un document relève de qui commande la phase à
-- laquelle le cours est rattaché — et de l'administrateur, que
-- `commande_la_phase` reconnaît déjà.
create policy cours_documents_write on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'cours-documents'
    and exists (
      select 1 from scolarite.cours c
      where c.id::text = split_part(name, '.', 1)
        and scolarite.commande_la_phase(c.classe_id)
    )
  );

create policy cours_documents_update on storage.objects
  for update to authenticated
  using (
    bucket_id = 'cours-documents'
    and exists (
      select 1 from scolarite.cours c
      where c.id::text = split_part(storage.objects.name, '.', 1)
        and scolarite.commande_la_phase(c.classe_id)
    )
  );

create policy cours_documents_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'cours-documents'
    and exists (
      select 1 from scolarite.cours c
      where c.id::text = split_part(storage.objects.name, '.', 1)
        and scolarite.commande_la_phase(c.classe_id)
    )
  );

-- ============================================================================
-- Contrôle : doit retourner 0 ligne.
-- Une politique de stockage qui n'aurait que le nom du dépôt pour prédicat.
-- ============================================================================
select policyname, cmd
from pg_policies
where schemaname = 'storage'
  and coalesce(qual, with_check, '') !~ 'exists|commande_';
