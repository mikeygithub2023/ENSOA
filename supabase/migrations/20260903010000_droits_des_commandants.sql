-- ============================================================================
-- Ce que commande chacun des deux commandants d'une promotion.
--
-- Le Commandant de Promotion et le Commandant de Brigade ont le même
-- périmètre — les phases de la promotion inscrite à leur profil, et les
-- élèves qui y sont affectés — mais pas la même main dessus :
--
--   · le Commandant de Promotion note tout, comme le Commandant de Division
--     sur sa division ;
--   · le Commandant de Brigade ne note QUE le sport. Il tient le programme
--     de ses phases — cours, devoirs, exercices — et voit les autres notes,
--     mais ne les saisit ni ne les corrige.
--
-- Le périmètre étant commun, il reste écrit une seule fois :
-- `commande_la_phase` reconnaît désormais les deux postes. Toutes les
-- politiques qui s'appuient sur elle — et elles sont nombreuses, migration
-- 054 — valent donc pour l'un comme pour l'autre, sans rien réécrire. Seules
-- les notes distinguent les deux, et c'est le seul endroit où il faut le
-- dire.
-- ============================================================================

-- --- 1. Le périmètre, commun aux deux ---------------------------------------
create or replace function scolarite.commande_la_phase(p_classe_id uuid)
returns boolean
language sql
security definer
stable
set search_path = scolarite, socle, public
as $$
  select socle.current_role() in ('commandant_brigade', 'commandant_promotion')
    and exists (
      select 1 from scolarite.classes c
      where c.id = p_classe_id
        and c.promotion_id is not null
        and c.promotion_id = socle.current_promotion()
    );
$$;

-- Les deux politiques qui nommaient le poste au lieu d'appeler la fonction.
drop policy if exists promotions_select_commandant on scolarite.promotions;
create policy promotions_select_commandant on scolarite.promotions
  for select to authenticated
  using (
    socle.current_role() in ('commandant_brigade', 'commandant_promotion')
    and id = socle.current_promotion()
  );

drop policy if exists divisions_select_commandant on socle.divisions;
create policy divisions_select_commandant on socle.divisions
  for select to authenticated
  using (
    socle.current_role() in ('commandant_brigade', 'commandant_promotion')
    and exists (
      select 1 from scolarite.promotions p
      where p.id = socle.current_promotion()
        and p.division_id = divisions.id
    )
  );

-- --- 2. Les notes, seule différence entre les deux --------------------------
-- « Cette note relève-t-elle du module Sport ? » Le sport est un type de
-- contrôle depuis la migration 056 : c'est lui qui fait foi, pas le nom de
-- la matière, qu'on pourrait écrire de dix façons.
create or replace function scolarite.note_de_sport(p_note_id uuid, p_controle_id uuid)
returns boolean
language sql
security definer
stable
set search_path = scolarite, socle, public
as $$
  select exists (
    select 1 from scolarite.controles c
    where c.id = p_controle_id
      and c.type = 'sport'
  );
$$;

grant execute on function scolarite.note_de_sport(uuid, uuid) to authenticated;

-- Les anciennes politiques ne distinguaient pas les deux postes : elles
-- ouvraient toutes les notes de la promotion au Commandant de Brigade.
drop policy if exists notes_insert_commandant on scolarite.notes;
drop policy if exists notes_update_commandant on scolarite.notes;

-- La lecture reste commune : commander une promotion, c'est en connaître
-- les résultats, fût-ce sans les écrire.
drop policy if exists notes_select_commandant on scolarite.notes;
create policy notes_select_commandant on scolarite.notes
  for select to authenticated
  using (scolarite.commande_l_apprenant(apprenant_id));

-- Le Commandant de Promotion note tout ce qui relève de sa promotion.
drop policy if exists notes_write_commandant_promotion on scolarite.notes;
create policy notes_write_commandant_promotion on scolarite.notes
  for all to authenticated
  using (
    socle.current_role() = 'commandant_promotion'
    and scolarite.commande_l_apprenant(apprenant_id)
  )
  with check (
    socle.current_role() = 'commandant_promotion'
    and scolarite.commande_l_apprenant(apprenant_id)
  );

-- Le Commandant de Brigade ne note que le sport.
--
-- La note sportive naît d'ailleurs d'un déclencheur, à partir de la
-- performance qu'il saisit : cette politique couvre le cas où l'application
-- écrirait la note directement, et surtout elle dit ce qui est permis — le
-- reste des notes lui est fermé, y compris à la correction.
drop policy if exists notes_write_commandant_brigade on scolarite.notes;
create policy notes_write_commandant_brigade on scolarite.notes
  for all to authenticated
  using (
    socle.current_role() = 'commandant_brigade'
    and scolarite.commande_l_apprenant(apprenant_id)
    and scolarite.note_de_sport(notes.id, notes.controle_id)
  )
  with check (
    socle.current_role() = 'commandant_brigade'
    and scolarite.commande_l_apprenant(apprenant_id)
    and scolarite.note_de_sport(notes.id, notes.controle_id)
  );

-- ============================================================================
-- Contrôle : les politiques d'écriture des notes, poste par poste.
-- ============================================================================
select policyname, cmd
from pg_policies
where schemaname = 'scolarite' and tablename = 'notes'
order by policyname;
