-- ============================================================================
-- Le Commandant de Brigade tient aussi les cours de ses phases.
--
-- Il les voyait déjà — `cours_select_commandant`, migration 054 — mais ne
-- pouvait ni en déposer, ni en corriger, ni en retirer un. Or il commande la
-- promotion : le programme de ses phases relève de lui autant que les notes,
-- qu'il saisit depuis le début.
--
-- L'administrateur et l'instructeur, eux, avaient déjà la main : le premier
-- sur toute l'école, le second sur sa division. Rien ne change pour eux.
--
-- La portée est la même que partout ailleurs pour ce poste :
-- `commande_la_phase` — la phase appartient-elle à la promotion inscrite à
-- son profil ? Il ne gagne donc rien en dehors d'elle.
-- ============================================================================

drop policy if exists cours_insert_commandant on scolarite.cours;
create policy cours_insert_commandant on scolarite.cours
  for insert to authenticated
  with check (scolarite.commande_la_phase(classe_id));

drop policy if exists cours_update_commandant on scolarite.cours;
create policy cours_update_commandant on scolarite.cours
  for update to authenticated
  using (scolarite.commande_la_phase(classe_id))
  with check (scolarite.commande_la_phase(classe_id));

drop policy if exists cours_delete_commandant on scolarite.cours;
create policy cours_delete_commandant on scolarite.cours
  for delete to authenticated
  using (scolarite.commande_la_phase(classe_id));

-- --- Ce qui accompagne un cours ---------------------------------------------
-- Un cours porte des questions de QCM et reçoit des devoirs rendus. Les
-- politiques de ces tables se règlent sur le cours dont elles relèvent : on
-- y ajoute le commandant de la même façon, quand ces tables existent.

do $$
begin
  if to_regclass('scolarite.qcm_questions') is not null then
    execute $p$
      drop policy if exists qcm_questions_commandant on scolarite.qcm_questions;
      create policy qcm_questions_commandant on scolarite.qcm_questions
        for all to authenticated
        using (
          exists (
            select 1 from scolarite.cours c
            where c.id = qcm_questions.devoir_id
              and scolarite.commande_la_phase(c.classe_id)
          )
        )
        with check (
          exists (
            select 1 from scolarite.cours c
            where c.id = qcm_questions.devoir_id
              and scolarite.commande_la_phase(c.classe_id)
          )
        );
    $p$;
  end if;
end $$;

-- ============================================================================
-- Contrôle : les politiques du commandant sur les cours sont-elles en place ?
-- ============================================================================
select policyname, cmd
from pg_policies
where schemaname = 'scolarite'
  and tablename = 'cours'
  and policyname like '%commandant%'
order by policyname;
