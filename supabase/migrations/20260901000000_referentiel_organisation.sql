-- ============================================================================
-- Le personnel, les services et les cellules passent en base.
--
-- Les trois tables existaient déjà — elles viennent du schéma d'origine du
-- soutien technique — mais l'application ne les lisait pas : elle servait une
-- liste écrite en dur dans le code (un service, quatre cellules, un militaire
-- fictif). Autrement dit, le bénéficiaire d'une distribution de carburant se
-- saisissait à la main à chaque fois, et `distribution.personnel_id` restait
-- vide.
--
-- Deux corrections ici, la saisie arrivant côté application :
-- ============================================================================

-- --- 1. Le grade devient du texte -------------------------------------------
-- Il était un entier, hérité d'un code HFSQL dont la table de correspondance
-- n'a jamais suivi. Personne ne saisit « 4 » pour dire « Sergent ». La table
-- est vide : la conversion ne perd rien.
alter table logistique.personnel
  alter column grade type text using grade::text;

comment on column logistique.personnel.grade is
  'Grade tel qu''on l''écrit — Sergent, Adjudant-chef… Texte libre, comme sur '
  'la fiche d''un apprenant : la nomenclature couvre officiers, sous-officiers '
  'et militaires du rang, et une liste fermée demanderait à être maintenue '
  'sans rien apporter.';

-- --- 2. Les cellules du Soutien Technique -----------------------------------
-- Reprises de la liste en dur : ce sont les vraies cellules du service, elles
-- n'avaient simplement jamais été écrites en base. Le personnel, lui, n'est
-- pas repris — la liste codée ne contenait qu'un militaire de démonstration.
--
-- Sans contrainte d'unicité sur le libellé, on se garde du doublon par un
-- `not exists` : la migration doit pouvoir se rejouer sans multiplier les
-- cellules.
insert into socle.service (libelle)
select 'Soutien Technique (ST)'
where not exists (
  select 1 from socle.service where libelle = 'Soutien Technique (ST)'
);

insert into socle.cellule (libelle, service_id)
select v.libelle, s.id
from (values
  ('Soutien pétrolier'),
  ('Garage'),
  ('Armurerie'),
  ('État-major ST')
) as v(libelle)
cross join (
  select id from socle.service where libelle = 'Soutien Technique (ST)' limit 1
) as s
where not exists (
  select 1 from socle.cellule c where c.libelle = v.libelle
);
