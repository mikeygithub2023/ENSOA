-- ============================================================================
-- LOGISTIQUE (ERP ENSOA) — repris de migration_023_chef_st_gere_son_service.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- ============================================================================
-- Le chef du Soutien Technique arme son propre service.
--
-- Réorganisation de l'ouverture des comptes : l'administrateur nomme les
-- chefs de service — Chef Soutien Technique, Poste de Police, Officier
-- Adjoint, Service Santé, et les autres administrateurs. Le chef du Soutien
-- Technique ouvre ensuite les comptes de son service : soutien pétrolier,
-- garage, armurerie. Il sait qui tient le dépôt, l'atelier et l'armurerie ;
-- l'administrateur ne le sait pas.
--
-- La création elle-même passe par la fonction `admin-create-user`, qui
-- s'exécute avec la clé de service et vérifie de son côté que l'appelant a
-- bien la charge du rôle demandé. Les politiques ci-dessous portent sur ce
-- que le chef peut faire ensuite : modifier et supprimer ces comptes.
--
-- La clause `with check` est la pièce essentielle : sans elle, le chef
-- pourrait ouvrir la fiche d'un de ses hommes et lui attribuer le rôle
-- d'administrateur — ou se l'attribuer à lui-même. Elle borne aussi bien la
-- ligne visée que la valeur écrite.
-- ============================================================================

create policy "profil chef st update" on socle.profiles
  for update
  using (
    socle.current_user_role() = 'chef_soutien_technique'
    and role_logistique in ('soutien_petrolier', 'garage', 'armurerie')
  )
  with check (
    socle.current_user_role() = 'chef_soutien_technique'
    and role_logistique in ('soutien_petrolier', 'garage', 'armurerie')
  );

create policy "profil chef st delete" on socle.profiles
  for delete
  using (
    socle.current_user_role() = 'chef_soutien_technique'
    and role_logistique in ('soutien_petrolier', 'garage', 'armurerie')
  );
