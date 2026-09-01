-- ============================================================================
-- SCOLARITÉ (ENSOA GSES) — repris de 057_audit_trigger_sans_colonne_id.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- Migration : le journal d'audit cesse d'exiger une colonne `id`.
--
-- `audit_trigger()` lisait `rec.id` sans précaution. Il prenait pourtant
-- soin d'entourer `rec.division_id` d'un gestionnaire d'exception, preuve
-- qu'on savait déjà que toutes les tables n'ont pas les mêmes colonnes —
-- mais `id` était tenu pour acquis.
--
-- Il ne l'est pas : `seances_sportives` a pour clé primaire le sous-module
-- qui la porte, pas un identifiant à elle. Toute écriture de séance
-- échouait donc sur « record "rec" has no field "id" », et le journal
-- faisait tomber l'opération qu'il était censé seulement observer.
--
-- Plutôt que d'empiler un second gestionnaire d'exception, on lit la ligne
-- une fois en JSON — ce qu'on faisait déjà pour `meta` — et on y pioche ce
-- qu'on y trouve. Une clé absente donne `null` au lieu de lever, et la
-- fonction cesse d'avoir un avis sur la forme des tables qu'elle observe.

create or replace function socle.audit_trigger()
returns trigger
language plpgsql
security definer
set search_path = scolarite, socle, public
as $$
declare
  rec record;
  donnees jsonb;
begin
  rec := coalesce(new, old);
  donnees := to_jsonb(rec);

  insert into socle.audit_log (
    actor_id,
    action,
    table_name,
    record_id,
    division_id,
    meta
  )
  values (
    auth.uid(),
    tg_op,
    tg_table_name,
    -- L'identifiant de la ligne, sous le nom qu'il porte dans cette table.
    -- `seances_sportives` est identifiée par son sous-module ; les autres
    -- tables ont un `id`.
    coalesce(donnees ->> 'id', donnees ->> 'sous_module_id'),
    (donnees ->> 'division_id')::uuid,
    donnees
  );

  return rec;
end;
$$;
