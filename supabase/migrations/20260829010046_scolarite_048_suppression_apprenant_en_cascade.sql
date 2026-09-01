-- ============================================================================
-- SCOLARITÉ (ENSOA GSES) — repris de 048_suppression_apprenant_en_cascade.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- Migration : débloquer la suppression d'un apprenant.
--
-- Supprimer un apprenant échouait sur une violation de clé étrangère, et le
-- coupable n'était pas évident : toutes les tables qui référencent
-- directement `apprenants` sont déjà en cascade — notes, permissions,
-- absences, consultations, antécédents, examens de visite, copies de QCM.
--
-- Le blocage venait d'un cran plus loin :
--
--   apprenant → consultations_medicales (cascade) → depenses (RESTRICT)
--
-- La suppression de l'apprenant emportait ses consultations, mais une
-- dépense rattachée à l'une d'elles s'y opposait — d'où l'échec.
--
-- ---------------------------------------------------------------------------
-- Ce `restrict` n'était pas une erreur : il protégeait la comptabilité. Une
-- analyse, une radio, une évacuation sanitaire ont été payées ; la dépense
-- ne doit pas s'évaporer parce qu'on retire une fiche d'apprenant, sans quoi
-- le bilan d'un mois déjà arrêté changerait rétroactivement.
--
-- On garde donc la dépense et on coupe seulement le lien : `set null` plutôt
-- que `cascade`. La dépense conserve sa date, son montant, sa catégorie et
-- son libellé — tout ce qui fait une pièce comptable. Elle perd le renvoi
-- vers une consultation qui, de toute façon, n'existe plus.
--
-- La contrainte `depenses_rattachement` doit suivre : elle exigeait qu'une
-- dépense de type « consultation » désigne une consultation. Cette exigence
-- reste vraie à la saisie — le formulaire l'impose — mais ne peut plus
-- l'être une fois la consultation supprimée.

alter table scolarite.depenses
  drop constraint if exists depenses_consultation_id_fkey;

alter table scolarite.depenses
  add constraint depenses_consultation_id_fkey
  foreign key (consultation_id)
  references scolarite.consultations_medicales (id)
  on delete set null;

alter table scolarite.depenses
  drop constraint if exists depenses_rattachement;

-- Une dépense de service ne se rattache à aucune consultation ; une dépense
-- de consultation en désigne une, ou plus aucune si celle-ci a été
-- supprimée avec l'apprenant.
alter table scolarite.depenses
  add constraint depenses_rattachement check (
    type = 'consultation' or consultation_id is null
  );
