-- ============================================================================
-- LOGISTIQUE (ERP ENSOA) — repris de migration_019_cst_taches_equipe.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- ============================================================================
-- Le CST supervise Soutien pétrolier, Garage et Armurerie : il doit pouvoir
-- voir (lecture seule) les tâches assignées par l'OA à ces 3 acteurs, pas
-- seulement les tâches "st" comme le permettait la policy d'origine.
-- ============================================================================

create policy "tache select cst" on logistique.tache_activite for select using (
  socle.current_user_role() = 'chef_soutien_technique' and acteur in ('st', 'garage', 'armurerie')
);
