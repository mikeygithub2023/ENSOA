-- ============================================================================
-- LOGISTIQUE (ERP ENSOA) — repris de migration_013_referentiels_garage.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- ============================================================================
-- Le formulaire véhicule permet désormais au Garage de créer une nouvelle
-- marque/modèle/type directement depuis le dialogue (bouton "+"), mais
-- l'écriture sur ces référentiels n'était ouverte qu'au chef soutien
-- technique — le Garage aurait été bloqué par la RLS.
-- ============================================================================

drop policy if exists "ecriture marque" on logistique.marque_vhl;
create policy "ecriture marque" on logistique.marque_vhl for all using (
  socle.current_user_role() in ('garage', 'chef_soutien_technique')
);

drop policy if exists "ecriture modele" on logistique.modele_vhl;
create policy "ecriture modele" on logistique.modele_vhl for all using (
  socle.current_user_role() in ('garage', 'chef_soutien_technique')
);

drop policy if exists "ecriture type_vhl" on logistique.type_vhl;
create policy "ecriture type_vhl" on logistique.type_vhl for all using (
  socle.current_user_role() in ('garage', 'chef_soutien_technique')
);
