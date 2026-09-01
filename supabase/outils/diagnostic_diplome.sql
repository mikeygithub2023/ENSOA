-- ============================================================================
-- Pourquoi l'ajout d'un diplôme fait-il échouer l'enregistrement d'un élève ?
--
-- La première version de ce script passait par une fonction temporaire, que
-- l'éditeur SQL de Supabase a refusée (« relation socle.profiles does not
-- exist » : il n'exécute pas le corps d'une fonction dans le même contexte
-- que les requêtes ordinaires). Celle-ci n'est faite que de requêtes
-- ordinaires — celles-là, l'éditeur les exécute.
--
-- MODE D'EMPLOI
--   Coller le fichier entier dans Dashboard > SQL Editor, puis Run.
--   L'éditeur s'arrête à la PREMIÈRE requête refusée : c'est justement la
--   réponse cherchée. Recopiez le message d'erreur, ou le dernier tableau
--   affiché si tout passe.
--
-- Rien n'est conservé : le `rollback` final annule tout.
-- ============================================================================

begin;

-- --- 1. Le compte qui enregistre -------------------------------------------
-- Si `role` ne vaut pas « admin », la politique d'ajout au catalogue des
-- diplômes refusera : elle n'ouvre qu'à admin, chef_division, instructeur et
-- medecin.
select 'ÉTAPE 1 — le compte' as etape,
       matricule, nom_complet, role, role_logistique, actif
from socle.profiles
where role is not null
order by created_at;

-- --- 2. Le catalogue porte-t-il deux orthographes du même diplôme ? --------
-- L'unicité du nom est sensible à la casse, la recherche ne l'est pas :
-- « BAC » et « Bac » peuvent coexister et faire hésiter la requête.
select 'ÉTAPE 2 — doublons de casse' as etape,
       lower(nom) as nom_normalise, count(*) as orthographes
from scolarite.diplomes
group by lower(nom)
having count(*) > 1;

select 'ÉTAPE 2bis — taille du catalogue' as etape,
       count(*) as diplomes
from scolarite.diplomes;

-- --- 3. On se met dans la peau de l'administrateur -------------------------
-- Tout ce qui suit s'exécute avec ses droits, RLS comprise : c'est ce que
-- l'application, elle, subit.
select set_config(
  'request.jwt.claims',
  json_build_object(
    'sub', (select id from socle.profiles
             where role = 'admin' order by created_at limit 1),
    'role', 'authenticated'
  )::text,
  true
);

set local role authenticated;

select 'ÉTAPE 3 — rôle vu par la base' as etape,
       socle.current_role()::text as current_role;

-- --- 4. Vider les diplômes actuels de l'élève ------------------------------
-- Première requête envoyée par l'application quand une fiche porte un
-- diplôme.
delete from scolarite.apprenant_diplomes
where apprenant_id = (select id from scolarite.apprenants order by id limit 1);

select 'ÉTAPE 4 — vider les diplômes de l''élève' as etape, 'ACCEPTÉ' as verdict;

-- --- 5. Ajouter un diplôme au catalogue ------------------------------------
insert into scolarite.diplomes (nom)
values ('DIAGNOSTIC — à ignorer');

select 'ÉTAPE 5 — ajouter au catalogue' as etape, 'ACCEPTÉ' as verdict;

-- --- 6. Rattacher ce diplôme à l'élève -------------------------------------
insert into scolarite.apprenant_diplomes (apprenant_id, diplome_id)
values (
  (select id from scolarite.apprenants order by id limit 1),
  (select id from scolarite.diplomes where nom = 'DIAGNOSTIC — à ignorer')
);

select 'ÉTAPE 6 — rattacher le diplôme à l''élève' as etape,
       'ACCEPTÉ' as verdict;

-- --- 7. Modifier la fiche elle-même ----------------------------------------
-- L'enregistrement écrit la fiche AVANT les diplômes : si c'est elle qui est
-- refusée, le diplôme n'y est pour rien.
update scolarite.apprenants
set nom = nom
where id = (select id from scolarite.apprenants order by id limit 1);

select 'ÉTAPE 7 — modifier la fiche de l''élève' as etape,
       'ACCEPTÉ' as verdict,
       'Tout est passé : le refus ne vient pas de la base.' as conclusion;

reset role;
rollback;
