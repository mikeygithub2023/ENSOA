-- ============================================================================
-- Accorder une permission, constater une absence : deux gestes de
-- commandement.
--
-- Les deux commandants d'une promotion voyaient les permissions et les
-- absences de leurs élèves — migration 054 — sans pouvoir en enregistrer
-- une seule. C'est le même oubli que pour les consultations médicales, et il
-- a la même cause : ces politiques ont été écrites quand le seul échelon
-- intermédiaire était la division.
--
-- Or on ne commande pas une promotion sans accorder les permissions de ses
-- élèves ni relever leurs absences. La portée reste celle de tout le reste :
-- les élèves des phases de leur promotion, et eux seuls.
--
-- L'administrateur et le Commandant de Division gardent ce qu'ils avaient.
-- ============================================================================

drop policy if exists permissions_write_commandant on scolarite.permissions;
create policy permissions_write_commandant on scolarite.permissions
  for all to authenticated
  using (scolarite.commande_l_apprenant(apprenant_id))
  with check (scolarite.commande_l_apprenant(apprenant_id));

drop policy if exists absences_write_commandant on scolarite.absences;
create policy absences_write_commandant on scolarite.absences
  for all to authenticated
  using (scolarite.commande_l_apprenant(apprenant_id))
  with check (scolarite.commande_l_apprenant(apprenant_id));

-- ============================================================================
-- Contrôle : les deux tables doivent porter une politique d'écriture pour le
-- commandant, en plus de celles de l'administrateur et de la division.
-- ============================================================================
select tablename, policyname, cmd
from pg_policies
where schemaname = 'scolarite'
  and tablename in ('permissions', 'absences')
order by tablename, cmd, policyname;
