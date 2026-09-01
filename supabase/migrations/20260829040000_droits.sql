-- ============================================================================
-- Droits d'accès — le dernier fichier, une fois toutes les tables créées.
--
-- La RLS filtre les lignes ; encore faut-il avoir le droit d'atteindre la
-- table. Sans ces GRANT, PostgREST renvoie 42501 alors que les politiques
-- sont parfaitement correctes — c'est le piège classique, et les deux bases
-- d'origine s'y étaient déjà cognées.
--
-- Le module scolarité, lui, porte déjà son propre bloc de GRANT, requalifié
-- avec le reste de son SQL : rien à ajouter pour lui.
-- ============================================================================

-- --- Socle -----------------------------------------------------------------
grant select, insert, update, delete on all tables in schema socle to authenticated;
grant usage, select on all sequences in schema socle to authenticated;

alter default privileges in schema socle
  grant select, insert, update, delete on tables to authenticated;
alter default privileges in schema socle
  grant usage, select on sequences to authenticated;

-- --- Logistique ------------------------------------------------------------
-- Ce module vivait dans `public`, où Supabase accorde ces droits par défaut.
-- Dans un schéma créé à la main, rien n'est accordé.
grant select, insert, update, delete on all tables in schema logistique to authenticated;
grant usage, select on all sequences in schema logistique to authenticated;

alter default privileges in schema logistique
  grant select, insert, update, delete on tables to authenticated;
alter default privileges in schema logistique
  grant usage, select on sequences to authenticated;
