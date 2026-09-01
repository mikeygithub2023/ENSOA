-- ============================================================================
-- Contrôle de la base unifiée — à coller dans Dashboard > SQL Editor.
-- Lecture seule, et UNE seule requête : l'éditeur n'affiche que le résultat
-- de la dernière instruction d'un script.
-- ============================================================================

select 1 as n, 'tables scolarite (attendu ~39)' as controle,
       count(*)::text as resultat
  from information_schema.tables
  where table_schema = 'scolarite' and table_type = 'BASE TABLE'
union all
select 2, 'tables logistique (attendu ~29)', count(*)::text
  from information_schema.tables
  where table_schema = 'logistique' and table_type = 'BASE TABLE'
union all
select 3, 'tables socle', count(*)::text
  from information_schema.tables
  where table_schema = 'socle' and table_type = 'BASE TABLE'
union all
-- LE contrôle qui compte : une table sans RLS est lisible par n'importe quel
-- compte connecté.
select 4, '>>> TABLES SANS RLS (doit être : aucune)',
       coalesce(string_agg(schemaname || '.' || tablename, ', '), 'aucune')
  from pg_tables
  where schemaname in ('socle', 'scolarite', 'logistique') and not rowsecurity
union all
select 5, 'politiques RLS posées', count(*)::text
  from pg_policies
  where schemaname in ('socle', 'scolarite', 'logistique')
union all
select 6, 'fonctions de rôle',
       coalesce(string_agg(n.nspname || '.' || p.proname, ', ' order by p.proname), 'AUCUNE')
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'socle'
    and p.proname in ('current_role', 'current_user_role', 'current_division', 'current_promotion')
union all
select 7, 'colonnes de rôle sur profiles',
       coalesce(string_agg(column_name || ' (nullable ' || is_nullable || ')', ', ' order by column_name), 'AUCUNE')
  from information_schema.columns
  where table_schema = 'socle' and table_name = 'profiles'
    and column_name in ('role', 'role_logistique', 'matricule')
union all
select 8, 'migrations appliquées (attendu 97)', count(*)::text
  from supabase_migrations.schema_migrations
union all
select 9, 'comptes existants', count(*)::text from auth.users
union all
select 10, 'profils dans la base unifiée', count(*)::text from socle.profiles
order by 1;
