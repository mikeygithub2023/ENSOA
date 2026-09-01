-- ============================================================================
-- Le coefficient d'une phase.
--
-- Une promotion se déroule en phases — FCB, CA1, CA2… — et toutes ne pèsent
-- pas le même poids dans la moyenne générale. Jusqu'ici, le bulletin d'une
-- promotion mettait toutes ses évaluations sur le même plan : la note d'une
-- phase courte pesait autant que celle d'une phase longue.
--
-- Le coefficient vit sur la phase elle-même, et non sur un référentiel
-- commun : chaque promotion a ses propres lignes de phase, donc son propre
-- barème. La phase 1 de la promotion 2026 peut peser 2 quand celle de 2027
-- pèse 3, sans qu'aucune ne dérange l'autre.
--
-- Par défaut 1 : les promotions déjà saisies gardent exactement la moyenne
-- qu'elles avaient, jusqu'à ce qu'on décide autrement.
-- ============================================================================

alter table scolarite.classes
  add column if not exists coefficient numeric(4, 2) not null default 1
    check (coefficient > 0);

comment on column scolarite.classes.coefficient is
  'Poids de la phase dans la moyenne générale de sa promotion. Sans objet '
  'pour un stage, qui ne se compose pas de phases.';
