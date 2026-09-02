-- ============================================================================
-- Une activité annulée annule ses tâches.
--
-- Annuler une activité laissait ses tâches « à faire ». Les services les
-- voyaient donc encore sur leur liste, et le tableau de bord de l'Officier
-- Adjoint les comptait parmi celles qui restent à rendre — alors qu'il n'y a
-- plus rien à faire. Deux personnes trompées par la même ligne.
--
-- Les tâches suivent désormais le sort de leur activité. Toutes celles qui
-- ne sont pas déjà validées passent à « annulée » : celles qu'on n'a pas
-- commencées comme celles qu'on a rendues sans que l'Officier Adjoint ait eu
-- le temps de les viser — il n'a plus rien à viser.
--
-- Une validation, elle, ne se reprend pas : c'est un fait acquis, et le
-- journal d'audit en garde la trace.
--
-- Le mouvement inverse est prévu : rouvrir une activité annulée rend leurs
-- tâches à ceux qui les avaient. Sans quoi une annulation par erreur serait
-- irréparable autrement qu'à la main, ligne par ligne.
-- ============================================================================

alter table logistique.tache_activite drop constraint if exists tache_activite_statut_check;
alter table logistique.tache_activite
  add constraint tache_activite_statut_check
  check (statut in ('a_faire', 'terminee', 'validee', 'annulee'));

create or replace function logistique.taches_suivent_l_activite()
returns trigger
language plpgsql
security definer
set search_path = logistique, public
as $$
begin
  if new.statut = 'annulee' and old.statut is distinct from 'annulee' then
    update logistique.tache_activite
    set statut = 'annulee'
    where activite_id = new.id
      and statut <> 'validee';

  elsif old.statut = 'annulee' and new.statut is distinct from 'annulee' then
    -- On rend la tâche à son acteur telle qu'elle était avant l'annulation :
    -- à faire. Distinguer « elle était rendue » de « elle ne l'était pas »
    -- demanderait de garder l'état d'avant, pour un cas — l'annulation
    -- corrigée — qui ne se présentera presque jamais.
    update logistique.tache_activite
    set statut = 'a_faire'
    where activite_id = new.id
      and statut = 'annulee';
  end if;

  return new;
end $$;

drop trigger if exists taches_suivent_l_activite on logistique.activite;
create trigger taches_suivent_l_activite
after update on logistique.activite
for each row execute function logistique.taches_suivent_l_activite();

-- ============================================================================
-- Rattrapage : les activités déjà annulées gardent des tâches vivantes.
-- ============================================================================
update logistique.tache_activite t
set statut = 'annulee'
from logistique.activite a
where a.id = t.activite_id
  and a.statut = 'annulee'
  and t.statut <> 'validee';

-- Contrôle : plus aucune tâche vivante sous une activité annulée.
select count(*) as taches_orphelines
from logistique.tache_activite t
join logistique.activite a on a.id = t.activite_id
where a.statut = 'annulee' and t.statut not in ('validee', 'annulee');
