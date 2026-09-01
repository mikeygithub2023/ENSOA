-- ============================================================================
-- SCOLARITÉ (ENSOA GSES) — repris de 032_consultation_pathologie.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- Migration : la pathologie dont souffre le patient, constatée lors de la
-- consultation.
--
-- Deux colonnes plutôt qu'une : `pathologie` est un grand groupe clinique
-- pris dans une liste fermée — c'est lui qui rend le volet santé
-- exploitable en statistiques (de quoi la troupe souffre-t-elle pendant sa
-- formation ?), qu'un champ libre fragmenterait à la moindre variante
-- d'orthographe. `pathologie_details` reçoit le diagnostic précis en clair,
-- que la liste ne saurait couvrir sans devenir une nomenclature médicale.
--
-- La colonne reste facultative : les consultations déjà enregistrées n'en
-- ont pas, et une consultation peut se conclure sans pathologie constatée.

alter table scolarite.consultations_medicales
  add column pathologie text check (
    pathologie in (
      'paludisme',
      'infection_respiratoire',
      'trouble_digestif',
      'traumatologie',
      'dermatologie',
      'dentaire',
      'ophtalmologie',
      'fievre_typhoide',
      'cephalees',
      'uro_genital',
      'allergie',
      'pathologie_chronique',
      'autre'
    )
  );

alter table scolarite.consultations_medicales
  add column pathologie_details text;
