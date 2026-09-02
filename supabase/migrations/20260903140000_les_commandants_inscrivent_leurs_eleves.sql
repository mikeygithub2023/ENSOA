-- ============================================================================
-- Les commandants inscrivent leurs élèves.
--
-- Le Commandant de Division le pouvait déjà. Ceux de Promotion et de Brigade
-- non : ils pouvaient corriger une fiche existante — `apprenants_update_
-- commandant`, migration 054 — mais pas en ouvrir une. Or c'est le
-- commandement de la promotion qui reçoit les nouveaux et les répartit.
--
-- Inscrire un élève touche trois tables, et il faut les trois : la fiche
-- elle-même, le catalogue des diplômes quand la formation civile en apporte
-- un qui n'y figure pas encore, et le lien entre les deux. Ouvrir la
-- première sans les autres ferait échouer l'enregistrement dès qu'une fiche
-- porte un diplôme — panne d'autant plus obscure qu'elle ne surviendrait
-- qu'une fois sur deux.
--
-- La portée ne bouge pas : les phases de leur promotion, et elles seules.
-- ============================================================================

-- --- 1. La fiche ------------------------------------------------------------
drop policy if exists apprenants_insert_commandant on scolarite.apprenants;
create policy apprenants_insert_commandant on scolarite.apprenants
  for insert to authenticated
  with check (scolarite.commande_la_phase(classe_id));

-- --- 2. Le catalogue des diplômes -------------------------------------------
-- Il ne fait que s'étendre : on y ajoute « BTS Comptabilité » quand un élève
-- le présente, et personne ne l'en retire. L'ouvrir à qui inscrit ne coûte
-- donc rien.
drop policy if exists diplomes_insert_commandant on scolarite.diplomes;
create policy diplomes_insert_commandant on scolarite.diplomes
  for insert to authenticated
  with check (
    socle.current_role() in ('commandant_promotion', 'commandant_brigade')
  );

-- --- 3. Le lien entre l'élève et ses diplômes -------------------------------
drop policy if exists apprenant_diplomes_write_commandant
  on scolarite.apprenant_diplomes;
create policy apprenant_diplomes_write_commandant
  on scolarite.apprenant_diplomes
  for all to authenticated
  using (scolarite.commande_l_apprenant(apprenant_id))
  with check (scolarite.commande_l_apprenant(apprenant_id));

-- ============================================================================
-- Contrôle : les trois politiques sont en place.
-- ============================================================================
select tablename, policyname, cmd
from pg_policies
where schemaname = 'scolarite'
  and policyname in (
    'apprenants_insert_commandant',
    'diplomes_insert_commandant',
    'apprenant_diplomes_write_commandant'
  )
order by tablename;
