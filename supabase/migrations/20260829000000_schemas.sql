-- ============================================================================
-- Les trois schémas de la base unifiée.
--
-- Ils se créent À CÔTÉ de ce que contient déjà le projet : rien n'est effacé
-- pour démarrer. Les anciennes tables du soutien technique restent dans
-- `public`, intactes — elles font office de sauvegarde tant que la nouvelle
-- application n'a pas fait ses preuves. On ne les supprimera qu'à la bascule.
--
-- Retour en arrière complet :
--   drop schema socle, scolarite, logistique cascade;
--
-- Séparer par schéma plutôt que fusionner les tables : les deux bases
-- d'origine ont des noms qui se percutent (profiles, personnel/apprenants,
-- notification/notifications, historique/audit_log, activite/activites_
-- sportives). Dans des schémas distincts, la collision n'existe plus, et
-- chaque module garde le SQL qui a déjà fait ses preuves en production.
-- ============================================================================

create schema if not exists socle;
create schema if not exists scolarite;
create schema if not exists logistique;

comment on schema socle is
  'Commun aux deux modules : identité (profiles), organisation, journaux.';
comment on schema scolarite is
  'Élèves et stagiaires : scolarité, notes, santé, cours.';
comment on schema logistique is
  'Soutien Technique : parc, carburant, armement, poste de police, OA.';

-- Sans USAGE sur le schéma, PostgREST renvoie 42501 même si les politiques
-- RLS sont correctes : la RLS filtre les lignes, encore faut-il avoir le
-- droit d'entrer dans le schéma.
grant usage on schema socle       to anon, authenticated, service_role;
grant usage on schema scolarite   to anon, authenticated, service_role;
grant usage on schema logistique  to anon, authenticated, service_role;

-- Le déclencheur de notification push du soutien technique appelle
-- `net.http_post` : sans pg_net, la migration du module échoue.
create extension if not exists pg_net with schema extensions;

-- RAPPEL DE DÉPLOIEMENT : les trois schémas doivent aussi être déclarés dans
-- Dashboard > Settings > API > Exposed schemas, sinon l'API REST ne les voit
-- pas. Côté Flutter : supabase.schema('logistique').from('vehicule').
