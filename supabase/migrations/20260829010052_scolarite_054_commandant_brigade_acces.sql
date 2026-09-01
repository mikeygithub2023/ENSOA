-- ============================================================================
-- SCOLARITÉ (ENSOA GSES) — repris de 054_commandant_brigade_acces.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- Migration : le rôle « Commandant de Brigade » — étape 2 sur 2.
--
-- Il commande une promotion : les phases qui la composent et les apprenants
-- qui y sont affectés. Il a sur eux ce que le chef de division a sur sa
-- division — et une chose de plus, qui est sa raison d'être : il saisit
-- lui-même les notes de ses élèves.
--
-- Ce qu'il n'a pas : la suppression d'une note. Comme le chef de division,
-- il en fait la demande, que l'administrateur tranche (migration 015). Un
-- correcteur qui pourrait supprimer puis ressaisir contournerait le suivi
-- des modifications.
--
-- ---------------------------------------------------------------------------
-- Les politiques RLS s'additionnent : celles qui suivent viennent en plus
-- des existantes, sans les toucher. Un chef de division garde exactement
-- les droits qu'il avait.

-- La promotion que commande l'utilisateur connecté.
alter table socle.profiles
  add column if not exists promotion_id uuid
    references scolarite.promotions (id) on delete set null;

create index if not exists profiles_promotion_idx on socle.profiles (promotion_id);

create or replace function socle.current_promotion()
returns uuid
language sql
security definer
stable
set search_path = scolarite, socle, public
as $$
  select promotion_id from socle.profiles where id = auth.uid();
$$;

-- « Cette phase relève-t-elle de la promotion que je commande ? »
--
-- Une fonction plutôt que la même sous-requête répétée dans dix politiques :
-- la règle est écrite une fois, et se corrige au même endroit.
create or replace function scolarite.commande_la_phase(p_classe_id uuid)
returns boolean
language sql
security definer
stable
set search_path = scolarite, socle, public
as $$
  select socle.current_role() = 'commandant_brigade'
    and exists (
      select 1 from scolarite.classes c
      where c.id = p_classe_id
        and c.promotion_id is not null
        and c.promotion_id = socle.current_promotion()
    );
$$;

-- Variante par apprenant : il relève de moi si sa phase relève de moi.
create or replace function scolarite.commande_l_apprenant(p_apprenant_id uuid)
returns boolean
language sql
security definer
stable
set search_path = scolarite, socle, public
as $$
  select exists (
    select 1 from scolarite.apprenants a
    where a.id = p_apprenant_id
      and scolarite.commande_la_phase(a.classe_id)
  );
$$;

grant execute on function socle.current_promotion() to authenticated;
grant execute on function scolarite.commande_la_phase(uuid) to authenticated;
grant execute on function scolarite.commande_l_apprenant(uuid) to authenticated;

-- --- Sa promotion, ses phases, ses apprenants -------------------------------
create policy promotions_select_commandant on scolarite.promotions
  for select to authenticated
  using (
    socle.current_role() = 'commandant_brigade'
    and id = socle.current_promotion()
  );

create policy classes_select_commandant on scolarite.classes
  for select to authenticated
  using (scolarite.commande_la_phase(id));

create policy apprenants_select_commandant on scolarite.apprenants
  for select to authenticated
  using (scolarite.commande_la_phase(classe_id));

create policy apprenants_update_commandant on scolarite.apprenants
  for update to authenticated
  using (scolarite.commande_la_phase(classe_id))
  with check (scolarite.commande_la_phase(classe_id));

-- Il voit la division dont relève sa promotion : sans quoi les écrans qui
-- affichent l'affectation d'un apprenant resteraient vides.
create policy divisions_select_commandant on socle.divisions
  for select to authenticated
  using (
    socle.current_role() = 'commandant_brigade'
    and exists (
      select 1 from scolarite.promotions p
      where p.id = socle.current_promotion()
        and p.division_id = divisions.id
    )
  );

-- --- Le programme de ses phases ---------------------------------------------
create policy matiere_modules_select_commandant on scolarite.matiere_modules
  for select to authenticated
  using (scolarite.commande_la_phase(classe_id));

create policy controles_select_commandant on scolarite.controles
  for select to authenticated
  using (scolarite.commande_la_phase(classe_id));

create policy controles_write_commandant on scolarite.controles
  for all to authenticated
  using (scolarite.commande_la_phase(classe_id))
  with check (scolarite.commande_la_phase(classe_id));

create policy sous_modules_commandant on scolarite.sous_modules
  for all to authenticated
  using (
    exists (
      select 1 from scolarite.controles c
      where c.id = sous_modules.module_id
        and scolarite.commande_la_phase(c.classe_id)
    )
  )
  with check (
    exists (
      select 1 from scolarite.controles c
      where c.id = sous_modules.module_id
        and scolarite.commande_la_phase(c.classe_id)
    )
  );

-- --- Les notes : ce qui le distingue du chef de division --------------------
create policy notes_select_commandant on scolarite.notes
  for select to authenticated
  using (scolarite.commande_l_apprenant(apprenant_id));

create policy notes_insert_commandant on scolarite.notes
  for insert to authenticated
  with check (scolarite.commande_l_apprenant(apprenant_id));

create policy notes_update_commandant on scolarite.notes
  for update to authenticated
  using (scolarite.commande_l_apprenant(apprenant_id))
  with check (scolarite.commande_l_apprenant(apprenant_id));

-- --- Le sport ---------------------------------------------------------------
create policy epreuves_sportives_commandant on scolarite.epreuves_sportives
  for all to authenticated
  using (
    exists (
      select 1 from scolarite.sous_modules sm
      join scolarite.controles c on c.id = sm.module_id
      where sm.id = epreuves_sportives.sous_module_id
        and scolarite.commande_la_phase(c.classe_id)
    )
  )
  with check (
    exists (
      select 1 from scolarite.sous_modules sm
      join scolarite.controles c on c.id = sm.module_id
      where sm.id = epreuves_sportives.sous_module_id
        and scolarite.commande_la_phase(c.classe_id)
    )
  );

create policy bareme_paliers_commandant on scolarite.bareme_paliers
  for all to authenticated
  using (
    exists (
      select 1 from scolarite.sous_modules sm
      join scolarite.controles c on c.id = sm.module_id
      where sm.id = bareme_paliers.sous_module_id
        and scolarite.commande_la_phase(c.classe_id)
    )
  )
  with check (
    exists (
      select 1 from scolarite.sous_modules sm
      join scolarite.controles c on c.id = sm.module_id
      where sm.id = bareme_paliers.sous_module_id
        and scolarite.commande_la_phase(c.classe_id)
    )
  );

create policy performances_sportives_commandant on scolarite.performances_sportives
  for all to authenticated
  using (scolarite.commande_l_apprenant(apprenant_id))
  with check (scolarite.commande_l_apprenant(apprenant_id));

-- --- Discipline et présence, comme le chef de division ----------------------
create policy permissions_select_commandant on scolarite.permissions
  for select to authenticated
  using (scolarite.commande_l_apprenant(apprenant_id));

create policy absences_select_commandant on scolarite.absences
  for select to authenticated
  using (scolarite.commande_l_apprenant(apprenant_id));

create policy cours_select_commandant on scolarite.cours
  for select to authenticated
  using (scolarite.commande_la_phase(classe_id));
