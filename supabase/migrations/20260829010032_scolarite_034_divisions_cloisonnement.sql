-- ============================================================================
-- SCOLARITÉ (ENSOA GSES) — repris de 034_divisions_cloisonnement.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- Migration : cloisonne les divisions par rôle.
--
-- `divisions_select` était en `using (true)` : n'importe quel utilisateur
-- authentifié voyait toutes les divisions. Les apprenants, eux, étaient
-- bien filtrés (`apprenants_select_division_staff`), mais un chef de
-- division ou un instructeur voyait malgré tout les autres divisions dans
-- les filtres et les listes déroulantes — et pouvait les parcourir.
--
-- Seuls l'administrateur et le médecin ont une portée globale : le premier
-- par fonction, le second parce que le service médical couvre toute l'école
-- (voir la migration 022). Tous les autres — chef de division, instructeur,
-- élève/stagiaire — ne voient que leur propre division.
--
-- Le filtrage est ainsi garanti côté serveur, comme pour les apprenants :
-- l'application n'a pas à s'en porter garante.

drop policy if exists divisions_select on socle.divisions;

create policy divisions_select on socle.divisions
  for select to authenticated
  using (
    socle.current_role() in ('admin', 'medecin')
    or id = socle.current_division()
  );
