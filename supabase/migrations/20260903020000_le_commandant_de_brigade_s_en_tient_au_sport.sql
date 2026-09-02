-- ============================================================================
-- Le Commandant de Brigade ne gère que le sport.
--
-- La migration précédente lui avait fermé les notes hors sport, mais lui
-- laissait la main sur les contrôles eux-mêmes : il pouvait créer un module
-- d'instruction générale ou en changer le coefficient, sans pouvoir y mettre
-- la moindre note. C'était une demi-mesure, et une demi-mesure sur des droits
-- n'a pas de sens : la limite porte désormais sur tout ce qui touche à
-- l'évaluation.
--
-- Ce qu'il garde : la LECTURE de tout le programme de ses phases — on ne
-- commande pas une promotion à l'aveugle —, et la main pleine sur le module
-- Sport, ses séances, ses barèmes et ses performances.
--
-- Ce qu'il garde aussi, et qui ne change pas : les cours, les devoirs et les
-- exercices de ses phases, qui ne sont pas des évaluations notées.
--
-- Le Commandant de Promotion, lui, n'est pas concerné : il tient l'ensemble.
--
-- Note : le module Sport d'une phase se crée par `assurer_module_sport`, qui
-- est `security definer`. Restreindre ses droits d'écriture ne l'empêche donc
-- pas de faire naître le module dont il a besoin.
-- ============================================================================

-- --- 1. Les contrôles -------------------------------------------------------
-- L'ancienne politique ne distinguait pas les deux postes.
drop policy if exists controles_write_commandant on scolarite.controles;

drop policy if exists controles_write_commandant_promotion on scolarite.controles;
create policy controles_write_commandant_promotion on scolarite.controles
  for all to authenticated
  using (
    socle.current_role() = 'commandant_promotion'
    and scolarite.commande_la_phase(classe_id)
  )
  with check (
    socle.current_role() = 'commandant_promotion'
    and scolarite.commande_la_phase(classe_id)
  );

drop policy if exists controles_write_commandant_brigade on scolarite.controles;
create policy controles_write_commandant_brigade on scolarite.controles
  for all to authenticated
  using (
    socle.current_role() = 'commandant_brigade'
    and scolarite.commande_la_phase(classe_id)
    and type = 'sport'
  )
  with check (
    socle.current_role() = 'commandant_brigade'
    and scolarite.commande_la_phase(classe_id)
    and type = 'sport'
  );

-- --- 2. Les sous-modules ----------------------------------------------------
-- Une séance sportive EST un sous-module du module Sport : c'est par là que
-- le Commandant de Brigade travaille. Les sous-modules des autres contrôles
-- lui restent en lecture seule.
drop policy if exists sous_modules_commandant on scolarite.sous_modules;

drop policy if exists sous_modules_select_commandant on scolarite.sous_modules;
create policy sous_modules_select_commandant on scolarite.sous_modules
  for select to authenticated
  using (
    exists (
      select 1 from scolarite.controles c
      where c.id = sous_modules.module_id
        and scolarite.commande_la_phase(c.classe_id)
    )
  );

drop policy if exists sous_modules_write_commandant_promotion on scolarite.sous_modules;
create policy sous_modules_write_commandant_promotion on scolarite.sous_modules
  for all to authenticated
  using (
    socle.current_role() = 'commandant_promotion'
    and exists (
      select 1 from scolarite.controles c
      where c.id = sous_modules.module_id
        and scolarite.commande_la_phase(c.classe_id)
    )
  )
  with check (
    socle.current_role() = 'commandant_promotion'
    and exists (
      select 1 from scolarite.controles c
      where c.id = sous_modules.module_id
        and scolarite.commande_la_phase(c.classe_id)
    )
  );

drop policy if exists sous_modules_write_commandant_brigade on scolarite.sous_modules;
create policy sous_modules_write_commandant_brigade on scolarite.sous_modules
  for all to authenticated
  using (
    socle.current_role() = 'commandant_brigade'
    and exists (
      select 1 from scolarite.controles c
      where c.id = sous_modules.module_id
        and c.type = 'sport'
        and scolarite.commande_la_phase(c.classe_id)
    )
  )
  with check (
    socle.current_role() = 'commandant_brigade'
    and exists (
      select 1 from scolarite.controles c
      where c.id = sous_modules.module_id
        and c.type = 'sport'
        and scolarite.commande_la_phase(c.classe_id)
    )
  );

-- ============================================================================
-- Contrôle : ce que chaque commandant peut écrire, table par table.
-- ============================================================================
select tablename, policyname, cmd
from pg_policies
where schemaname = 'scolarite'
  and tablename in ('controles', 'sous_modules', 'notes')
  and policyname like '%commandant%'
order by tablename, policyname;
