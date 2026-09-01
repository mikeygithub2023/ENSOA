-- ============================================================================
-- SCOLARITÉ (ENSOA GSES) — repris de 046_appareils_notifications_push.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- Migration : les appareils à prévenir.
--
-- Une notification poussée s'adresse à un téléphone, pas à un compte :
-- Firebase Cloud Messaging remet le message à un « jeton » d'appareil, que
-- l'application obtient au lancement et qui change au fil des
-- réinstallations. On garde donc la correspondance jeton -> profil.
--
-- La table n'a aucune politique cliente : elle ne se manipule qu'à travers
-- les deux fonctions ci-dessous. C'est nécessaire pour un cas précis — le
-- téléphone qui change de main. Si l'élève B se connecte sur l'appareil de
-- l'élève A, le jeton est le même : sans réattribution, B recevrait les
-- devoirs de A. `enregistrer_appareil` efface donc toute attribution
-- antérieure du jeton, ce qu'une simple politique « chacun sa ligne »
-- interdirait (la ligne appartient encore à A).

create table socle.appareils (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references socle.profiles (id) on delete cascade,
  jeton text not null unique,
  plateforme text not null default 'android'
    check (plateforme in ('android', 'ios')),
  created_at timestamptz not null default now(),
  vu_le timestamptz not null default now()
);

create index appareils_profile_idx on socle.appareils (profile_id);

alter table socle.appareils enable row level security;

-- Rattache un jeton au profil appelant, en le retirant à qui le détenait.
-- Appelée à chaque ouverture de session et à chaque renouvellement du jeton
-- par Firebase.
create function scolarite.enregistrer_appareil(
  p_jeton text,
  p_plateforme text default 'android'
)
returns void
language plpgsql
security definer
set search_path = scolarite, socle, public
as $$
begin
  if auth.uid() is null then
    raise exception 'Non authentifié';
  end if;

  if p_jeton is null or length(trim(p_jeton)) = 0 then
    raise exception 'Jeton manquant';
  end if;

  insert into socle.appareils (profile_id, jeton, plateforme)
  values (auth.uid(), p_jeton, coalesce(p_plateforme, 'android'))
  on conflict (jeton) do update
    set profile_id = auth.uid(),
        plateforme = coalesce(p_plateforme, 'android'),
        vu_le = now();
end;
$$;

-- Détache le jeton, à la déconnexion. Volontairement sans condition sur le
-- propriétaire : celui qui tient l'appareil a le droit de faire taire ses
-- notifications, même si le jeton était encore attribué à un autre.
create function scolarite.oublier_appareil(p_jeton text)
returns void
language plpgsql
security definer
set search_path = scolarite, socle, public
as $$
begin
  delete from socle.appareils where jeton = p_jeton;
end;
$$;

revoke execute on function scolarite.enregistrer_appareil(text, text) from public;
revoke execute on function scolarite.oublier_appareil(text) from public;
grant execute on function scolarite.enregistrer_appareil(text, text)
  to authenticated;
grant execute on function scolarite.oublier_appareil(text) to authenticated;
