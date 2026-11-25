-- ============================================================================
-- La rubrique Carburant repart de zéro.
--
-- Les soutes, les quantités et les mouvements en base viennent des essais de
-- recette : ils ont servi à éprouver les formulaires, pas à tenir le dépôt.
-- Avant d'y porter les données réelles de l'école, on fait table rase — un
-- stock à moitié vrai est pire qu'un stock vide, parce qu'on le croit.
--
-- CE QUI DISPARAÎT
--   logistique.soute               les dépôts
--   logistique.soute_type_stock    les quantités, par soute et par répartition
--   logistique.depotage            les réceptions
--   logistique.depotage_interne    les ventilations entre répartitions
--   logistique.distribution        les sorties
--   socle.notifications            les seules alertes de type « carburant »
--
-- CE QUI RESTE, ET POURQUOI
--   logistique.type_stock    Gasoil et Super. C'est un référentiel, pas une
--                            donnée de dépôt : sans ces deux lignes, le
--                            formulaire de dépotage ne trouve plus le type
--                            correspondant au carburant saisi et renonce
--                            (voir 20260901030000_types_de_carburant.sql).
--   logistique.repartition   BA1, CA1, CA2, Général, Activités Ordinaires.
--                            Ce sont les affectations réelles de l'école, et
--                            « Activités Ordinaires » est exigée par le
--                            déclencheur qui ouvre toute soute nouvelle
--                            (voir 20260911000000_toute_soute...).
--
-- CE QU'IL FAUT FAIRE ENSUITE
--   Recréer les soutes réelles depuis l'écran Carburant. Chaque soute reçoit
--   automatiquement sa ligne « Activités Ordinaires » — c'est là qu'entre le
--   carburant reçu, et c'est de là qu'on ventile vers BA1, CA1, CA2.
--
-- À EXÉCUTER UNE SEULE FOIS, dans Supabase → SQL Editor.
-- ============================================================================

-- --- Les mouvements, les stocks, les soutes ---------------------------------
-- TRUNCATE plutôt que DELETE : les compteurs d'identité repartent à 1, donc
-- la première soute réelle porte le numéro 1. Les cinq tables sont citées
-- ensemble, sans CASCADE : si une table inconnue référençait l'une d'elles,
-- PostgreSQL refuserait l'ordre au lieu de la vider en silence.
truncate table
  logistique.depotage_interne,
  logistique.depotage,
  logistique.distribution,
  logistique.soute_type_stock,
  logistique.soute
restart identity;

-- --- Les alertes qui renvoyaient à ces mouvements ---------------------------
-- Elles n'ont pas de clé étrangère vers eux : rien ne les aurait emportées.
-- Un journal qui annonce des distributions dont il ne reste pas trace ment.
delete from socle.notifications where type = 'carburant';

-- ============================================================================
-- Contrôle : les cinq premières lignes doivent rendre 0.
-- La dernière rend les référentiels conservés : 2 types de carburant, et
-- les répartitions de l'école — dont « Activités Ordinaires ».
-- ============================================================================
select 'soute' as table_, count(*) from logistique.soute
union all select 'soute_type_stock', count(*) from logistique.soute_type_stock
union all select 'depotage', count(*) from logistique.depotage
union all select 'depotage_interne', count(*) from logistique.depotage_interne
union all select 'distribution', count(*) from logistique.distribution
union all select 'type_stock (conservé)', count(*) from logistique.type_stock
union all select 'repartition (conservé)', count(*) from logistique.repartition;
