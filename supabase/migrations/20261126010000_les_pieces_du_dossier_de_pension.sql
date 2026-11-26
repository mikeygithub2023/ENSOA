-- ============================================================================
-- Les pièces du dossier de pension, d'après la liste remise par l'école
-- (« Éléments constitutifs d'un dossier de pension », 26 novembre 2026).
--
-- Le catalogue avait été livré vide, à charge pour l'école de le remplir :
-- la voici. Deux pièces ne se demandent qu'au militaire marié — l'acte de
-- mariage, l'acte de naissance de l'épouse —, et l'acte de naissance des
-- enfants qu'à celui qui en a. D'où une colonne `condition` : sans elle, le
-- dossier d'un célibataire ne serait jamais complet.
--
-- Rejouable : une pièce déjà au catalogue (même libellé) n'est pas
-- dupliquée ; sa place et sa condition sont remises à la liste.
-- ============================================================================

alter table scolarite.pieces_pension
  add column if not exists condition text;

alter table scolarite.pieces_pension
  drop constraint if exists pieces_pension_condition_check;
alter table scolarite.pieces_pension
  add constraint pieces_pension_condition_check
  check (condition is null or condition in ('marie', 'enfants'));

comment on column scolarite.pieces_pension.condition is
  'À qui la pièce se demande : à tous (null), au militaire marié (marie), '
  'au militaire qui a des enfants (enfants).';

insert into scolarite.pieces_pension (libelle, ordre, obligatoire, condition)
values
  ('Fiche individuelle', 10, true, null),
  ('Photocopie de la carte d''identité militaire', 20, true, null),
  ('Photocopie de la carte nationale d''identité', 30, true, null),
  ('Extrait d''acte de naissance original du militaire', 40, true, null),
  ('Extrait d''acte de naissance original de chaque enfant', 50, true,
   'enfants'),
  ('État civil du militaire', 60, true, null),
  ('Livret de pension', 70, true, null),
  ('Extrait original de l''acte de mariage', 80, true, 'marie'),
  ('Extrait d''acte de naissance original de l''épouse', 90, true, 'marie')
on conflict (libelle) do update
  set ordre = excluded.ordre,
      condition = excluded.condition,
      active = true;

notify pgrst, 'reload schema';

-- ============================================================================
-- Contrôle : 9 pièces actives, dont 2 « si marié » et 1 « si enfants ».
-- ============================================================================
select
  count(*) filter (where active) as pieces_actives,
  count(*) filter (where active and condition = 'marie') as si_marie,
  count(*) filter (where active and condition = 'enfants') as si_enfants
from scolarite.pieces_pension;
