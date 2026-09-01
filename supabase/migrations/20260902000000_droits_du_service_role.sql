-- ============================================================================
-- Les fonctions serveur ont enfin le droit de lire.
--
-- `20260829040000_droits.sql` avait ouvert les trois schémas à
-- `authenticated`, et s'était arrêté là. Or les fonctions Edge ne s'exécutent
-- pas sous ce rôle : elles portent la clé de service, donc le rôle
-- `service_role`. Dans le schéma `public`, Supabase lui accorde tout d'office
-- — c'est pourquoi le piège ne s'était pas vu. Dans `socle`, `scolarite` et
-- `logistique`, créés à la main, il n'avait que le droit d'entrer : `usage`
-- sur le schéma, et rien sur les tables.
--
-- Les fonctions échouaient donc toutes à la même ligne — la lecture du profil
-- de l'appelant — sur un « permission denied for table profiles ». Et comme
-- aucune ne vérifiait l'erreur, chacune interprétait le profil manquant à sa
-- façon : l'assistant y voyait un compte sans droits (« réservé à
-- l'administrateur »), la suppression de compte un compte fermé (« compte
-- désactivé »). Deux refus incompréhensibles, une seule cause.
--
-- ⚠ `service_role` contourne la RLS par construction. Ces droits ne relâchent
-- rien pour l'application : c'est du code serveur, qui vérifie lui-même
-- l'identité et les droits de l'appelant avant d'agir.
-- ============================================================================

do $$
declare
  cible text;
begin
  foreach cible in array array['socle', 'scolarite', 'logistique'] loop
    execute format(
      'grant select, insert, update, delete on all tables in schema %I '
      'to service_role', cible
    );
    execute format(
      'grant usage, select on all sequences in schema %I to service_role',
      cible
    );
    execute format(
      'grant execute on all functions in schema %I to service_role', cible
    );

    -- Et pour les tables à venir, afin que le piège ne se retende pas.
    execute format(
      'alter default privileges in schema %I '
      'grant select, insert, update, delete on tables to service_role', cible
    );
    execute format(
      'alter default privileges in schema %I '
      'grant usage, select on sequences to service_role', cible
    );
    execute format(
      'alter default privileges in schema %I '
      'grant execute on functions to service_role', cible
    );
  end loop;
end $$;

-- ============================================================================
-- Contrôle : le rôle de service peut-il lire les trois tables sur lesquelles
-- les fonctions butaient ?
-- ============================================================================
select
  has_table_privilege('service_role', 'socle.profiles', 'select') as profils,
  has_table_privilege('service_role', 'scolarite.apprenants', 'select')
    as apprenants,
  has_table_privilege('service_role', 'logistique.vehicule', 'select')
    as vehicules;
