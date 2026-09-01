-- ============================================================================
-- SCOLARITÉ (ENSOA GSES) — repris de 059_suppression_promotion_en_cascade.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- Migration : supprimer une promotion emporte réellement tout ce qui en
-- dépend.
--
-- `classes.promotion_id` cascade déjà : retirer une promotion retire ses
-- phases. Mais six tables pointent vers une phase sans règle de
-- suppression — apprenants, contrôles, cours, absences, permissions,
-- consultations, visites médicales. La cascade butait donc sur la première
-- d'entre elles, et la suppression échouait sur une violation de clé
-- étrangère.
--
-- L'écran promettait pourtant l'inverse : « ses phases — leurs matières,
-- modules, évaluations et notes comprises ». C'est cette promesse qu'on
-- tient ici.
--
-- Une fois ces liens en cascade, la chaîne est complète : la promotion
-- emporte ses phases, chaque phase ses apprenants et ses contrôles, chaque
-- apprenant ses notes, absences, permissions et consultations, chaque
-- contrôle ses sous-modules et ses notes. Tout ce qui pend aux apprenants
-- et aux contrôles cascadait déjà.
--
-- Ce que la base ne peut PAS emporter : les comptes d'authentification des
-- élèves. Ils vivent dans `auth.users`, hors d'atteinte d'une contrainte
-- de clé étrangère, et leur suppression demande la clé de service (voir la
-- fonction `delete-user`). Supprimer une promotion laisse donc derrière
-- elle les comptes de ses élèves, à fermer depuis Administration ›
-- Espaces élèves.

-- --- Les apprenants ---------------------------------------------------------
alter table scolarite.apprenants
  drop constraint if exists apprenants_classe_id_fkey;
alter table scolarite.apprenants
  add constraint apprenants_classe_id_fkey
  foreign key (classe_id) references scolarite.classes (id) on delete cascade;

-- --- Les évaluations --------------------------------------------------------
alter table scolarite.controles
  drop constraint if exists controles_classe_id_fkey;
alter table scolarite.controles
  add constraint controles_classe_id_fkey
  foreign key (classe_id) references scolarite.classes (id) on delete cascade;

-- --- La vie de la phase -----------------------------------------------------
alter table scolarite.absences
  drop constraint if exists absences_classe_id_fkey;
alter table scolarite.absences
  add constraint absences_classe_id_fkey
  foreign key (classe_id) references scolarite.classes (id) on delete cascade;

alter table scolarite.permissions
  drop constraint if exists permissions_classe_id_fkey;
alter table scolarite.permissions
  add constraint permissions_classe_id_fkey
  foreign key (classe_id) references scolarite.classes (id) on delete cascade;

alter table scolarite.consultations_medicales
  drop constraint if exists consultations_medicales_classe_id_fkey;
alter table scolarite.consultations_medicales
  add constraint consultations_medicales_classe_id_fkey
  foreign key (classe_id) references scolarite.classes (id) on delete cascade;

alter table scolarite.visites_medicales
  drop constraint if exists visites_medicales_classe_id_fkey;
alter table scolarite.visites_medicales
  add constraint visites_medicales_classe_id_fkey
  foreign key (classe_id) references scolarite.classes (id) on delete cascade;
