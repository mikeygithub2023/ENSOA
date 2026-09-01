-- ============================================================================
-- LOGISTIQUE (ERP ENSOA) — repris de migration_014_device_token.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- ============================================================================
-- Jetons FCM (Firebase Cloud Messaging) — un appareil par ligne, lié au
-- compte connecté dessus. La fonction serveur (Edge Function) s'en sert pour
-- savoir à quels appareils pousser une notification donnée.
-- ============================================================================

create table socle.device_token (
  id bigint generated always as identity primary key,
  utilisateur_id uuid references socle.profiles(id) on delete cascade not null,
  token text unique not null,
  plateforme text not null default 'android',
  cree_le timestamptz not null default now()
);

alter table socle.device_token enable row level security;

-- Chacun ne gère que les jetons de ses propres appareils.
create policy "device_token acces" on socle.device_token for all using (
  utilisateur_id = auth.uid()
);
