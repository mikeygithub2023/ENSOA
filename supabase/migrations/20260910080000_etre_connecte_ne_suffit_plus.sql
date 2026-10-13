-- ============================================================================
-- Être connecté ne suffit plus : il faut être de l'école.
--
-- Vingt-deux politiques n'avaient qu'un prédicat : `auth.role() =
-- 'authenticated'`, ou `true`. Autrement dit : posséder un jeton quelconque.
--
-- Or le tableau de bord du projet montre que l'inscription libre est
-- ACTIVÉE. N'importe qui sur Internet, muni de la clé publishable — qui
-- voyage dans chaque APK et se lit en trente secondes —, se crée un compte,
-- confirme son adresse, et obtient un jeton `authenticated`. Il n'a aucun
-- rôle, donc la plupart des tables lui restent fermées. Mais ces vingt-deux
-- là s'ouvraient : le parc, les soutes et leurs niveaux, les dépotages, les
-- distributions nominatives de carburant, les réparations, et surtout les
-- MOUVEMENTS DE VÉHICULES — qui est sorti, quand, vers où, avec quel chef de
-- bord. Dans une école militaire, c'est du renseignement.
--
-- Désactiver l'inscription referme la porte d'entrée ; cette migration
-- referme les pièces. Les deux valent mieux qu'une seule : l'inscription
-- peut être rouverte un jour par mégarde, et un compte d'élève radié dont on
-- aurait oublié de retirer le rôle ne doit pas, lui non plus, lire le parc.
--
-- COMMENT. On ne retire aucune politique : on remplace leur prédicat par
-- « ce compte appartient-il à l'école », c'est-à-dire porte-t-il un rôle. La
-- commande `alter policy` préserve le reste — commande, rôles, nom —, ce qui
-- évite de recopier vingt-deux définitions et d'en abîmer une au passage.
--
-- CE QUE CELA NE CHANGE PAS : tout compte de l'école garde exactement ce
-- qu'il lisait. Le cloisonnement entre services reste à faire, table par
-- table, et il est noté au rapport d'audit ; ici on ne traite que la
-- frontière entre « l'école » et « le reste du monde ».
-- ============================================================================

create or replace function socle.est_de_l_ecole()
returns boolean
language sql
security definer
stable
set search_path = socle, public
as $$
  -- Les deux fonctions vérifient déjà `actif` : un compte désactivé n'est
  -- plus de l'école, et un compte sans profil ni rôle ne l'a jamais été.
  select socle.current_role() is not null
      or socle.current_user_role() is not null;
$$;

grant execute on function socle.est_de_l_ecole() to authenticated;

do $$
declare
  r record;
  n int := 0;
begin
  for r in
    select schemaname, tablename, policyname, qual, with_check
    from pg_policies
    where schemaname in ('socle', 'scolarite', 'logistique')
      and (coalesce(qual, '') ~ 'auth\.role\(\)' or coalesce(qual, '') = 'true')
  loop
    execute format(
      'alter policy %I on %I.%I using (socle.est_de_l_ecole())',
      r.policyname, r.schemaname, r.tablename);

    -- Une politique d'écriture porte aussi un `with check` ; le laisser plus
    -- large que le `using` permettrait d'insérer ce qu'on ne pourrait pas
    -- relire.
    if r.with_check is not null then
      execute format(
        'alter policy %I on %I.%I with check (socle.est_de_l_ecole())',
        r.policyname, r.schemaname, r.tablename);
    end if;

    n := n + 1;
  end loop;

  raise notice 'Politiques resserrées : %', n;
end $$;

-- ============================================================================
-- Contrôle : doit retourner 0 ligne.
-- Une politique qui se contenterait encore d'un jeton quelconque.
-- ============================================================================
select schemaname, tablename, policyname
from pg_policies
where schemaname in ('socle', 'scolarite', 'logistique')
  and (coalesce(qual, '') ~ 'auth\.role\(\)' or coalesce(qual, '') = 'true');
