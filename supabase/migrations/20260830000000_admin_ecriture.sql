-- ============================================================================
-- L'administrateur reçoit la main sur le soutien technique et l'officier
-- adjoint, et plus seulement le regard.
--
-- CE QUE ÇA CHANGE, ET IL FAUT LE SAVOIR :
--
-- Jusqu'ici, la migration 018b de l'application d'origine ne lui accordait
-- qu'une lecture transversale — « nécessaire au tableau de bord ». L'écriture
-- restait au garage, au soutien pétrolier, à l'armurerie, au poste de police
-- et au chef du Soutien Technique, chacun sur son domaine. C'était une
-- séparation des rôles : celui qui ouvre les comptes n'ajoutait pas d'armes à
-- l'inventaire.
--
-- Après cette migration, l'administrateur peut créer, modifier et supprimer
-- dans les 24 tables du soutien technique. Ce n'est pas un détail technique :
-- c'est un choix d'organisation, assumé, pour qu'il puisse tenir les écrans
-- lui-même. Ses actions restent tracées dans le journal (`socle.historique`),
-- qui enregistre l'auteur de chaque opération.
--
-- Pour revenir en arrière, il suffit de supprimer les politiques créées ici :
-- leur nom se termine toutes par `_admin_ecriture`.
-- ============================================================================

do $$
declare
  cible text;
  tables_st text[] := array[
    -- Parc et maintenance
    'vehicule', 'reparation', 'vidange', 'mouvement',
    'marque_vhl', 'modele_vhl', 'type_vhl',
    -- Carburant
    'soute', 'soute_type_stock', 'depotage', 'distribution',
    'repartition', 'type_stock',
    -- Armement
    'arme', 'dotation_arme', 'stock_munition', 'type_arme',
    'equipement_protection', 'dotation_equipement',
    -- Poste de police
    'passage_visiteur', 'passage_vehicule',
    -- Officier adjoint
    'activite', 'tache_activite',
    -- Personnel militaire
    'personnel'
  ];
begin
  foreach cible in array tables_st loop
    execute format(
      'drop policy if exists %I on logistique.%I',
      cible || '_admin_ecriture', cible
    );
    -- `for all` couvre la lecture, l'insertion, la modification et la
    -- suppression. Les politiques permissives s'additionnent : celles des
    -- chefs de service restent intactes, celle-ci s'ajoute.
    execute format(
      'create policy %I on logistique.%I for all to authenticated '
      'using (socle.current_user_role() = ''administrateur'') '
      'with check (socle.current_user_role() = ''administrateur'')',
      cible || '_admin_ecriture', cible
    );
  end loop;
end $$;

-- --- Organisation du service, restée dans le socle -------------------------
do $$
declare
  cible text;
begin
  foreach cible in array array['service', 'cellule'] loop
    execute format(
      'drop policy if exists %I on socle.%I',
      cible || '_admin_ecriture', cible
    );
    execute format(
      'create policy %I on socle.%I for all to authenticated '
      'using (socle.current_user_role() = ''administrateur'') '
      'with check (socle.current_user_role() = ''administrateur'')',
      cible || '_admin_ecriture', cible
    );
  end loop;
end $$;

-- Contrôle : 26 politiques doivent porter ce suffixe.
select count(*) as politiques_admin
from pg_policies
where policyname like '%\_admin\_ecriture'
  and schemaname in ('logistique', 'socle');
