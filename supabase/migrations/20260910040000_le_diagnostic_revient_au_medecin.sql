-- ============================================================================
-- Le diagnostic revient au médecin, et les épreuves à l'encadrement.
--
-- QUATRE DÉFAUTS CORRIGÉS ICI.
--
-- --- 1. Un commandant réécrivait le diagnostic médical ----------------------
--
-- La migration 20260903050000 porte ce commentaire : « Ce qui reste au
-- médecin — le traitement, le diagnostic — est porté par ses propres colonnes
-- ET SA PROPRE POLITIQUE. »
--
-- Cette politique n'existe pas. Et la RLS ne sait pas restreindre colonne par
-- colonne : un `for all` sur la ligne donne toutes les colonnes de la ligne.
-- Un commandant de promotion ou de brigade pouvait donc réécrire un
-- diagnostic, annuler une exemption médicale, retirer des jours de repos,
-- effacer une hospitalisation — et supprimer la consultation entière.
--
-- Son besoin réel, que le même commentaire énonce, est de « délivrer
-- l'autorisation de consulter » : créer la ligne, et la retirer s'il s'est
-- trompé d'élève. Pas de la modifier.
--
-- --- 2. Un élève supprimait les questions de son propre devoir --------------
--
-- `qcm_questions_all` ne vérifiait qu'une chose : que le cours parent soit
-- VISIBLE. Or un élève voit les devoirs de sa classe. Le `for all` lui
-- donnait donc `update` et `delete` : supprimer les questions difficiles
-- avant de composer. Le correctif appliqué à la table sœur
-- `qcm_propositions` avait oublié celle-ci.
--
-- --- 3. Les clés de réponse étaient ouvertes à toute la scolarité -----------
--
-- `qcm_propositions_encadrement` n'avait pour prédicat que « ne pas être
-- élève ». Un médecin, un commandant de brigade borné au sport, un
-- commandant d'une autre division lisaient et modifiaient les bonnes réponses
-- de tous les devoirs de l'école. On adosse la politique au cours, dont le
-- cloisonnement par division et par phase est, lui, correct.
--
-- --- 4. Le chef du soutien technique pouvait nommer un administrateur -------
--
-- `"profil chef st update"` épinglait `role_logistique` dans son `with check`,
-- mais pas `role` — la colonne de la scolarité. Il pouvait donc poser
-- `role = 'admin'` sur le compte d'un garagiste, lui ouvrant les dossiers
-- médicaux et les notes de toute l'école. Exactement ce que la migration
-- fondatrice disait vouloir éviter : « une politique mal retranscrite, c'est
-- le dossier médical d'un élève ouvert au garage ».
-- ============================================================================

-- --- 1. Consultations médicales ---------------------------------------------
drop policy if exists consultations_medicales_write_commandant on scolarite.consultations_medicales;
drop policy if exists consultations_medicales_write_chef_division on scolarite.consultations_medicales;

create policy consultations_medicales_presenter on scolarite.consultations_medicales
  for insert to authenticated
  with check (scolarite.commande_l_apprenant(apprenant_id));

create policy consultations_medicales_retirer on scolarite.consultations_medicales
  for delete to authenticated
  using (
    scolarite.commande_l_apprenant(apprenant_id)
    -- Une consultation que le service de santé a commencé à traiter n'est
    -- plus une erreur d'aiguillage : elle appartient au dossier médical.
    and statut = 'en_attente'
  );

-- --- 2 et 3. Les épreuves ---------------------------------------------------
drop policy if exists qcm_questions_all on scolarite.qcm_questions;

create policy qcm_questions_encadrement on scolarite.qcm_questions
  for all to authenticated
  using (
    socle.current_role() is distinct from 'eleve_stagiaire'
    and exists (
      select 1 from scolarite.cours c
      where c.id = qcm_questions.devoir_id
        and scolarite.commande_la_phase(c.classe_id)
    )
  )
  with check (
    socle.current_role() is distinct from 'eleve_stagiaire'
    and exists (
      select 1 from scolarite.cours c
      where c.id = qcm_questions.devoir_id
        and scolarite.commande_la_phase(c.classe_id)
    )
  );

-- L'élève lit les questions de son devoir ; il ne les écrit pas.
create policy qcm_questions_select_eleve on scolarite.qcm_questions
  for select to authenticated
  using (exists (select 1 from scolarite.cours c where c.id = qcm_questions.devoir_id));

drop policy if exists qcm_propositions_encadrement on scolarite.qcm_propositions;
create policy qcm_propositions_encadrement on scolarite.qcm_propositions
  for all to authenticated
  using (
    socle.current_role() is distinct from 'eleve_stagiaire'
    and exists (
      select 1 from scolarite.qcm_questions q
      join scolarite.cours c on c.id = q.devoir_id
      where q.id = qcm_propositions.question_id
        and scolarite.commande_la_phase(c.classe_id)
    )
  )
  with check (
    socle.current_role() is distinct from 'eleve_stagiaire'
    and exists (
      select 1 from scolarite.qcm_questions q
      join scolarite.cours c on c.id = q.devoir_id
      where q.id = qcm_propositions.question_id
        and scolarite.commande_la_phase(c.classe_id)
    )
  );

-- --- 4. Le chef du soutien technique ----------------------------------------
drop policy if exists "profil chef st update" on socle.profiles;
create policy "profil chef st update" on socle.profiles
  for update to authenticated
  using (
    socle.current_user_role() = 'chef_soutien_technique'
    and role_logistique in ('soutien_petrolier', 'garage', 'armurerie')
    -- Il n'administre que des comptes purement logistiques. Un compte qui
    -- porte aussi un rôle de scolarité ne relève pas de lui.
    and role is null
  )
  with check (
    socle.current_user_role() = 'chef_soutien_technique'
    and role_logistique in ('soutien_petrolier', 'garage', 'armurerie')
    and role is null
  );

-- ============================================================================
-- Contrôle : doit retourner 0 ligne.
-- Une politique d'écriture sur les consultations qui porterait encore sur
-- toutes les colonnes.
-- ============================================================================
select policyname, cmd
from pg_policies
where schemaname = 'scolarite' and tablename = 'consultations_medicales'
  and cmd = 'ALL' and policyname <> 'admin_tout_pouvoir';
