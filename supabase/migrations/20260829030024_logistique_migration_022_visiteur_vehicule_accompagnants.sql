-- ============================================================================
-- LOGISTIQUE (ERP ENSOA) — repris de migration_022_visiteur_vehicule_accompagnants.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- ============================================================================
-- Le visiteur peut se présenter au portail avec un véhicule et accompagné.
--
-- Ces colonnes vont sur `passage_visiteur`, et non dans `passage_vehicule` :
-- cette dernière table suit les véhicules DE L'ÉCOLE, dont la sortie a été
-- autorisée par un mouvement créé au Garage. Le véhicule d'un visiteur est
-- un véhicule civil, qui n'appartient pas au parc, ne reçoit pas d'ordre de
-- mission et n'a pas de kilométrage à relever. Les mêler fausserait les
-- comptes du parc.
--
-- Les accompagnants ne font pas l'objet d'une fiche chacun : au poste de
-- garde, on note leur nombre et leurs noms sur la même ligne que le
-- visiteur principal, qui répond d'eux. Un compte séparé permet d'afficher
-- « Visiteur + 3 » dans la liste sans avoir à découper le texte.
-- ============================================================================

alter table logistique.passage_visiteur
  add column if not exists vehicule_immatriculation text;

alter table logistique.passage_visiteur
  add column if not exists vehicule_description text;

alter table logistique.passage_visiteur
  add column if not exists nombre_accompagnants integer not null default 0;

alter table logistique.passage_visiteur
  add column if not exists accompagnants text;

-- Un nombre d'accompagnants négatif n'a pas de sens ; la borne haute évite
-- qu'une faute de frappe transforme une visite en délégation de mille
-- personnes — au-delà, c'est une cérémonie, elle se prépare autrement.
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'passage_visiteur_nombre_accompagnants_check'
  ) then
    alter table logistique.passage_visiteur
      add constraint passage_visiteur_nombre_accompagnants_check
      check (nombre_accompagnants >= 0 and nombre_accompagnants <= 200);
  end if;
end $$;
