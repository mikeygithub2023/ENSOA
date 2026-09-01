-- ============================================================================
-- Rattacher le premier compte administrateur.
--
-- C'est le seul compte créé à la main : tous les suivants s'ouvrent depuis
-- l'application, par cet administrateur.
--
-- AVANT : Dashboard > Authentication > Users > Add user.
--
--   ⚠ L'EMAIL N'EST PAS LIBRE. On se connecte à l'ERP avec son matricule ;
--     l'application le traduit en email technique. L'email du compte doit
--     donc être exactement :
--
--         <matricule en minuscules, sans espace ni ponctuation>@sig.ensoa.ci
--
--     Matricule « 12 345/AB »  →  email  12345ab@sig.ensoa.ci
--
--     Le domaine diffère volontairement du `@stensoa.com` de l'ancienne
--     application logistique : les deux jeux de comptes cohabitent dans le
--     même auth.users, et les mêmes matricules peuvent être recréés ici sans
--     collision. L'ancienne application garde ses comptes tant qu'elle sert.
--
--   Le mot de passe : au moins 8 caractères, choisi par toi. Le drapeau
--   `doit_changer_mot_de_passe` ci-dessous impose son remplacement à la
--   première connexion.
--
-- Le déclencheur `on_auth_user_created` crée aussitôt la ligne de profil ;
-- ce script ne fait que la compléter. Remplacer les valeurs entre chevrons.
-- ============================================================================

-- ÉTAPE 0 — l'email exact à saisir dans le Dashboard, calculé à partir du
-- matricule par la même règle que l'application. Exécuter cette requête
-- seule, d'abord, et recopier son résultat : c'est le seul email avec lequel
-- la connexion par matricule retrouvera le compte.
--
--   select lower(regexp_replace('<MATRICULE>', '[^a-zA-Z0-9]', '', 'g'))
--          || '@sig.ensoa.ci' as email_a_creer;
--
--   « ADM-001 »  →  adm001@sig.ensoa.ci
--   « 12 345/AB »  →  12345ab@sig.ensoa.ci

update socle.profiles
set matricule       = '<MATRICULE>',        -- tel qu'il sera saisi à l'écran
    nom             = '<NOM>',
    prenom          = '<PRENOM>',
    grade           = '<GRADE>',
    role            = 'admin',              -- administrateur scolarité
    role_logistique = 'administrateur',     -- administrateur soutien technique
    actif           = true,
    doit_changer_mot_de_passe = true
where id = (
  select id from auth.users
  where email = '<MATRICULE NORMALISÉ>@sig.ensoa.ci'
);

-- Contrôle : une ligne, les deux rôles posés.
select matricule, nom_complet, grade, role, role_logistique, actif,
       doit_changer_mot_de_passe
from socle.profiles;
