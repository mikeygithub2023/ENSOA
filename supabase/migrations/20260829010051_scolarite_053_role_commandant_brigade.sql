-- ============================================================================
-- SCOLARITÉ (ENSOA GSES) — repris de 053_role_commandant_brigade.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- Migration : le rôle « Commandant de Brigade » — étape 1 sur 2.
--
-- Cette migration n'ajoute que la valeur à l'énuméré. PostgreSQL refuse
-- qu'une valeur d'énuméré fraîchement ajoutée soit employée dans la même
-- transaction : les politiques d'accès qui la nomment font donc l'objet de
-- la migration suivante, à passer après celle-ci.

alter type socle.app_role add value if not exists 'commandant_brigade';
