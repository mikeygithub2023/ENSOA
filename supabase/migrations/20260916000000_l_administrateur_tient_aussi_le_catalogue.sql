-- ============================================================================
-- L'administrateur peut compléter le catalogue des véhicules.
--
-- `marque_vhl`, `modele_vhl` et `type_vhl` n'étaient ouverts en écriture
-- qu'au garage et au chef du soutien technique. L'administrateur en était
-- exclu — un oubli, resté invisible tant que personne n'avait créé de
-- véhicule depuis ce compte.
--
-- Il s'est vu à l'import d'un parc existant : importer un véhicule crée au
-- passage sa marque, son modèle et son type s'ils manquent. L'administrateur
-- se heurtait donc au catalogue avant même d'atteindre le parc.
--
-- Ces trois tables sont un catalogue, pas un registre : y ajouter
-- « MITSUBISHI » n'engage rien et ne révèle rien. L'administrateur a reçu la
-- lecture et l'écriture sur toutes les rubriques de l'ERP ; rien ne
-- justifiait que celle-ci fasse exception.
--
-- Les politiques sont `for all` sans `with check` : PostgreSQL applique
-- alors `using` aussi à l'insertion. On les réécrit entièrement plutôt que
-- d'en ajouter une quatrième, pour qu'un seul endroit dise qui tient le
-- catalogue.
-- ============================================================================

drop policy if exists "ecriture marque" on logistique.marque_vhl;
create policy "ecriture marque" on logistique.marque_vhl
  for all to authenticated
  using (
    socle.est_administrateur()
    or socle.current_user_role() in ('garage', 'chef_soutien_technique')
  )
  with check (
    socle.est_administrateur()
    or socle.current_user_role() in ('garage', 'chef_soutien_technique')
  );

drop policy if exists "ecriture modele" on logistique.modele_vhl;
create policy "ecriture modele" on logistique.modele_vhl
  for all to authenticated
  using (
    socle.est_administrateur()
    or socle.current_user_role() in ('garage', 'chef_soutien_technique')
  )
  with check (
    socle.est_administrateur()
    or socle.current_user_role() in ('garage', 'chef_soutien_technique')
  );

drop policy if exists "ecriture type_vhl" on logistique.type_vhl;
create policy "ecriture type_vhl" on logistique.type_vhl
  for all to authenticated
  using (
    socle.est_administrateur()
    or socle.current_user_role() in ('garage', 'chef_soutien_technique')
  )
  with check (
    socle.est_administrateur()
    or socle.current_user_role() in ('garage', 'chef_soutien_technique')
  );

-- ============================================================================
-- Contrôle : doit retourner 0 ligne.
-- Une table du catalogue dont l'écriture resterait fermée à l'administrateur.
-- ============================================================================
select tablename, policyname
from pg_policies
where schemaname = 'logistique'
  and tablename in ('marque_vhl', 'modele_vhl', 'type_vhl')
  and cmd = 'ALL'
  and coalesce(with_check, '') not like '%est_administrateur%';
