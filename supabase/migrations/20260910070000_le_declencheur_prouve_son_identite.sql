-- ============================================================================
-- Le déclencheur prouve son identité à la fonction de notification.
--
-- FAILLE CORRIGÉE ICI. `push-notification` n'avait aucun contrôle d'appelant :
-- ni en-tête lu, ni profil, ni rôle. Son seul laissez-passer était la clé
-- publishable — publique par destination, et présente dans chaque APK.
-- Quiconque la lisait poussait une notification de son choix sur TOUTES les
-- tablettes de l'école, au nom de l'établissement.
--
-- La fonction exige désormais un en-tête `x-webhook-secret`. Ce déclencheur
-- est son seul appelant légitime ; il le présente.
--
-- OÙ VIT LE SECRET. Dans une table que `authenticated` ne peut pas lire — RLS
-- activée, aucune politique, donc aucune ligne visible — et que seule cette
-- fonction `security definer` consulte. Le laisser en clair dans le corps de
-- la fonction l'exposerait à quiconque peut appeler `pg_get_functiondef`,
-- ce qui était précisément le défaut de la clé publishable qu'il remplace.
--
-- EN CAS DE ROTATION : changer la valeur ici ET dans les secrets du projet
-- (`supabase secrets set WEBHOOK_SECRET=...`). Les deux doivent concorder ;
-- sinon la fonction répond 403 et les notifications cessent en silence —
-- `net.http_post` est asynchrone et le déclencheur n'observe pas la réponse.
-- ============================================================================

create table if not exists socle.secrets (
  cle text primary key,
  valeur text not null,
  pose_le timestamptz not null default now()
);

alter table socle.secrets enable row level security;
-- Aucune politique, à dessein : personne ne lit cette table par l'API.
-- Les fonctions `security definer` la lisent, elles, sans la consulter.

revoke all on socle.secrets from authenticated;
revoke all on socle.secrets from anon;

insert into socle.secrets (cle, valeur)
values ('webhook_push', '708db398449ca7e5e7f243366ab9b66f55d0ac9196b5aa776d4ea08dc3c58037')
on conflict (cle) do update set valeur = excluded.valeur, pose_le = now();

create or replace function logistique.notifier_push_webhook()
returns trigger
language plpgsql
security definer
-- Le `search_path` manquait : c'était la seule fonction `security definer`
-- du dépôt sans lui, et l'écart que signale le contrôle Supabase
-- `0011_function_search_path_mutable`.
set search_path = logistique, socle, net, public
as $$
declare v_secret text;
begin
  select valeur into v_secret from socle.secrets where cle = 'webhook_push';

  perform net.http_post(
    url := 'https://alsglftuvvefxaadfzsj.supabase.co/functions/v1/push-notification',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-webhook-secret', v_secret
    ),
    body := jsonb_build_object(
      'record', jsonb_build_object(
        'titre', new.title,
        'destinataire_id', new.profile_id,
        'role_cible', new.role_cible,
        'message', new.message
      )
    )
  );
  return new;
end $$;

-- ============================================================================
-- Contrôle : doit retourner 0 ligne.
-- La clé publishable ne doit plus figurer dans aucune définition de fonction.
-- ============================================================================
select p.proname
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname in ('socle', 'scolarite', 'logistique')
  and p.prokind = 'f'
  and pg_get_functiondef(p.oid) like '%sb_publishable_%';
