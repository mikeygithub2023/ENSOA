-- ============================================================================
-- Le Chef du Soutien Technique ne voit que son service.
--
-- La politique de lecture des profils, écrite au tout début du module
-- logistique, lui ouvrait TOUS les comptes de l'école : le commandant de
-- l'école, les commandants de division, de promotion et de brigade,
-- l'officier adjoint, le service de santé. Il y voyait des gens sur lesquels
-- il n'a aucune autorité, et dont l'organisation interne de la scolarité ne
-- le regarde pas.
--
-- Ses politiques de modification et de suppression, elles, étaient bornées
-- depuis toujours à `soutien_petrolier`, `garage` et `armurerie` — migration
-- 023. La lecture rattrape ce retard : il voit désormais exactement les
-- comptes sur lesquels il peut agir, et le sien.
--
-- Effet de bord assumé : là où l'application nomme l'auteur d'une action —
-- le journal d'audit, le soutier d'un imprimé de distribution —, une action
-- faite par quelqu'un hors de son service s'affichera « Auteur inconnu »
-- pour lui. C'est le prix d'un cloisonnement qui, sans cela, n'en serait pas
-- un.
-- ============================================================================

drop policy if exists "profil personnel" on socle.profiles;
create policy "profil personnel" on socle.profiles
  for select
  using (
    id = auth.uid()
    or (
      socle.current_user_role() = 'chef_soutien_technique'
      and role_logistique in ('soutien_petrolier', 'garage', 'armurerie')
    )
  );

-- Contrôle : ce que chaque poste du soutien technique voit de la table.
select policyname, cmd
from pg_policies
where schemaname = 'socle' and tablename = 'profiles'
order by cmd, policyname;
