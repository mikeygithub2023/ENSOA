-- ============================================================================
-- Retirer les performances sportives restées seules après la suppression de
-- leur note.
--
-- LE PROBLÈME
--   Une note sportive est calculée par un déclencheur à partir de la
--   performance. Jusqu'à la correction d'aujourd'hui, valider une demande de
--   suppression ne retirait que la note : la performance restait en base, et
--   l'écran l'affichait « Sans barème ». Ce script retire celles-là.
--
-- COMMENT ON LES RECONNAÎT
--   Une performance sans note n'est pas forcément orpheline : il est normal
--   qu'elle n'en ait pas quand le barème manque pour son sexe. Les supprimer
--   toutes détruirait des mesures parfaitement valables.
--
--   On s'appuie donc sur le journal d'audit, qui garde la trace de chaque
--   note supprimée avec la ligne entière. Sont retirées les seules
--   performances dont la note a effectivement été supprimée — et qui n'en
--   ont pas retrouvé une depuis.
--
-- MODE D'EMPLOI — deux passages
--   1. Coller ce fichier tel quel dans Dashboard > SQL Editor > Run.
--      Il se termine par `rollback` : RIEN n'est supprimé. Le tableau
--      affiché est la liste exacte de ce qui partirait.
--   2. Si cette liste est la bonne, remplacer la dernière ligne
--      `rollback;` par `commit;` et relancer.
-- ============================================================================

begin;

with notes_supprimees as (
  -- Les notes sportives que quelqu'un a supprimées, d'après le journal.
  select distinct
    (meta ->> 'sous_module_id')::uuid as sous_module_id,
    (meta ->> 'apprenant_id')::uuid   as apprenant_id
  from socle.audit_log
  where table_name = 'notes'
    and action = 'DELETE'
    and meta ->> 'sous_module_id' is not null
    and meta ->> 'apprenant_id' is not null
),
orphelines as (
  select p.id
  from scolarite.performances_sportives p
  join notes_supprimees n
    on n.sous_module_id = p.sous_module_id
   and n.apprenant_id = p.apprenant_id
  -- Sauf si une note lui est revenue depuis : le barème a pu être complété,
  -- ou la performance ressaisie. Elle n'est alors plus orpheline.
  where not exists (
    select 1 from scolarite.notes x
    where x.sous_module_id = p.sous_module_id
      and x.apprenant_id = p.apprenant_id
  )
)
delete from scolarite.performances_sportives p
using orphelines o
where p.id = o.id
returning
  p.id,
  (select trim(a.prenom || ' ' || a.nom)
     from scolarite.apprenants a where a.id = p.apprenant_id) as eleve,
  (select sm.nom
     from scolarite.sous_modules sm where sm.id = p.sous_module_id) as seance,
  p.valeur,
  p.created_at;

-- ⚠ Tant que cette ligne dit `rollback`, rien n'est supprimé : le tableau
--   ci-dessus n'est qu'un aperçu. Remplacer par `commit;` pour l'appliquer.
rollback;
