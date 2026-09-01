-- ============================================================================
-- SCOLARITÉ (ENSOA GSES) — repris de 006_nom_admin.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- Mise à jour ponctuelle : nom/prénom du compte admin.
update socle.profiles
set prenom = 'Lieutenant-Colonel', nom = 'DJAMA'
where id = (select id from auth.users where email = 'admin@ensoa.local');
