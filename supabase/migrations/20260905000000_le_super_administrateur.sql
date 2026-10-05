-- ============================================================================
-- Le super administrateur : la main, et plus seulement la vue.
--
-- La migration 018b lui avait ouvert la lecture sur tous les domaines, pour
-- son tableau de bord transversal, et son commentaire le disait : « C'est une
-- vue, pas une main. Les écrans s'ouvrent et affichent, mais un enregistrement
-- serait refusé par le serveur. Lui donner la main demanderait d'ajouter des
-- politiques d'écriture — décision d'organisation, pas de code. »
--
-- La décision est prise : il commande l'école, il écrit partout.
--
-- POURQUOI UNE BOUCLE PLUTÔT QU'UNE LISTE. Énumérer les quarante tables
-- aurait produit une liste juste aujourd'hui et fausse au premier ajout —
-- exactement ce qui a privé l'administrateur des consultations et des visites
-- médicales côté application pendant des semaines, sans que rien ne le
-- signale. La boucle parcourt ce qui existe ; une table créée demain par une
-- migration ultérieure devra relancer ce bloc, et la dernière section le
-- rappelle.
--
-- CE QU'ELLE NE TOUCHE PAS : les tables sans RLS. Y poser une politique ne
-- servirait à rien — sans RLS, PostgreSQL ne consulte aucune politique — et
-- leur accorder des droits de table ouvrirait l'accès à tout le monde, non à
-- l'administrateur seul. Elles sont nommées en fin d'exécution.
-- ============================================================================

-- --- Qui est administrateur ------------------------------------------------
-- Les deux familles de rôles cohabitent depuis la fusion des applications :
-- `role` pour la scolarité, `role_logistique` pour le soutien technique. Un
-- administrateur porte normalement les deux, mais il suffit d'en porter un :
-- un compte à demi renseigné ne doit pas se retrouver à demi puissant, sans
-- qu'on sache lequel de ses écrans le refusera.
--
-- `actif` compte autant que le rôle : un compte désactivé garde sa ligne et
-- ses rôles, et retrouverait tous ses droits si l'on ne regardait que ceux-ci.
create or replace function socle.est_administrateur()
returns boolean
language sql
security definer
stable
set search_path = socle, public
as $$
  select exists (
    select 1
    from socle.profiles
    where id = auth.uid()
      and actif
      and (role = 'admin' or role_logistique = 'administrateur')
  );
$$;

grant execute on function socle.est_administrateur() to authenticated;

-- --- La main sur tout ------------------------------------------------------
do $$
declare
  t record;
  sans_rls text := '';
begin
  for t in
    select n.nspname as schema_, c.relname as table_, c.relrowsecurity as rls
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname in ('socle', 'scolarite', 'logistique')
      and c.relkind = 'r'
    order by n.nspname, c.relname
  loop
    if not t.rls then
      sans_rls := sans_rls || format('%s.%s ', t.schema_, t.table_);
      continue;
    end if;

    -- Les politiques permissives s'additionnent : celle-ci n'enlève rien à
    -- personne, elle ajoute une voie pour le seul administrateur.
    execute format(
      'drop policy if exists admin_tout_pouvoir on %I.%I',
      t.schema_, t.table_);
    execute format(
      'create policy admin_tout_pouvoir on %I.%I for all to authenticated '
      'using (socle.est_administrateur()) '
      'with check (socle.est_administrateur())',
      t.schema_, t.table_);

    -- Une politique ne sert à rien sans le droit de table qui la précède :
    -- PostgreSQL refuse d'abord sur les privilèges, et ne consulte la RLS
    -- qu'ensuite. Le droit est sans danger ici, la RLS étant active.
    execute format(
      'grant select, insert, update, delete on %I.%I to authenticated',
      t.schema_, t.table_);
  end loop;

  if sans_rls <> '' then
    raise warning 'Tables sans RLS, laissées intactes : %', sans_rls;
  end if;
end $$;

-- --- Les séquences suivent -------------------------------------------------
-- Insérer dans une table à clé `serial` demande aussi le droit sur sa
-- séquence. Sans lui, l'insertion échoue sur un message qui ne parle pas de
-- la table où elle a lieu.
grant usage, select on all sequences in schema socle to authenticated;
grant usage, select on all sequences in schema scolarite to authenticated;
grant usage, select on all sequences in schema logistique to authenticated;

-- ============================================================================
-- Contrôle : ce que l'administrateur peut désormais écrire.
--
-- Doit retourner 0. Toute ligne listée est une table où il resterait sans
-- main — soit qu'elle n'ait pas de RLS, soit que la boucle l'ait manquée.
-- ============================================================================
select n.nspname || '.' || c.relname as table_sans_pouvoir_admin
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname in ('socle', 'scolarite', 'logistique')
  and c.relkind = 'r'
  and c.relrowsecurity
  and not exists (
    select 1 from pg_policies p
    where p.schemaname = n.nspname
      and p.tablename = c.relname
      and p.policyname = 'admin_tout_pouvoir'
  );

-- ============================================================================
-- POUR LA SUITE
--
-- Une table créée après cette migration n'aura pas la politique. Le plus sûr
-- est de rejouer le bloc `do $$ ... $$` ci-dessus dans la migration qui crée
-- la table, ou de le recopier dans une migration d'entretien. La requête de
-- contrôle ci-dessus dit à tout moment s'il en manque.
-- ============================================================================
