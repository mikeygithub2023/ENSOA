-- ============================================================================
-- RETOUR EN ARRIÈRE — annule l'installation de la base unifiée.
--
-- Les trois schémas ont été créés à côté de l'existant : les supprimer remet
-- le projet exactement dans l'état où il était. Les anciennes tables du
-- soutien technique, restées dans `public`, n'ont jamais été touchées.
--
-- À exécuter dans Dashboard > SQL Editor du projet ENSOA.
--
-- ⚠ Après la bascule, ce script détruirait la base de production. Il n'est
--   valable que TANT QUE la nouvelle application n'est pas en service.
-- ============================================================================

begin;

drop schema if exists scolarite  cascade;
drop schema if exists logistique cascade;
drop schema if exists socle      cascade;

-- Le déclencheur sur auth.users pointe vers socle.handle_new_user() : le
-- cascade l'emporte avec la fonction, mais on s'en assure.
drop trigger if exists on_auth_user_created on auth.users;

commit;

-- Contrôle : doit renvoyer 0.
select count(*) as schemas_restants
from information_schema.schemata
where schema_name in ('socle', 'scolarite', 'logistique');
