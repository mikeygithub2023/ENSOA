-- ============================================================================
-- LOGISTIQUE (ERP ENSOA) — repris de migration_020_soute_modification_suppression.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- ============================================================================
-- Modification et suppression d'une soute.
--
-- Suppression « douce », comme pour les véhicules (migration 012) : la ligne
-- n'est pas effacée, elle est marquée supprimée et disparaît des listes.
--
-- Deux raisons de ne pas effacer pour de bon :
--
--   * `soute_type_stock` référence `soute(id)` sans ON DELETE. Postgres
--     refuserait donc purement et simplement la suppression d'une soute
--     ayant reçu la moindre répartition, et l'utilisateur n'y verrait qu'une
--     erreur de contrainte.
--
--   * Les dépotages et les distributions se rattachent à `soute_type_stock`.
--     Effacer la soute reviendrait à trouer l'historique des mouvements de
--     carburant — ce qu'un service ne peut pas se permettre : ce sont les
--     pièces comptables du dépôt.
--
-- Le libellé, lui, se modifie normalement : renommer une soute ne change
-- rien à ce qu'elle a reçu ni distribué.
-- ============================================================================

alter table logistique.soute add column if not exists supprime boolean not null default false;

-- Les listes ne remontent que les soutes actives ; l'index sert ce filtre,
-- présent sur chaque lecture.
create index if not exists soute_actives_idx on logistique.soute (supprime) where supprime = false;
