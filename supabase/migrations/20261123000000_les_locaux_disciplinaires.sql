-- ============================================================================
-- Les locaux disciplinaires.
--
-- L'école relevait les absences et les permissions ; elle ne tenait nulle
-- part les punitions. Un élève aux arrêts était donc compté présent à la
-- prise d'armes du matin — il manquait aux rangs sans que rien ne le dise,
-- et le seul moyen de l'expliquer était de l'inscrire en absence, ce qui
-- confond une faute punie avec une absence constatée.
--
-- Une ligne est un séjour : qui, depuis quand, pour combien de jours, pour
-- quel motif, et sur décision de qui. La date de sortie prévue se calcule —
-- le premier jour compte, une punition de trois jours commencée lundi
-- s'achève mercredi — et la sortie réelle se marque au retour, qu'elle
-- tombe plus tôt (punition levée) ou plus tard.
--
-- Même structure que `absences` (migration 008), à une différence près :
-- `classe_id` y est facultatif. Le personnel de la Division de Commandement
-- et Logistique ne suit aucune phase, et un sous-officier de l'école va aux
-- arrêts comme un élève.
-- ============================================================================

create table if not exists scolarite.locaux_disciplinaires (
  id uuid primary key default gen_random_uuid(),
  apprenant_id uuid not null
    references scolarite.apprenants (id) on delete cascade,
  division_id uuid not null references socle.divisions (id),

  -- Facultatif : le personnel de l'école n'a pas de phase. Dénormalisé
  -- comme ailleurs, pour que la RLS borne sans jointure.
  classe_id uuid references scolarite.classes (id),

  date_debut date not null,

  -- Les jours infligés. Le premier compte : trois jours à partir du lundi
  -- s'achèvent le mercredi.
  jours integer not null check (jours > 0),

  motif text not null,

  -- L'autorité qui a puni. Facultative : elle se lit sur le bulletin de
  -- punition, et toutes les écritures n'en viennent pas.
  autorite text,

  -- La sortie réelle, nulle tant que l'intéressé n'est pas ressorti.
  -- Antérieure à la sortie prévue quand la punition est levée.
  date_sortie date,

  created_at timestamptz not null default now(),

  constraint locaux_disciplinaires_sortie_apres_entree
    check (date_sortie is null or date_sortie >= date_debut)
);

-- La sortie prévue n'est pas une saisie mais une conséquence : la calculer
-- dans la base, c'est garantir qu'une correction du nombre de jours la
-- corrige aussi, et qu'aucune requête n'ait à refaire l'opération.
alter table scolarite.locaux_disciplinaires
  add column if not exists date_fin_prevue date
  generated always as (date_debut + (jours - 1)) stored;

create index if not exists locaux_disciplinaires_apprenant_idx
  on scolarite.locaux_disciplinaires (apprenant_id);
create index if not exists locaux_disciplinaires_classe_idx
  on scolarite.locaux_disciplinaires (classe_id);
create index if not exists locaux_disciplinaires_division_idx
  on scolarite.locaux_disciplinaires (division_id);

alter table scolarite.locaux_disciplinaires enable row level security;

-- --- Lecture ---------------------------------------------------------------
-- Les mêmes yeux que sur une absence : l'administrateur et le médecin
-- partout, le personnel d'une division chez elle, le commandant sur ses
-- élèves, et l'intéressé sur son propre cas.
drop policy if exists locaux_disciplinaires_select_global
  on scolarite.locaux_disciplinaires;
create policy locaux_disciplinaires_select_global
  on scolarite.locaux_disciplinaires
  for select to authenticated
  using (socle.current_role() in ('admin', 'medecin'));

drop policy if exists locaux_disciplinaires_select_division
  on scolarite.locaux_disciplinaires;
create policy locaux_disciplinaires_select_division
  on scolarite.locaux_disciplinaires
  for select to authenticated
  using (
    socle.current_role() in ('chef_division', 'instructeur')
    and division_id = socle.current_division()
  );

drop policy if exists locaux_disciplinaires_select_commandant
  on scolarite.locaux_disciplinaires;
create policy locaux_disciplinaires_select_commandant
  on scolarite.locaux_disciplinaires
  for select to authenticated
  using (scolarite.commande_l_apprenant(apprenant_id));

drop policy if exists locaux_disciplinaires_select_self
  on scolarite.locaux_disciplinaires;
create policy locaux_disciplinaires_select_self
  on scolarite.locaux_disciplinaires
  for select to authenticated
  using (
    exists (
      select 1 from scolarite.apprenants a
      where a.id = locaux_disciplinaires.apprenant_id
        and a.profile_id = auth.uid()
    )
  );

-- --- Écriture --------------------------------------------------------------
-- Punir est un acte de commandement : l'administrateur, le chef de division
-- chez lui, le commandant de promotion ou de brigade sur ses élèves. Un
-- instructeur ne met personne aux arrêts, et le médecin non plus.
drop policy if exists locaux_disciplinaires_write_admin
  on scolarite.locaux_disciplinaires;
create policy locaux_disciplinaires_write_admin
  on scolarite.locaux_disciplinaires
  for all to authenticated
  using (socle.current_role() = 'admin')
  with check (socle.current_role() = 'admin');

drop policy if exists locaux_disciplinaires_write_chef_division
  on scolarite.locaux_disciplinaires;
create policy locaux_disciplinaires_write_chef_division
  on scolarite.locaux_disciplinaires
  for all to authenticated
  using (
    socle.current_role() = 'chef_division'
    and division_id = socle.current_division()
  )
  with check (
    socle.current_role() = 'chef_division'
    and division_id = socle.current_division()
  );

drop policy if exists locaux_disciplinaires_write_commandant
  on scolarite.locaux_disciplinaires;
create policy locaux_disciplinaires_write_commandant
  on scolarite.locaux_disciplinaires
  for all to authenticated
  using (scolarite.commande_l_apprenant(apprenant_id))
  with check (scolarite.commande_l_apprenant(apprenant_id));

drop trigger if exists audit_locaux_disciplinaires
  on scolarite.locaux_disciplinaires;
create trigger audit_locaux_disciplinaires
  after insert or update or delete on scolarite.locaux_disciplinaires
  for each row execute function socle.audit_trigger();

grant select, insert, update, delete
  on scolarite.locaux_disciplinaires to authenticated;

-- La nouvelle table n'existe pour l'API qu'une fois le schéma relu.
notify pgrst, 'reload schema';

-- ============================================================================
-- Contrôle : doit rendre sept politiques, et la table doit porter la RLS.
-- ============================================================================
select
  (select count(*) from pg_policies
    where schemaname = 'scolarite'
      and tablename = 'locaux_disciplinaires') as politiques,
  (select relrowsecurity from pg_class
    where oid = 'scolarite.locaux_disciplinaires'::regclass) as rls_active;
