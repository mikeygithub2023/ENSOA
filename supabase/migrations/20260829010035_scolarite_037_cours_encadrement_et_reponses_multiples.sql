-- ============================================================================
-- SCOLARITÉ (ENSOA GSES) — repris de 037_cours_encadrement_et_reponses_multiples.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- Migration : deux corrections du module Cours.
--
-- 1. L'élève/stagiaire ne dépose pas de cours : il les consulte. Seul
--    l'encadrement alimente la plateforme. La migration 036 avait ouvert le
--    dépôt à tous — on referme.
--
-- 2. Une question de QCM peut avoir plusieurs bonnes réponses. L'index
--    unique posé en 036 l'interdisait ; il tombe.
--
--    Le barème s'applique dès lors à chaque proposition cochée, ce qui est
--    la lecture littérale de la règle de l'école : chaque bonne réponse
--    cochée vaut +1, chaque mauvaise cochée −1, une proposition laissée de
--    côté ne compte ni pour ni contre. Une question vaut donc autant de
--    points qu'elle compte de bonnes réponses, et le total d'un devoir est
--    la somme de ces maxima.

drop policy if exists cours_insert on scolarite.cours;

create policy cours_insert on scolarite.cours
  for insert to authenticated
  with check (
    socle.current_role() in ('admin', 'medecin')
    or (
      socle.current_role() in ('chef_division', 'instructeur')
      and division_id = socle.current_division()
    )
  );

drop index if exists scolarite.qcm_propositions_une_seule_correcte;
