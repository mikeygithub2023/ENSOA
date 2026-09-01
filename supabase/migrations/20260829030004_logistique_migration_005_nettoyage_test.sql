-- ============================================================================
-- LOGISTIQUE (ERP ENSOA) — repris de migration_005_nettoyage_test.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- ============================================================================
-- Nettoyage : supprime la ligne de test créée par erreur pendant les essais
-- du formulaire Distribution (Soute Abidjan avait reçu par erreur 5000 L de
-- Gasoil sous la répartition BA1, alors qu'Abidjan ne devrait avoir que
-- "Général"). On supprime d'abord les dépotages/distributions de test qui
-- référencent cette ligne, puis la ligne elle-même.
-- ============================================================================

delete from logistique.distribution
where soute_stock_id = (
  select sts.id from logistique.soute_type_stock sts
  where sts.soute_id = (select id from logistique.soute where libelle = 'Soute Abidjan')
    and sts.repartition_id = (select id from logistique.repartition where libelle = 'BA1')
);

delete from logistique.depotage
where soute_stock_id = (
  select sts.id from logistique.soute_type_stock sts
  where sts.soute_id = (select id from logistique.soute where libelle = 'Soute Abidjan')
    and sts.repartition_id = (select id from logistique.repartition where libelle = 'BA1')
);

delete from logistique.soute_type_stock
where soute_id = (select id from logistique.soute where libelle = 'Soute Abidjan')
  and repartition_id = (select id from logistique.repartition where libelle = 'BA1');
