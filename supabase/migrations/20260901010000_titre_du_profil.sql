-- ============================================================================
-- Le titre affiché d'un agent.
--
-- Le poste dit ce qu'on a le droit de faire ; le titre dit comment on se
-- nomme. Les deux ne se recouvrent pas toujours : le Commandant de l'école
-- tient le compte d'administrateur, mais on ne l'appelle pas
-- « l'administrateur ». Les autres administrateurs, eux, sont bien des
-- administrateurs.
--
-- On aurait pu écrire le nom du commandant dans le code. Le jour où il change
-- d'affectation, le titre serait resté attaché au mauvais homme, et le
-- nouveau commandant se serait vu appeler administrateur. Le titre vit donc
-- sur le profil, avec la fonction.
--
-- Nul par défaut : l'application retombe alors sur le libellé du poste, qui
-- convient à tout le monde sauf exception.
-- ============================================================================

alter table socle.profiles
  add column if not exists titre text;

comment on column socle.profiles.titre is
  'Titre affiché à la place du libellé du poste — « Commandant de l''école », '
  '« Directeur des études »… Nul pour la plupart des agents.';
