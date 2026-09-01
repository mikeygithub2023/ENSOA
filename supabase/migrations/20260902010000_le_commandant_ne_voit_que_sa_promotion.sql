-- ============================================================================
-- Le Commandant de Brigade ne voit que sa promotion.
--
-- Il en voyait deux. La règle écrite pour lui était pourtant juste — elle ne
-- laisse passer que la promotion qu'il commande. Mais les politiques
-- permissives de PostgreSQL s'additionnent : il suffit qu'UNE seule accepte
-- la ligne pour qu'elle soit visible. Et `promotions_select`, écrite bien
-- avant que ce poste n'existe, acceptait :
--
--     socle.current_role() in ('admin', 'medecin')
--     or division_id = socle.current_division()
--
-- La seconde branche ne vérifie aucun rôle. Elle ouvre donc toutes les
-- promotions de sa division à quiconque a une division inscrite au profil —
-- et le Commandant de Brigade en a une, celle dont relève sa promotion.
--
-- On borne cette branche aux postes auxquels elle était destinée : le chef de
-- division, l'instructeur, et l'élève qui consulte la sienne. Personne n'y
-- perd ce qu'il avait ; le commandant cesse d'y gagner ce qu'il ne devait pas
-- avoir.
--
-- ⚠ Leçon à retenir pour la suite : une politique sans condition de rôle est
-- une porte ouverte à tous les rôles à venir. Les autres politiques de la
-- scolarité nomment le leur — celle-ci était la seule à ne pas le faire.
-- ============================================================================

drop policy if exists promotions_select on scolarite.promotions;
create policy promotions_select on scolarite.promotions
  for select to authenticated
  using (
    socle.current_role() in ('admin', 'medecin')
    or (
      socle.current_role() in ('chef_division', 'instructeur', 'eleve_stagiaire')
      and division_id = socle.current_division()
    )
  );

-- ============================================================================
-- Contrôle : ce que voit chaque commandant de brigade rattaché à une
-- promotion. La colonne `promotions_visibles` doit valoir 1 pour chacun.
-- ============================================================================
select
  p.matricule,
  p.nom_complet,
  pr.nom as promotion_commandee,
  (
    select count(*)
    from scolarite.promotions x
    where
      'commandant_brigade' in ('admin', 'medecin')
      or (
        'commandant_brigade' in ('chef_division', 'instructeur', 'eleve_stagiaire')
        and x.division_id = p.division_id
      )
      or x.id = p.promotion_id
  ) as promotions_visibles
from socle.profiles p
left join scolarite.promotions pr on pr.id = p.promotion_id
where p.role = 'commandant_brigade';
