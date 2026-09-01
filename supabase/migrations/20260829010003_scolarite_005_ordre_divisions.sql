-- ============================================================================
-- SCOLARITÉ (ENSOA GSES) — repris de 005_ordre_divisions.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- Migration : ordre d'affichage explicite pour les divisions. Les trois
-- lignes ont été insérées en une seule requête dans schema.sql, donc
-- `created_at` est identique pour les trois — trier par cette colonne ne
-- garantit pas un ordre stable. On fixe donc un ordre explicite.

alter table socle.divisions add column if not exists ordre integer;

update socle.divisions set ordre = 1 where code = 'formation_initiale';
update socle.divisions set ordre = 2 where code = 'formation_specialistes';
update socle.divisions set ordre = 3 where code = 'formation_continue';
