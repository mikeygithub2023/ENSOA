-- ============================================================================
-- SCOLARITÉ (ENSOA GSES) — repris de 004_photo_apprenant.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- Migration : stockage de la photo d'un apprenant (bucket Supabase Storage
-- privé) + colonne de référence sur `apprenants`. L'URL n'est jamais
-- stockée telle quelle (le bucket est privé) : on garde le chemin de
-- l'objet et on génère une URL signée à la demande côté client.

alter table scolarite.apprenants add column if not exists photo_path text;

insert into storage.buckets (id, name, public)
values ('apprenant-photos', 'apprenant-photos', false)
on conflict (id) do nothing;

create policy apprenant_photos_select on storage.objects
  for select to authenticated
  using (bucket_id = 'apprenant-photos');

create policy apprenant_photos_write on storage.objects
  for all to authenticated
  using (bucket_id = 'apprenant-photos')
  with check (bucket_id = 'apprenant-photos');
