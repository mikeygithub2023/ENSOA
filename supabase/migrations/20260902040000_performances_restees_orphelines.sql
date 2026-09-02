-- ============================================================================
-- Retirer les performances sportives laissées seules par une suppression de
-- note antérieure.
--
-- Une note sportive est calculée par un déclencheur à partir de la
-- performance. Jusqu'à la correction de ce jour, valider une demande de
-- suppression ne retirait que la note : la performance restait en base, et
-- l'écran l'affichait « Sans barème », faute de quoi que ce soit pour la
-- noter. Ce sont ces restes-là qu'on retire.
--
-- ⚠ Une performance sans note n'est PAS forcément orpheline : il est normal
-- qu'elle n'en ait pas quand le barème manque pour le sexe de l'élève. On ne
-- se fie donc pas à l'absence de note, mais au journal d'audit, qui garde la
-- ligne entière de chaque note supprimée. Et on épargne celles qui ont
-- retrouvé une note depuis — le barème a pu être complété.
--
-- Aperçu obtenu avant application : deux performances, toutes deux sur le
-- CROSS, saisies le 01/09/2026.
-- ============================================================================

with orphelines as (
  select p.id
  from scolarite.performances_sportives p
  where exists (
    select 1 from socle.audit_log j
    where j.table_name = 'notes'
      and j.action = 'DELETE'
      and (j.meta ->> 'sous_module_id')::uuid = p.sous_module_id
      and (j.meta ->> 'apprenant_id')::uuid = p.apprenant_id
  )
  and not exists (
    select 1 from scolarite.notes n
    where n.sous_module_id = p.sous_module_id
      and n.apprenant_id = p.apprenant_id
  )
)
delete from scolarite.performances_sportives p
using orphelines o
where p.id = o.id;
