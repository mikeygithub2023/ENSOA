-- ============================================================================
-- Corriger ou supprimer un contrôle revient à l'administrateur.
--
-- Créer un module, un contrôle continu ou un examen reste ouvert à ceux qui
-- tiennent le programme — le Commandant de Division sur sa division, le
-- Commandant de Promotion sur la sienne. Mais le CORRIGER ou le SUPPRIMER,
-- non : changer un libellé ou un coefficient déplace le barème de toute une
-- promotion, et supprimer un contrôle emporte toutes ses notes. Ces deux
-- gestes-là ne se rattrapent pas, et ils reviennent à l'administrateur.
--
-- Les politiques existantes étaient écrites `for all` : elles accordaient
-- donc l'insertion, la modification et la suppression d'un seul tenant. On
-- les remplace par des politiques d'insertion seule, l'administrateur
-- gardant la sienne — `controles_write_admin`, inchangée — qui couvre tout.
--
-- Le Commandant de Brigade n'est pas concerné : il ne gère que le sport, et
-- le module Sport se crée tout seul par `assurer_module_sport`.
-- ============================================================================

-- --- Le Commandant de Division ----------------------------------------------
drop policy if exists controles_write_commandant on scolarite.controles;
drop policy if exists controles_write_chef_division on scolarite.controles;

drop policy if exists controles_insert_chef_division on scolarite.controles;
create policy controles_insert_chef_division on scolarite.controles
  for insert to authenticated
  with check (
    socle.current_role() = 'chef_division'
    and division_id = socle.current_division()
  );

-- --- Le Commandant de Promotion ---------------------------------------------
drop policy if exists controles_write_commandant_promotion on scolarite.controles;

drop policy if exists controles_insert_commandant_promotion on scolarite.controles;
create policy controles_insert_commandant_promotion on scolarite.controles
  for insert to authenticated
  with check (
    socle.current_role() = 'commandant_promotion'
    and scolarite.commande_la_phase(classe_id)
  );

-- --- Le Commandant de Brigade -----------------------------------------------
-- Sport uniquement, et en insertion seule comme les autres.
drop policy if exists controles_write_commandant_brigade on scolarite.controles;

drop policy if exists controles_insert_commandant_brigade on scolarite.controles;
create policy controles_insert_commandant_brigade on scolarite.controles
  for insert to authenticated
  with check (
    socle.current_role() = 'commandant_brigade'
    and scolarite.commande_la_phase(classe_id)
    and type = 'sport'
  );

-- ============================================================================
-- Contrôle : qui peut faire quoi sur les contrôles. Seules des politiques
-- « INSERT » doivent subsister hors de l'administrateur.
-- ============================================================================
select policyname, cmd
from pg_policies
where schemaname = 'scolarite' and tablename = 'controles'
order by cmd, policyname;
