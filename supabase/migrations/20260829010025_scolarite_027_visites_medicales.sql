-- ============================================================================
-- SCOLARITÉ (ENSOA GSES) — repris de 027_visites_medicales.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- Migration : visites médicales de l'ENSOA — écran "Visites médicales" du
-- médecin.
--
-- Une visite médicale est une campagne : un titre, la classe/stage
-- convoquée, une date et un type (incorporation, périodique, aptitude
-- sport, reprise, contre-visite). Elle n'est ni demandée ni autorisée par
-- le commandement, contrairement à une consultation : c'est le médecin qui
-- la planifie, la réalise et la saisit — les deux tables sont donc
-- réservées au seul rôle `medecin`.
--
-- Les apprenants qui l'ont passée sont dans `visites_medicales_apprenants`,
-- une ligne par apprenant : c'est là que vit l'examen proprement dit, qui
-- reprend champ pour champ le cachet apposé sur le dossier médical :
--
--   Taille / Poids / PTM / PIGNET / T.A / Pouls
--   VOD / VOG / AOD / AOG / URINE : S(ucre) et A(lbumine)
--   CLINIQUE                                        SIGYCOP
--
-- Deux partis pris sur ce cachet :
--   * l'indice de PIGNET n'est pas saisi — il se déduit des mensurations
--     (taille - (poids + périmètre thoracique moyen)) et est donc calculé
--     par la base, ce qui évite toute incohérence avec les trois valeurs
--     saisies ;
--   * le profil SIGYCOP est éclaté en sept colonnes (une par lettre) plutôt
--     que stocké en une chaîne, pour rester interrogeable (ex. tous les
--     apprenants dont le Y dépasse 3).
--
-- `division_id` est dénormalisé depuis la classe/stage (comme sur
-- `consultations_medicales`) pour filtrer par division sans jointure.

-- Reprise d'une première version des visites médicales passée à la main sur
-- la base, qui stockait une visite par apprenant (une ligne = un examen) :
-- la structure ci-dessous sépare la campagne de ses examens et n'est donc
-- pas atteignable par un simple `alter table`, on repart de zéro. `cascade`
-- emporte index, policies, triggers et clés étrangères. La policy
-- `classes_select_medecin` vit sur `classes` et survivrait au drop : elle
-- ferait échouer la recréation en « policy already exists ».
-- ⚠ Les visites déjà saisies sont perdues (reprise validée en connaissance
-- de cause).
drop table if exists scolarite.visites_medicales_apprenants cascade;
drop table if exists scolarite.visites_medicales cascade;
drop policy if exists classes_select_medecin on scolarite.classes;

create table scolarite.visites_medicales (
  id uuid primary key default gen_random_uuid(),
  titre text not null,
  division_id uuid not null references socle.divisions (id),
  classe_id uuid not null references scolarite.classes (id),
  date_visite date not null,
  type text not null check (type in ('incorporation', 'periodique', 'aptitude_sport', 'reprise', 'contre_visite')),
  created_at timestamptz not null default now()
);

create index visites_medicales_division_idx on scolarite.visites_medicales (division_id);
create index visites_medicales_classe_idx on scolarite.visites_medicales (classe_id);
create index visites_medicales_date_idx on scolarite.visites_medicales (date_visite desc);

-- Un apprenant passé à une visite : son examen et sa conclusion
-- d'aptitude. Un même apprenant ne figure qu'une fois par visite.
create table scolarite.visites_medicales_apprenants (
  id uuid primary key default gen_random_uuid(),
  visite_id uuid not null references scolarite.visites_medicales (id) on delete cascade,
  apprenant_id uuid not null references scolarite.apprenants (id) on delete cascade,
  resultat text not null check (resultat in ('apte', 'inapte_temporaire', 'inapte_definitif', 'a_revoir')),
  observations text,

  -- Mensurations : taille et périmètre thoracique moyen (PTM) en
  -- centimètres, poids en kilogrammes.
  taille_cm numeric(5, 1) check (taille_cm is null or taille_cm > 0),
  poids_kg numeric(5, 1) check (poids_kg is null or poids_kg > 0),
  ptm_cm numeric(5, 1) check (ptm_cm is null or ptm_cm > 0),
  pignet numeric(6, 1) generated always as (taille_cm - (poids_kg + ptm_cm)) stored,

  -- Constantes : tension artérielle telle qu'elle est notée sur le cachet
  -- (ex. « 12/8 ») et pouls en battements par minute.
  tension_arterielle text,
  pouls integer check (pouls is null or pouls > 0),

  -- Acuité visuelle (VOD/VOG) et auditive (AOD/AOG), œil/oreille droit puis
  -- gauche — texte libre, ces valeurs se notant sous des formes variées
  -- (« 10/10 », « P2 », « normale »...).
  vod text,
  vog text,
  aod text,
  aog text,

  -- Analyse d'urine : sucre et albumine.
  urine_sucre text,
  urine_albumine text,

  -- Examen clinique, en texte libre.
  clinique text,

  -- Profil médical SIGYCOP : S(ceinture scapulaire), I(membres inférieurs),
  -- G(état général), Y(yeux), C(sens chromatique), O(oreilles),
  -- P(psychisme).
  sigycop_s smallint check (sigycop_s is null or sigycop_s between 0 and 6),
  sigycop_i smallint check (sigycop_i is null or sigycop_i between 0 and 6),
  sigycop_g smallint check (sigycop_g is null or sigycop_g between 0 and 6),
  sigycop_y smallint check (sigycop_y is null or sigycop_y between 0 and 6),
  sigycop_c smallint check (sigycop_c is null or sigycop_c between 0 and 6),
  sigycop_o smallint check (sigycop_o is null or sigycop_o between 0 and 6),
  sigycop_p smallint check (sigycop_p is null or sigycop_p between 0 and 6),

  created_at timestamptz not null default now(),
  unique (visite_id, apprenant_id)
);

create index visites_medicales_apprenants_visite_idx on scolarite.visites_medicales_apprenants (visite_id);
create index visites_medicales_apprenants_apprenant_idx on scolarite.visites_medicales_apprenants (apprenant_id);

alter table scolarite.visites_medicales enable row level security;
alter table scolarite.visites_medicales_apprenants enable row level security;

-- Lecture et écriture réservées au médecin.
create policy visites_medicales_all_medecin on scolarite.visites_medicales
  for all to authenticated
  using (socle.current_role() = 'medecin')
  with check (socle.current_role() = 'medecin');

create policy visites_medicales_apprenants_all_medecin on scolarite.visites_medicales_apprenants
  for all to authenticated
  using (socle.current_role() = 'medecin')
  with check (socle.current_role() = 'medecin');

-- La visite étant rattachée à une classe/stage, le médecin doit pouvoir
-- lire le référentiel `classes` — jusqu'ici réservé à l'admin, au personnel
-- de la division et à l'apprenant pour la sienne. Lecture seule et sur
-- toute l'école, comme sa vue globale sur `apprenants`.
create policy classes_select_medecin on scolarite.classes
  for select to authenticated
  using (socle.current_role() = 'medecin');

create trigger audit_visites_medicales
  after insert or update or delete on scolarite.visites_medicales
  for each row execute function socle.audit_trigger();

create trigger audit_visites_medicales_apprenants
  after insert or update or delete on scolarite.visites_medicales_apprenants
  for each row execute function socle.audit_trigger();

grant select, insert, update, delete on scolarite.visites_medicales to authenticated;
grant select, insert, update, delete on scolarite.visites_medicales_apprenants to authenticated;
