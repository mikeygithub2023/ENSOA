-- ============================================================================
-- Le déclencheur de notification lisait une colonne qui n'existe pas.
--
-- `notifier_depotage()` composait son message avec `new.quantite_recue`. La
-- colonne s'appelle `qte_carburant_recue`. Résultat : toute insertion dans
-- `logistique.depotage` échouait sur
--
--     record "new" has no field "quantite_recue"   (SQLSTATE 42703)
--
-- et plus aucun dépotage ne s'enregistrait. Le déclencheur étant `after
-- insert`, son échec annulait la transaction entière : la ligne n'entrait
-- pas, et l'écran annonçait une erreur sans dire laquelle.
--
-- POURQUOI CELA A PU PASSER INAPERÇU. plpgsql ne résout `new.<champ>` qu'à
-- l'exécution : `create function` accepte sans broncher un champ qui
-- n'existe pas. Rien ne se voit à la migration, rien aux tests du client —
-- seulement au premier dépotage réel. Un contrôle est donc ajouté plus bas
-- pour que la classe entière de ce défaut ne puisse pas revenir.
-- ============================================================================

create or replace function logistique.notifier_depotage()
returns trigger language plpgsql security definer
set search_path = logistique, socle, public
as $$
begin
  perform socle.notifier(
    array(select socle.les_administrateurs()),
    'carburant',
    'Dépotage de soute',
    new.qte_carburant_recue || ' L de ' || new.type_carburant
      || ' reçus en soute.'
  );
  return new;
end $$;

-- ============================================================================
-- La garde : aucun déclencheur ne lit une colonne absente.
--
-- Le même balayage que celui qui a trouvé ce défaut, mais exécuté à chaque
-- migration. Il parcourt toutes les fonctions de déclencheur des trois
-- schémas, en extrait les `new.x` et `old.x`, et refuse la migration si l'un
-- d'eux ne correspond à aucune colonne de la table déclencheuse.
--
-- Ce contrôle a ses limites, et mieux vaut les connaître : il ne voit pas un
-- champ construit dynamiquement (`execute`), et une colonne homonyme sur une
-- autre table le satisfait. Il attrape en revanche exactement ce qui vient
-- de se produire — une colonne renommée, un déclencheur resté en arrière.
-- ============================================================================
do $$
declare
  fautes text := '';
  r record;
  champ text;
begin
  for r in
    select n.nspname as schema, c.relname as tbl, t.tgname as trig,
           p.proname as fonction, pg_get_functiondef(p.oid) as src
    from pg_trigger t
    join pg_class c on c.oid = t.tgrelid
    join pg_namespace n on n.oid = c.relnamespace
    join pg_proc p on p.oid = t.tgfoid
    where not t.tgisinternal
      and n.nspname in ('socle', 'scolarite', 'logistique')
  loop
    for champ in
      select distinct lower(m[2])
      from regexp_matches(r.src, '\m(new|old)\.([a-z_][a-z0-9_]*)', 'gi') as m
    loop
      if not exists (
        select 1 from information_schema.columns
        where table_schema = r.schema and table_name = r.tbl
          and column_name = champ
      ) then
        fautes := fautes || format(E'\n  %s.%s : le déclencheur %s (%s) lit '
                 || '« %s », qui n''est pas une colonne de cette table.',
                 r.schema, r.tbl, r.trig, r.fonction, champ);
      end if;
    end loop;
  end loop;

  if fautes <> '' then
    raise exception
      'Un déclencheur lit une colonne qui n''existe pas. Toute écriture sur '
      'la table échouerait à l''exécution :%s', fautes;
  end if;
end $$;

-- ============================================================================
-- Contrôle : doit retourner 1 ligne, la fonction corrigée.
-- ============================================================================
select p.proname
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'logistique'
  and p.proname = 'notifier_depotage'
  and pg_get_functiondef(p.oid) like '%qte_carburant_recue%';
