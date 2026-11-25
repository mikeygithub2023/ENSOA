-- ============================================================================
-- Le dossier de pension, et les décorations.
--
-- Deux rubriques que l'école tient sur le papier et que la fiche ignorait.
--
-- LE DOSSIER DE PENSION est une liste de pièces à réunir avant le départ à
-- la retraite. Vérifier un dossier, c'est passer cette liste et dire, pièce
-- par pièce, si elle y est. La date de retraite est déjà en base
-- (`apprenants.date_retraite`, migration du 19 novembre) : l'écran peut donc
-- montrer d'abord ceux qui partent dans l'année, et c'est à cela que sert
-- une vérification — savoir ce qui manque avant qu'il soit tard.
--
-- LES DÉCORATIONS sont un registre : une ligne par décoration reçue, avec
-- la référence du texte qui l'attribue. Un militaire peut recevoir deux fois
-- la même (citations, échelons successifs), d'où l'absence de contrainte
-- d'unicité sur le seul couple militaire/décoration.
--
-- DEUX CATALOGUES, LIVRÉS VIDES. Les pièces exigées par la Direction des
-- Ressources Humaines et les décorations en usage à l'école ne sont pas de
-- notre ressort : les deviner, c'est risquer qu'un dossier soit déclaré
-- complet parce qu'il contient les pièces qu'on avait supposées. Les deux
-- listes se saisissent depuis l'écran, par l'administrateur, et rien n'est
-- préchargé ici — pas une ligne.
--
-- POURQUOI PAS DE `division_id` DÉNORMALISÉE, contrairement aux absences,
-- aux permissions et aux locaux disciplinaires. Sur ces registres-là, la
-- division est celle où le fait s'est produit : elle appartient à
-- l'écriture, et la figer est juste. Ici, il n'y a pas de fait daté mais un
-- état courant — ce dossier-ci est à jour, cet homme-là porte cette
-- médaille. Un militaire muté de la Division de Formation Initiale à la
-- Division de Commandement et Logistique emporterait sinon un dossier que
-- son nouveau chef ne verrait pas. La portée se lit donc sur la fiche, au
-- moment de la question, par `scolarite.releve_de_ma_division`.
-- ============================================================================

-- ============================================================================
-- 0. DE QUI RELÈVE CE MILITAIRE, MAINTENANT
-- ============================================================================
-- `security definer` : la fonction lit `apprenants` sans que la RLS de cette
-- table ne s'applique. Sans cela, un chef de division dont la politique de
-- lecture sur `apprenants` serait un jour restreinte verrait des dossiers
-- disparaître sans message — une politique qui se tait est pire qu'une
-- politique qui refuse.
create or replace function scolarite.releve_de_ma_division(p_apprenant_id uuid)
returns boolean
language sql
security definer
stable
set search_path = scolarite, socle, public
as $$
  select exists (
    select 1 from scolarite.apprenants a
    where a.id = p_apprenant_id
      and a.division_id = socle.current_division()
  );
$$;

grant execute on function scolarite.releve_de_ma_division(uuid)
  to authenticated;


-- ============================================================================
-- 1. LE CATALOGUE DES PIÈCES DU DOSSIER DE PENSION
-- ============================================================================
create table if not exists scolarite.pieces_pension (
  id uuid primary key default gen_random_uuid(),

  libelle text not null unique,

  -- L'ordre du dossier, pas l'ordre alphabétique : une liste de
  -- vérification se passe dans l'ordre où les pièces sont rangées.
  ordre integer not null default 0,

  -- Une pièce peut être exigée ou simplement attendue. Un dossier n'est
  -- complet que si toutes les pièces obligatoires y sont.
  obligatoire boolean not null default true,

  -- Une pièce qui n'est plus demandée se désactive ; on ne la supprime pas,
  -- sinon les vérifications déjà faites perdraient leur objet.
  active boolean not null default true,

  created_at timestamptz not null default now()
);

create index if not exists pieces_pension_ordre_idx
  on scolarite.pieces_pension (ordre, libelle);

comment on table scolarite.pieces_pension is
  'Catalogue des pièces du dossier de pension, tenu par l''administrateur. '
  'Livré vide : la liste est celle de la DORH, pas la nôtre.';


-- ============================================================================
-- 2. LE DOSSIER DE PENSION D'UN MILITAIRE
-- ============================================================================
-- Une ligne par pièce vérifiée. Les lignes naissent à la première
-- vérification : rien n'est prérempli, et un dossier jamais ouvert n'a
-- aucune ligne plutôt que des dizaines de lignes vides.
create table if not exists scolarite.dossiers_pension (
  id uuid primary key default gen_random_uuid(),

  apprenant_id uuid not null
    references scolarite.apprenants (id) on delete cascade,

  -- `restrict` : une pièce que des dossiers mentionnent ne se supprime pas
  -- du catalogue. On la désactive (voir `pieces_pension.active`), et
  -- l'histoire des vérifications reste lisible.
  piece_id uuid not null
    references scolarite.pieces_pension (id) on delete restrict,

  presente boolean not null default false,

  -- Quand, et par qui. La date est saisie plutôt que prise à l'horloge :
  -- une vérification se fait souvent au bureau avant d'être portée à
  -- l'écran.
  verifie_le date,
  verifie_par uuid references socle.profiles (id),

  observation text,

  created_at timestamptz not null default now(),

  -- Une pièce, une ligne. L'écran met à jour la ligne existante plutôt que
  -- d'en empiler une seconde qui dirait le contraire.
  constraint dossiers_pension_une_ligne_par_piece
    unique (apprenant_id, piece_id)
);

create index if not exists dossiers_pension_apprenant_idx
  on scolarite.dossiers_pension (apprenant_id);

comment on table scolarite.dossiers_pension is
  'Vérification du dossier de pension, pièce par pièce. Une ligne naît à '
  'la première vérification de cette pièce pour ce militaire.';


-- ============================================================================
-- 3. LE CATALOGUE DES DÉCORATIONS
-- ============================================================================
create table if not exists scolarite.decorations (
  id uuid primary key default gen_random_uuid(),

  libelle text not null unique,

  -- Les décorations se citent dans un ordre de préséance, qui n'est ni
  -- alphabétique ni chronologique.
  ordre integer not null default 0,

  active boolean not null default true,

  created_at timestamptz not null default now()
);

create index if not exists decorations_ordre_idx
  on scolarite.decorations (ordre, libelle);

comment on table scolarite.decorations is
  'Catalogue des décorations en usage à l''école, tenu par '
  'l''administrateur. Livré vide.';


-- ============================================================================
-- 4. LES DÉCORATIONS REÇUES
-- ============================================================================
create table if not exists scolarite.decorations_recues (
  id uuid primary key default gen_random_uuid(),

  apprenant_id uuid not null
    references scolarite.apprenants (id) on delete cascade,

  decoration_id uuid not null
    references scolarite.decorations (id) on delete restrict,

  -- Facultative : une médaille portée depuis des années sans que la date
  -- soit retrouvée vaut mieux qu'une ligne qu'on n'a pas pu saisir.
  date_attribution date,

  -- Le texte qui l'attribue : décret, arrêté, décision, ordre général.
  reference text,

  -- Échelon, agrafe, palme — ce qui distingue deux attributions de la même
  -- décoration.
  echelon text,

  observation text,

  created_at timestamptz not null default now(),
  cree_par uuid references socle.profiles (id),

  -- La même décoration peut être reçue deux fois, à deux dates. Deux fois
  -- à la même date, non : c'est une saisie en double.
  constraint decorations_recues_pas_deux_fois_le_meme_jour
    unique (apprenant_id, decoration_id, date_attribution)
);

create index if not exists decorations_recues_apprenant_idx
  on scolarite.decorations_recues (apprenant_id);

comment on table scolarite.decorations_recues is
  'Registre des décorations reçues. Une ligne par attribution — la même '
  'décoration peut revenir à deux dates différentes.';


-- ============================================================================
-- 5. QUI VOIT QUOI, QUI ÉCRIT QUOI
-- ============================================================================
alter table scolarite.pieces_pension enable row level security;
alter table scolarite.dossiers_pension enable row level security;
alter table scolarite.decorations enable row level security;
alter table scolarite.decorations_recues enable row level security;

-- --- Les deux catalogues ----------------------------------------------------
-- Lecture par toute l'école : sans la liste des pièces, l'écran de
-- vérification serait vide pour qui n'est pas administrateur. Un catalogue
-- ne révèle rien de personne.
--
-- Écriture par l'administrateur seul — c'est une nomenclature, pas une
-- écriture de service, et deux mains qui la tiennent la font diverger.

drop policy if exists pieces_pension_select on scolarite.pieces_pension;
create policy pieces_pension_select on scolarite.pieces_pension
  for select to authenticated
  using (socle.est_de_l_ecole());

drop policy if exists pieces_pension_ecriture on scolarite.pieces_pension;
create policy pieces_pension_ecriture on scolarite.pieces_pension
  for all to authenticated
  using (socle.current_role() = 'admin' or socle.est_administrateur())
  with check (socle.current_role() = 'admin' or socle.est_administrateur());

drop policy if exists decorations_select on scolarite.decorations;
create policy decorations_select on scolarite.decorations
  for select to authenticated
  using (socle.est_de_l_ecole());

drop policy if exists decorations_ecriture on scolarite.decorations;
create policy decorations_ecriture on scolarite.decorations
  for all to authenticated
  using (socle.current_role() = 'admin' or socle.est_administrateur())
  with check (socle.current_role() = 'admin' or socle.est_administrateur());


-- --- Le dossier de pension --------------------------------------------------
-- Lecture : l'administrateur partout ; le chef de division et l'instructeur
-- sur l'effectif de leur division ; le commandant de promotion ou de
-- brigade sur ses élèves ; l'intéressé sur son propre cas — il a le droit
-- de savoir ce qui manque à son dossier.
--
-- Le médecin n'y figure pas, contrairement aux absences et aux locaux
-- disciplinaires : ni la pension ni les décorations ne relèvent de lui.

drop policy if exists dossiers_pension_select_admin
  on scolarite.dossiers_pension;
create policy dossiers_pension_select_admin on scolarite.dossiers_pension
  for select to authenticated
  using (socle.current_role() = 'admin' or socle.est_administrateur());

drop policy if exists dossiers_pension_select_division
  on scolarite.dossiers_pension;
create policy dossiers_pension_select_division on scolarite.dossiers_pension
  for select to authenticated
  using (
    socle.current_role() in ('chef_division', 'instructeur')
    and scolarite.releve_de_ma_division(apprenant_id)
  );

drop policy if exists dossiers_pension_select_commandant
  on scolarite.dossiers_pension;
create policy dossiers_pension_select_commandant on scolarite.dossiers_pension
  for select to authenticated
  using (scolarite.commande_l_apprenant(apprenant_id));

drop policy if exists dossiers_pension_select_self on scolarite.dossiers_pension;
create policy dossiers_pension_select_self on scolarite.dossiers_pension
  for select to authenticated
  using (
    exists (
      select 1 from scolarite.apprenants a
      where a.id = dossiers_pension.apprenant_id
        and a.profile_id = auth.uid()
    )
  );

-- Écriture : l'administrateur, et le chef de division sur son effectif. Ni
-- l'instructeur ni le commandant de brigade — déclarer une pièce présente
-- engage l'école devant la DORH, et ce n'est pas un acte d'instruction.
drop policy if exists dossiers_pension_ecriture_admin
  on scolarite.dossiers_pension;
create policy dossiers_pension_ecriture_admin on scolarite.dossiers_pension
  for all to authenticated
  using (socle.current_role() = 'admin' or socle.est_administrateur())
  with check (socle.current_role() = 'admin' or socle.est_administrateur());

drop policy if exists dossiers_pension_ecriture_division
  on scolarite.dossiers_pension;
create policy dossiers_pension_ecriture_division on scolarite.dossiers_pension
  for all to authenticated
  using (
    socle.current_role() = 'chef_division'
    and scolarite.releve_de_ma_division(apprenant_id)
  )
  with check (
    socle.current_role() = 'chef_division'
    and scolarite.releve_de_ma_division(apprenant_id)
  );


-- --- Les décorations reçues -------------------------------------------------
drop policy if exists decorations_recues_select_admin
  on scolarite.decorations_recues;
create policy decorations_recues_select_admin on scolarite.decorations_recues
  for select to authenticated
  using (socle.current_role() = 'admin' or socle.est_administrateur());

drop policy if exists decorations_recues_select_division
  on scolarite.decorations_recues;
create policy decorations_recues_select_division
  on scolarite.decorations_recues
  for select to authenticated
  using (
    socle.current_role() in ('chef_division', 'instructeur')
    and scolarite.releve_de_ma_division(apprenant_id)
  );

drop policy if exists decorations_recues_select_commandant
  on scolarite.decorations_recues;
create policy decorations_recues_select_commandant
  on scolarite.decorations_recues
  for select to authenticated
  using (scolarite.commande_l_apprenant(apprenant_id));

drop policy if exists decorations_recues_select_self
  on scolarite.decorations_recues;
create policy decorations_recues_select_self on scolarite.decorations_recues
  for select to authenticated
  using (
    exists (
      select 1 from scolarite.apprenants a
      where a.id = decorations_recues.apprenant_id
        and a.profile_id = auth.uid()
    )
  );

drop policy if exists decorations_recues_ecriture_admin
  on scolarite.decorations_recues;
create policy decorations_recues_ecriture_admin on scolarite.decorations_recues
  for all to authenticated
  using (socle.current_role() = 'admin' or socle.est_administrateur())
  with check (socle.current_role() = 'admin' or socle.est_administrateur());

drop policy if exists decorations_recues_ecriture_division
  on scolarite.decorations_recues;
create policy decorations_recues_ecriture_division
  on scolarite.decorations_recues
  for all to authenticated
  using (
    socle.current_role() = 'chef_division'
    and scolarite.releve_de_ma_division(apprenant_id)
  )
  with check (
    socle.current_role() = 'chef_division'
    and scolarite.releve_de_ma_division(apprenant_id)
  );


-- ============================================================================
-- 6. JOURNAL ET DROITS
-- ============================================================================
drop trigger if exists audit_pieces_pension on scolarite.pieces_pension;
create trigger audit_pieces_pension
  after insert or update or delete on scolarite.pieces_pension
  for each row execute function socle.audit_trigger();

drop trigger if exists audit_dossiers_pension on scolarite.dossiers_pension;
create trigger audit_dossiers_pension
  after insert or update or delete on scolarite.dossiers_pension
  for each row execute function socle.audit_trigger();

drop trigger if exists audit_decorations on scolarite.decorations;
create trigger audit_decorations
  after insert or update or delete on scolarite.decorations
  for each row execute function socle.audit_trigger();

drop trigger if exists audit_decorations_recues on scolarite.decorations_recues;
create trigger audit_decorations_recues
  after insert or update or delete on scolarite.decorations_recues
  for each row execute function socle.audit_trigger();

grant select, insert, update, delete
  on scolarite.pieces_pension to authenticated;
grant select, insert, update, delete
  on scolarite.dossiers_pension to authenticated;
grant select, insert, update, delete
  on scolarite.decorations to authenticated;
grant select, insert, update, delete
  on scolarite.decorations_recues to authenticated;

-- Les nouvelles tables n'existent pour l'API qu'une fois le schéma relu.
notify pgrst, 'reload schema';


-- ============================================================================
-- Contrôle : quatre tables, la RLS active sur chacune, et les politiques
-- comptées — 2 sur chaque catalogue, 6 sur chaque registre. Les deux
-- catalogues doivent rendre 0 ligne : ils sont livrés vides.
-- ============================================================================
select
  c.relname as table_,
  c.relrowsecurity as rls_active,
  (select count(*) from pg_policies p
    where p.schemaname = 'scolarite' and p.tablename = c.relname) as politiques
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'scolarite'
  and c.relname in (
    'pieces_pension', 'dossiers_pension', 'decorations', 'decorations_recues')
order by c.relname;
