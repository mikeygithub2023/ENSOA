-- ============================================================================
-- SCOLARITÉ (ENSOA GSES) — repris de 024_medicaments_type.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- Migration : classe pharmacologique de chaque médicament, pour pouvoir
-- ranger le catalogue par type (comme dans un logiciel de pharmacie). Liste
-- fermée (pas de catalogue libre géré par l'admin) pour garantir un
-- regroupement cohérent — un champ texte libre fragmenterait les groupes au
-- moindre écart de saisie.

alter table scolarite.medicaments
  add column type text not null default 'autre'
  check (type in (
    'antalgique',
    'antibiotique',
    'antipaludeen',
    'anti_inflammatoire',
    'antiseptique',
    'antihistaminique',
    'digestif',
    'vitamine',
    'solute',
    'materiel',
    'autre'
  ));
