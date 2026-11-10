-- ============================================================================
-- LOGISTIQUE (ERP ENSOA) — migration 025 : chef de bord sur l'ordre de mission
--
-- Migration propre à l'application unifiée (non issue du portage des deux
-- bases d'origine). À appliquer avec `supabase db push`, ou collée dans
-- l'éditeur SQL de Supabase.
-- ============================================================================

-- Un ordre de mission distingue désormais deux personnes :
--   * le CONDUCTEUR, déjà enregistré dans les colonnes `*_chef_bord`
--     (grade_chef_bord, nom_chef_bord, contact_chef_bord) ;
--   * le CHEF DE BORD, qui commande la mission — ajouté ici (grade + nom).
--
-- On n'ajoute que les deux colonnes du chef de bord ; on ne renomme pas les
-- colonnes du conducteur, l'application les lit déjà telles quelles.

alter table logistique.mouvement
  add column if not exists grade_chef_de_bord text not null default '';
alter table logistique.mouvement
  add column if not exists nom_chef_de_bord text not null default '';

-- Le défaut n'a servi qu'à peupler les lignes déjà là ; un nouvel ordre doit
-- nommer son chef de bord.
alter table logistique.mouvement alter column grade_chef_de_bord drop default;
alter table logistique.mouvement alter column nom_chef_de_bord drop default;
