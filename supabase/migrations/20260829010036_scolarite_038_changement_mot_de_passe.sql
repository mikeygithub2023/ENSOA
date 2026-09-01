-- ============================================================================
-- SCOLARITÉ (ENSOA GSES) — repris de 038_changement_mot_de_passe.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- Migration : imposer le changement du mot de passe à la première
-- connexion.
--
-- L'espace élève s'ouvre avec le numéro de téléphone pour mot de passe.
-- Ce numéro n'est pas un secret : il figure sur la fiche de l'élève et ses
-- camarades le connaissent. Il ne vaut donc que comme mot de passe
-- d'ouverture, et l'élève doit en choisir un autre avant d'accéder à quoi
-- que ce soit.
--
-- Le drapeau vit sur le profil plutôt que dans les métadonnées du compte
-- auth : l'application le lit déjà avec le rôle et la division, sans appel
-- supplémentaire.
--
-- Par défaut à `false` : les comptes existants, dont le mot de passe a été
-- choisi par un administrateur puis transmis de la main à la main, ne sont
-- pas concernés. Seule la fonction `espaces-eleves` le lève, à l'ouverture
-- d'un espace.

alter table socle.profiles
  add column doit_changer_mot_de_passe boolean not null default false;

-- Chacun peut lever son propre drapeau, et lui seul : c'est le pendant du
-- changement de mot de passe, qui n'est possible que sur son propre compte.
-- `profiles_update_admin` couvre déjà l'administrateur.
create policy profiles_update_self on socle.profiles
  for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());
