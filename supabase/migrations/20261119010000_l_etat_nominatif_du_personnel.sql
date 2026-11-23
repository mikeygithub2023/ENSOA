-- ============================================================================
-- L'état nominatif du personnel : ce que la DORH tient et que la fiche
-- ignorait.
--
-- La fiche signalétique de l'école (migration 003) a été écrite pour un
-- élève : filiation, contact d'urgence, taille, poids, groupe sanguin. Le
-- personnel de la Division de Commandement et Logistique, entré avec la
-- migration du 19 novembre, porte autre chose — un état nominatif, celui
-- que l'école transmet à la Direction des Ressources Humaines. On y lit la
-- catégorie, le numéro mécanographique, le début de service, la date de
-- nomination au grade, la date de retraite, la position statutaire, le
-- service d'affectation, l'emploi tenu, les diplômes militaire et civil, le
-- domaine de spécialité, les régies DORH et solde, le matricule solde.
--
-- Rien de tout cela n'avait de colonne : l'importer aurait voulu dire le
-- perdre. Les rubriques s'ajoutent donc ici, toutes facultatives, et toutes
-- ouvertes à n'importe quelle fiche — un stagiaire est un militaire comme
-- un autre, il a lui aussi un matricule solde. Elles ne restent vides que
-- parce que personne ne les a saisies.
--
-- Aucune contrainte de domaine sur `categorie`, `position_statutaire`,
-- `domaine` ou les régies : ces nomenclatures sont celles de la DORH, elles
-- changent sans nous prévenir, et une fiche refusée à l'enregistrement
-- parce qu'un code a changé d'intitulé coûte plus cher qu'une valeur
-- inattendue dans une colonne de texte.
-- ============================================================================

alter table scolarite.apprenants
  add column if not exists categorie text,
  add column if not exists code_grade integer,
  add column if not exists numero_mecano text,
  add column if not exists date_debut_service date,
  add column if not exists date_nomination date,
  add column if not exists date_retraite date,
  add column if not exists position_statutaire text,
  add column if not exists service_affectation text,
  add column if not exists emploi_tenu text,
  add column if not exists diplome_militaire text,
  add column if not exists diplome_militaire_obtenu_le date,
  add column if not exists diplome_civil text,
  add column if not exists domaine text,
  add column if not exists regie_dorh text,
  add column if not exists regie_solde text,
  add column if not exists matricule_solde text,
  add column if not exists observations text;

comment on column scolarite.apprenants.categorie is
  'Catégorie statutaire telle que la DORH l''écrit : OFF (officier), SOF '
  '(sous-officier), MDR (militaire du rang). Texte libre : la nomenclature '
  'n''est pas la nôtre.';

comment on column scolarite.apprenants.code_grade is
  'Code hiérarchique du grade dans l''état nominatif DORH (15 pour un '
  'lieutenant-colonel, 1 pour un soldat de deuxième classe). Repris tel '
  'quel, et non reconstruit depuis le grade : l''état nominatif fait foi. '
  'Il ne sert pas à ordonner une prise d''armes — plusieurs grades '
  'partagent un code dans les listes reçues.';

comment on column scolarite.apprenants.numero_mecano is
  'Numéro mécanographique. Unique dans toute l''armée, et c''est lui qui '
  'identifie un militaire quand le matricule manque.';

comment on column scolarite.apprenants.date_nomination is
  'Date de nomination au grade actuel — pas à l''emploi tenu.';

comment on column scolarite.apprenants.position_statutaire is
  'Où le militaire se trouve au regard du service : personnel au service, '
  'mis à disposition, stage intérieur ou extérieur, opérations '
  'extérieures, congé sanitaire. À ne pas confondre avec `statut`, qui dit '
  'si la fiche est active.';

comment on column scolarite.apprenants.service_affectation is
  'Service ou unité d''affectation (CCAS/ENSOA, ENSOA/CMA, SAF, DI...).';

comment on column scolarite.apprenants.matricule_solde is
  'Matricule tenu par la solde, qui n''est pas toujours le matricule '
  'militaire : les deux fichiers ont vécu séparément.';

-- Le numéro mécanographique identifie un militaire dans toute l'armée. Deux
-- fiches qui le partagent sont la même personne saisie deux fois — et c'est
-- l'erreur que fait un import rejoué. L'index la refuse, et rend l'import
-- de l'état nominatif rejouable sans dégât.
--
-- Index partiel : les élèves n'ont pas de numéro mécanographique, et
-- plusieurs milliers de NULL n'ont pas à se gêner les uns les autres.
create unique index if not exists apprenants_mecano_unique
  on scolarite.apprenants (numero_mecano)
  where numero_mecano is not null;
