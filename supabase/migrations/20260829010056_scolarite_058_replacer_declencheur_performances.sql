-- ============================================================================
-- SCOLARITÉ (ENSOA GSES) — repris de 058_replacer_declencheur_performances.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- Migration : rétablir le déclencheur qui transforme une performance en
-- note.
--
-- La migration 056 a refait `performances_sportives` — la performance se
-- rattache désormais à une séance et non plus à une épreuve. Refaire la
-- table a emporté ses déclencheurs, et si l'audit a bien été recréé,
-- `sync_note_performance` (migration 055) ne l'a pas été.
--
-- Conséquence : la performance s'enregistrait, mais rien n'écrivait la note
-- correspondante dans `notes`. Le calcul était juste, le barème lu
-- correctement — simplement, personne ne le déclenchait. Toute séance
-- restait donc sans note, sans qu'aucune erreur ne le signale.

drop trigger if exists sync_note_performance on scolarite.performances_sportives;
create trigger sync_note_performance
  after insert or update or delete on scolarite.performances_sportives
  for each row execute function scolarite.trg_performance_sportive();

-- Rattrapage des performances déjà saisies entre-temps, s'il y en a : elles
-- n'ont jamais produit de note.
do $$
declare
  v_performance record;
begin
  for v_performance in
    select sous_module_id, apprenant_id from scolarite.performances_sportives
  loop
    perform scolarite.sync_note_sportive(
      v_performance.sous_module_id,
      v_performance.apprenant_id
    );
  end loop;
end;
$$;
