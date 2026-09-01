-- ============================================================================
-- LOGISTIQUE (ERP ENSOA) — repris de migration_024_changement_pin_obligatoire.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- ============================================================================
-- Le PIN choisi par celui qui ouvre le compte doit être remplacé à la
-- première connexion.
--
-- Le PIN initial n'est pas un secret : celui qui a ouvert le compte le
-- connaît, il l'a dicté ou noté quelque part pour le transmettre. Tant qu'il
-- n'a pas été changé, deux personnes peuvent entrer sous la même identité —
-- et le journal d'audit attribuerait à l'une ce que l'autre a fait.
--
-- `doit_changer_mot_de_passe` est posé à la création du compte et retiré au premier
-- changement. Tant qu'il est vrai, l'application ne donne accès à rien
-- d'autre qu'à l'écran de changement.
-- ============================================================================

alter table socle.profiles
  add column if not exists doit_changer_mot_de_passe boolean not null default false;

-- Marque le PIN comme changé, pour l'appelant et lui seul.
--
-- Une fonction plutôt qu'une politique d'écriture sur `profiles` : ouvrir la
-- table à la modification de soi-même permettrait aussi de se changer de
-- rôle ou de se réactiver, les politiques RLS ne sachant pas restreindre
-- colonne par colonne. Ici, une seule colonne bouge, et seulement sur sa
-- propre ligne.
create or replace function socle.marquer_pin_change()
returns void
language plpgsql
security definer
set search_path = logistique, socle, public
as $$
begin
  if auth.uid() is null then
    raise exception 'Non authentifié';
  end if;

  update socle.profiles
    set doit_changer_mot_de_passe = false
    where id = auth.uid();
end;
$$;

revoke execute on function socle.marquer_pin_change() from public;
grant execute on function socle.marquer_pin_change() to authenticated;
