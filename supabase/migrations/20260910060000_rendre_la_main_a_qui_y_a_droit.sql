-- ============================================================================
-- Rendre la main à qui y a droit.
--
-- RÉGRESSION INTRODUITE PAR LA MIGRATION PRÉCÉDENTE, corrigée ici.
--
-- J'ai refermé les consultations et les dépôts de fichiers en m'adossant à
-- `scolarite.commande_l_apprenant()`. Mauvais choix : cette fonction ne vaut
-- que pour le COMMANDANT DE BRIGADE — elle repose sur `commande_la_phase()`,
-- dont la première ligne est `socle.current_role() = 'commandant_brigade'`.
--
-- Conséquences mesurées contre la base :
--   * un commandant de division ne pouvait plus présenter un élève à
--     l'infirmerie : `new row violates row-level security policy` ;
--   * plus personne ne pouvait déposer une photo ni un document de cours —
--     pas même l'administrateur, car `admin_tout_pouvoir` ne couvre que les
--     trois schémas applicatifs, et `storage.objects` n'en fait pas partie.
--
-- Refermer une porte est facile ; la refermer sans enfermer ceux qui
-- travaillent demande de savoir exactement qui commande qui. D'où les deux
-- fonctions ci-dessous, qui disent cette hiérarchie une fois pour toutes.
-- ============================================================================

-- --- Qui peut agir sur un apprenant ----------------------------------------
-- L'administrateur ; le commandant de division pour sa division ; ceux de
-- promotion et de brigade pour leur promotion. Le service de santé a ses
-- propres politiques et n'a pas besoin de celle-ci.
create or replace function scolarite.peut_gerer_l_apprenant(p_apprenant_id uuid)
returns boolean
language sql
security definer
stable
set search_path = scolarite, socle, public
as $$
  select socle.est_administrateur()
      or exists (
        select 1
        from scolarite.apprenants a
        left join scolarite.classes c on c.id = a.classe_id
        where a.id = p_apprenant_id
          and (
            (socle.current_role() = 'chef_division'
               and a.division_id = socle.current_division())
            or (socle.current_role() in ('commandant_promotion', 'commandant_brigade')
               and c.promotion_id is not null
               and c.promotion_id = socle.current_promotion())
          )
      );
$$;

grant execute on function scolarite.peut_gerer_l_apprenant(uuid) to authenticated;

-- --- Qui peut agir sur un cours ---------------------------------------------
create or replace function scolarite.peut_gerer_le_cours(p_cours_id uuid)
returns boolean
language sql
security definer
stable
set search_path = scolarite, socle, public
as $$
  select socle.est_administrateur()
      or exists (
        select 1
        from scolarite.cours co
        join scolarite.classes c on c.id = co.classe_id
        where co.id = p_cours_id
          and (
            (socle.current_role() = 'chef_division'
               and c.division_id = socle.current_division())
            or (socle.current_role() in ('commandant_promotion', 'commandant_brigade')
               and c.promotion_id is not null
               and c.promotion_id = socle.current_promotion())
          )
      );
$$;

grant execute on function scolarite.peut_gerer_le_cours(uuid) to authenticated;

-- --- Les consultations : rendre sa place au commandant de division ---------
drop policy if exists consultations_medicales_presenter on scolarite.consultations_medicales;
drop policy if exists consultations_medicales_retirer on scolarite.consultations_medicales;

create policy consultations_medicales_presenter on scolarite.consultations_medicales
  for insert to authenticated
  with check (scolarite.peut_gerer_l_apprenant(apprenant_id));

create policy consultations_medicales_retirer on scolarite.consultations_medicales
  for delete to authenticated
  using (
    scolarite.peut_gerer_l_apprenant(apprenant_id)
    -- Une consultation que le service de santé a prise en charge n'est plus
    -- une erreur d'aiguillage : elle appartient au dossier médical.
    and statut = 'en_attente'
  );

-- Le commandant corrige la date qu'il a demandée, et rien d'autre. Les
-- colonnes du médecin — diagnostic, exemption, jours de repos,
-- hospitalisation — restent à leur valeur : la RLS ne sachant pas filtrer par
-- colonne, c'est un déclencheur qui les épingle.
create policy consultations_medicales_corriger on scolarite.consultations_medicales
  for update to authenticated
  using (scolarite.peut_gerer_l_apprenant(apprenant_id))
  with check (scolarite.peut_gerer_l_apprenant(apprenant_id));

create or replace function scolarite.le_diagnostic_reste_au_medecin()
returns trigger
language plpgsql
security definer
set search_path = scolarite, socle, public
as $$
begin
  -- L'administrateur et le service de santé écrivent ces colonnes ; eux
  -- seuls. Les autres peuvent toucher à la date et au motif de présentation.
  if socle.est_administrateur() or socle.current_role() = 'medecin' then
    return new;
  end if;

  new.statut := old.statut;
  new.jours_repos := old.jours_repos;
  new.exemption := old.exemption;
  new.exemption_details := old.exemption_details;
  new.hospitalisation_interne := old.hospitalisation_interne;
  new.hospitalisation_externe := old.hospitalisation_externe;
  new.pathologie := old.pathologie;
  new.pathologie_details := old.pathologie_details;
  return new;
end $$;

drop trigger if exists le_diagnostic_reste_au_medecin on scolarite.consultations_medicales;
create trigger le_diagnostic_reste_au_medecin
before update on scolarite.consultations_medicales
for each row execute function scolarite.le_diagnostic_reste_au_medecin();

-- --- Les dépôts de fichiers : rouvrir à qui y a droit -----------------------
drop policy if exists apprenant_photos_write on storage.objects;
drop policy if exists apprenant_photos_update on storage.objects;
drop policy if exists apprenant_photos_delete on storage.objects;

create policy apprenant_photos_write on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'apprenant-photos'
    and scolarite.peut_gerer_l_apprenant(nullif(split_part(name, '.', 1), '')::uuid)
  );

create policy apprenant_photos_update on storage.objects
  for update to authenticated
  using (
    bucket_id = 'apprenant-photos'
    and scolarite.peut_gerer_l_apprenant(
          nullif(split_part(storage.objects.name, '.', 1), '')::uuid)
  );

create policy apprenant_photos_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'apprenant-photos'
    and scolarite.peut_gerer_l_apprenant(
          nullif(split_part(storage.objects.name, '.', 1), '')::uuid)
  );

drop policy if exists cours_documents_write on storage.objects;
drop policy if exists cours_documents_update on storage.objects;
drop policy if exists cours_documents_delete on storage.objects;

create policy cours_documents_write on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'cours-documents'
    and scolarite.peut_gerer_le_cours(nullif(split_part(name, '.', 1), '')::uuid)
  );

create policy cours_documents_update on storage.objects
  for update to authenticated
  using (
    bucket_id = 'cours-documents'
    and scolarite.peut_gerer_le_cours(
          nullif(split_part(storage.objects.name, '.', 1), '')::uuid)
  );

create policy cours_documents_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'cours-documents'
    and scolarite.peut_gerer_le_cours(
          nullif(split_part(storage.objects.name, '.', 1), '')::uuid)
  );

-- --- Les épreuves : même correction ----------------------------------------
-- `commande_la_phase` y était déjà employée par la migration précédente, avec
-- le même défaut : seul un commandant de brigade pouvait écrire une question.
drop policy if exists qcm_questions_encadrement on scolarite.qcm_questions;
create policy qcm_questions_encadrement on scolarite.qcm_questions
  for all to authenticated
  using (
    socle.current_role() is distinct from 'eleve_stagiaire'
    and scolarite.peut_gerer_le_cours(qcm_questions.devoir_id)
  )
  with check (
    socle.current_role() is distinct from 'eleve_stagiaire'
    and scolarite.peut_gerer_le_cours(devoir_id)
  );

drop policy if exists qcm_propositions_encadrement on scolarite.qcm_propositions;
create policy qcm_propositions_encadrement on scolarite.qcm_propositions
  for all to authenticated
  using (
    socle.current_role() is distinct from 'eleve_stagiaire'
    and exists (
      select 1 from scolarite.qcm_questions q
      where q.id = qcm_propositions.question_id
        and scolarite.peut_gerer_le_cours(q.devoir_id)
    )
  )
  with check (
    socle.current_role() is distinct from 'eleve_stagiaire'
    and exists (
      select 1 from scolarite.qcm_questions q
      where q.id = qcm_propositions.question_id
        and scolarite.peut_gerer_le_cours(q.devoir_id)
    )
  );
