-- ============================================================================
-- LOGISTIQUE (ERP ENSOA) — repris de migration_004_correction_repartitions.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- ============================================================================
-- Correction : chaque répartition de la Soute Bouaké mélange Gasoil ET Super
-- (le modèle le supportait déjà — seules les données de départ étaient fausses,
-- tout avait été mis en Gasoil par erreur). À exécuter après migration_003.
-- ============================================================================

update logistique.soute_type_stock set qte_gasoil = 1000, qte_super = 1500
where soute_id = 1 and repartition_id = (select id from logistique.repartition where libelle = 'BA1');

update logistique.soute_type_stock set qte_gasoil = 1000, qte_super = 0
where soute_id = 1 and repartition_id = (select id from logistique.repartition where libelle = 'CA2');

update logistique.soute_type_stock set qte_gasoil = 1000, qte_super = 500
where soute_id = 1 and repartition_id = (select id from logistique.repartition where libelle = 'CA1');
