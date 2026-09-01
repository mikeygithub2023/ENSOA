-- ============================================================================
-- Les types de carburant.
--
-- `logistique.type_stock` est le référentiel qui distingue le gasoil du super.
-- Il vivait dans le `seed.sql` de l'application d'origine — un fichier de
-- démonstration que la fusion n'a pas rejoué, à raison : il contenait aussi
-- des véhicules et des soutes fictifs.
--
-- Sauf que ces deux lignes-là ne sont pas de la démonstration : sans elles,
-- aucun dépotage n'est possible. Le formulaire cherche le type correspondant
-- au carburant saisi, ne trouve rien, et renonce.
--
-- Deux lignes, donc, et pas une de plus.
-- ============================================================================

insert into logistique.type_stock (libelle)
select v.libelle
from (values ('Gasoil'), ('Super')) as v(libelle)
where not exists (
  select 1 from logistique.type_stock t where t.libelle = v.libelle
);
