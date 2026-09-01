-- ============================================================================
-- LOGISTIQUE (ERP ENSOA) — repris de migration_021_armement_suppression.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- ============================================================================
-- Suppression dans le module Armement : armes, calibres de munitions,
-- équipements de protection et types d'arme.
--
-- Suppression « douce » partout, comme pour les véhicules (migration 012) et
-- les soutes (migration 020) : la ligne est marquée supprimée, jamais
-- effacée.
--
-- Ce n'est pas une précaution de principe, c'est une nécessité :
--
--   * `dotation_arme.arme_id` et `dotation_equipement.equipement_id`
--     référencent ces tables sans ON DELETE. Postgres refuserait donc
--     d'effacer une arme ou un équipement ayant fait l'objet du moindre bon
--     de sortie, et l'utilisateur n'y verrait qu'une erreur de contrainte.
--
--   * Un registre d'armurerie se relit des années après. Savoir quelle arme
--     a été remise à qui, et quand, suppose que l'arme figure toujours au
--     registre — même réformée, même détruite. Effacer la ligne effacerait
--     la trace de ce qu'elle a servi.
--
-- Les munitions n'ont, elles, aucune table qui les référence : leur
-- suppression pourrait être définitive. On garde tout de même la même
-- mécanique, pour que les quatre écrans du module se comportent pareil et
-- qu'un calibre retiré par erreur se retrouve en base.
-- ============================================================================

alter table logistique.arme
  add column if not exists supprime boolean not null default false;

alter table logistique.stock_munition
  add column if not exists supprime boolean not null default false;

alter table logistique.equipement_protection
  add column if not exists supprime boolean not null default false;

alter table logistique.type_arme
  add column if not exists supprime boolean not null default false;

-- Les listes ne remontent que les lignes actives ; ces index servent ce
-- filtre, présent sur chaque lecture.
create index if not exists arme_actives_idx
  on logistique.arme (supprime) where supprime = false;

create index if not exists stock_munition_actives_idx
  on logistique.stock_munition (supprime) where supprime = false;

create index if not exists equipement_protection_actives_idx
  on logistique.equipement_protection (supprime) where supprime = false;

create index if not exists type_arme_actives_idx
  on logistique.type_arme (supprime) where supprime = false;
