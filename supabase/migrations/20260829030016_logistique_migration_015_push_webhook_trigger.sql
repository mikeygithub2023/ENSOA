-- ============================================================================
-- LOGISTIQUE (ERP ENSOA) — repris de migration_015_push_webhook_trigger.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- ============================================================================
-- Remplace le "Database Webhook" du dashboard (impossible à créer sur ce
-- projet : le schéma interne supabase_functions n'a jamais été provisionné,
-- erreur 3F000) par un trigger Postgres direct, via pg_net, qui appelle
-- l'Edge Function push-notification à chaque insertion dans `notification`.
-- ============================================================================

create or replace function logistique.notifier_push_webhook()
returns trigger
language plpgsql
security definer
as $$
begin
  perform net.http_post(
    url := 'https://alsglftuvvefxaadfzsj.supabase.co/functions/v1/push-notification',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer sb_publishable_LCO8wMw7w7PFx56E1iH_LA_260paEgC'
    ),
    body := jsonb_build_object('record', to_jsonb(NEW))
  );
  return NEW;
end;
$$;

drop trigger if exists push_notification_on_insert on socle.notification;
create trigger push_notification_on_insert
after insert on socle.notification
for each row
execute function logistique.notifier_push_webhook();
