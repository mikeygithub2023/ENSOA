-- ============================================================================
-- Un commandant envoie ses élèves à l'infirmerie.
--
-- Enregistrer une consultation de routine, c'est délivrer l'autorisation de
-- consulter : le geste relève du commandement, pas du médecin, qui ne fait
-- ensuite que traiter ce qui lui est adressé. L'administrateur et le
-- Commandant de Division l'avaient ; les deux commandants d'une promotion,
-- non — leurs élèves ne pouvaient donc pas être présentés au service de
-- santé par leur propre chef.
--
-- Ils ne voyaient d'ailleurs même pas les consultations de leurs élèves :
-- aucune politique de lecture ne les nommait. On corrige les deux, dans la
-- même portée que tout le reste — les élèves des phases de leur promotion.
-- ============================================================================

drop policy if exists consultations_medicales_select_commandant
  on scolarite.consultations_medicales;
create policy consultations_medicales_select_commandant
  on scolarite.consultations_medicales
  for select to authenticated
  using (scolarite.commande_l_apprenant(apprenant_id));

-- L'écriture couvre l'autorisation, sa correction et son annulation : un
-- élève présenté par erreur se retire, et une consultation demandée pour le
-- mauvais motif se corrige. Ce qui reste au médecin — le traitement, le
-- diagnostic — est porté par ses propres colonnes et sa propre politique.
drop policy if exists consultations_medicales_write_commandant
  on scolarite.consultations_medicales;
create policy consultations_medicales_write_commandant
  on scolarite.consultations_medicales
  for all to authenticated
  using (scolarite.commande_l_apprenant(apprenant_id))
  with check (scolarite.commande_l_apprenant(apprenant_id));

-- ============================================================================
-- Contrôle : les politiques de la table, poste par poste.
-- ============================================================================
select policyname, cmd
from pg_policies
where schemaname = 'scolarite' and tablename = 'consultations_medicales'
order by cmd, policyname;
