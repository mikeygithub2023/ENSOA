-- ============================================================================
-- LOGISTIQUE (ERP ENSOA) — repris de migration_007_notifications.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- ============================================================================
-- Table NOTIFICATION — jusqu'ici les notifications étaient une liste figée
-- identique pour tout le monde (mock côté app). On la fait persister et on
-- permet de cibler un destinataire précis (destinataire_id) ou un rôle
-- entier (role_cible) ; une notification sans aucun des deux est globale.
-- ============================================================================

create table socle.notification (
  id bigint generated always as identity primary key,
  date timestamptz not null default now(),
  categorie text not null,
  titre text not null,
  message text not null,
  lue boolean not null default false,
  destinataire_id uuid references socle.profiles(id) on delete cascade,
  role_cible socle.user_role
);

alter table socle.notification enable row level security;

-- Lecture : notifications globales, ciblant mon rôle, ou m'étant destinées.
create policy "notification select" on socle.notification for select using (
  auth.role() = 'authenticated'
  and (
    (destinataire_id is null and role_cible is null)
    or destinataire_id = auth.uid()
    or role_cible = socle.current_user_role()
  )
);

-- Écriture : tout utilisateur connecté peut créer une notification.
create policy "notification insert" on socle.notification for insert with check (auth.role() = 'authenticated');

-- Marquer comme lue : uniquement les notifications qui me sont destinées
-- (personnelles ou globales) — pas celles ciblant un autre utilisateur précis.
create policy "notification update" on socle.notification for update using (
  destinataire_id = auth.uid() or destinataire_id is null
);
