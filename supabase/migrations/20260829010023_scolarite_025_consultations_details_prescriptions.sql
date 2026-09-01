-- ============================================================================
-- SCOLARITÉ (ENSOA GSES) — repris de 025_consultations_details_prescriptions.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- Migration : détails saisis quand l'exemption ou une hospitalisation est
-- activée sur une consultation — l'UI passe d'une case à cocher à un
-- bouton bascule qui révèle un champ de détail/lieu une fois activé.

alter table scolarite.consultations_medicales add column exemption_details text;
alter table scolarite.consultations_medicales add column hospitalisation_interne_lieu text;
alter table scolarite.consultations_medicales add column hospitalisation_externe_lieu text;
