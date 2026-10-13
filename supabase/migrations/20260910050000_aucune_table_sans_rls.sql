-- ============================================================================
-- Aucune table sans RLS, et l'annuaire du personnel se referme.
--
-- --- Le risque structurel ---------------------------------------------------
--
-- `20260829040000_droits.sql` accorde `select, insert, update, delete` sur
-- TOUTES les tables des trois schémas à `authenticated`, et pose
-- `alter default privileges` pour les tables à venir.
--
-- Il n'existe donc plus aucun filet de privilège sous la RLS. Une migration
-- future qui oublierait `enable row level security` ouvrirait la table à
-- toute l'école — en lecture ET en écriture — et rien ne le signalerait. La
-- requête de contrôle du super administrateur ne détecte pas ce cas : elle
-- filtre sur les tables AYANT la RLS.
--
-- Ce bloc ferme la classe entière de défauts : il échoue si une table des
-- trois schémas n'a pas la RLS. Le rejouer dans une migration d'entretien,
-- ou le recopier dans toute migration qui crée une table, suffit à la garder
-- fermée. Mieux vaut une migration qui refuse de s'appliquer qu'une table
-- ouverte dont personne ne s'aperçoit.
--
-- --- L'annuaire du personnel ------------------------------------------------
--
-- `logistique.personnel` était lisible par tout compte connecté : noms,
-- grades, matricules, numéros de téléphone, dates et lieux de naissance. Un
-- élève, un armurier, un gardien du poste de police avaient l'annuaire
-- nominatif complet du personnel de l'école.
--
-- L'asymétrie était frappante : `socle.profiles` est cloisonné avec soin,
-- jusqu'à borner le chef du soutien technique à son seul service, tandis que
-- cette table-ci, qui porte davantage de données personnelles, était ouverte.
-- Elle est vide aujourd'hui — le défaut est dans la politique, pas encore
-- dans les données. C'est le bon moment pour la fermer.
-- ============================================================================

drop policy if exists "lecture personnel" on logistique.personnel;
create policy "lecture personnel" on logistique.personnel
  for select to authenticated
  using (socle.current_user_role() is not null);

-- ============================================================================
-- Le garde-fou : aucune table des trois schémas sans RLS.
-- ============================================================================
do $$
declare v_sans text;
begin
  select string_agg(format('%s.%s', n.nspname, c.relname), ', ' order by n.nspname, c.relname)
    into v_sans
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname in ('socle', 'scolarite', 'logistique')
    and c.relkind = 'r'
    and not c.relrowsecurity;

  if v_sans is not null then
    raise exception
      'Table(s) sans Row Level Security, donc ouverte(s) à tout compte '
      'connecté : %. Ajoutez `alter table ... enable row level security` '
      'et les politiques correspondantes.', v_sans;
  end if;
end $$;

-- ============================================================================
-- Contrôle : doit retourner 0 ligne.
-- ============================================================================
select n.nspname || '.' || c.relname as table_sans_rls
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname in ('socle', 'scolarite', 'logistique')
  and c.relkind = 'r'
  and not c.relrowsecurity;
