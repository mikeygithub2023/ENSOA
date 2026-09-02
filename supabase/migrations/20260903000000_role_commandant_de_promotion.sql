-- ============================================================================
-- Un nouveau poste : le Commandant de Promotion.
--
-- Il commande une promotion, comme le Commandant de Brigade, mais avec les
-- droits du Commandant de Division sur son périmètre : lecture ET écriture
-- sur les notes, les cours, les devoirs et les exercices de sa promotion.
-- Le Commandant de Brigade, lui, ne notera plus que le sport.
--
-- Cette migration ne fait qu'ajouter la valeur à l'énumération. PostgreSQL
-- interdit de s'en servir dans la transaction qui la crée : les politiques
-- qui la nomment viennent donc dans le fichier suivant.
-- ============================================================================

alter type socle.app_role add value if not exists 'commandant_promotion';
