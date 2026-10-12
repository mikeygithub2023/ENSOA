-- ============================================================================
-- Supprimer un service sans effacer ce qu'il a fait.
--
-- Un service retiré (`actif = false`) reste dans la liste, grisé, et peut
-- être remis en service : c'est la pause. La suppression est autre chose —
-- le service n'existe plus, il disparaît de l'écran, et personne n'a plus à
-- le voir.
--
-- Mais les tâches qu'il a reçues, elles, restent. Les effacer trouerait
-- l'historique des activités : une prise d'armes dont trois tâches sur cinq
-- auraient disparu ne se relit plus. Et la clé étrangère de
-- `tache_activite` refuserait de toute façon la suppression de la ligne.
--
-- D'où une date de suppression plutôt qu'un `delete` : la ligne survit pour
-- que les tâches gardent le nom du service qui les a reçues, et elle cesse
-- de paraître partout ailleurs.
-- ============================================================================

alter table socle.profil_personnalise
  add column if not exists supprime_le timestamptz;

-- Le nom redevient disponible après une suppression : « Intendance » peut
-- renaître. L'index ne garde donc que les services vivants.
drop index if exists socle.profil_personnalise_libelle_actif_idx;
create unique index if not exists profil_personnalise_libelle_vivant_idx
  on socle.profil_personnalise (lower(libelle))
  where actif and supprime_le is null;

-- --- Un service supprimé ne doit laisser personne derrière lui -------------
-- Supprimer un service auquel des comptes sont encore rattachés laisserait
-- ces comptes membres d'un service invisible : ils ne verraient plus rien et
-- rien à l'écran ne dirait pourquoi. L'application le vérifie déjà ; la base
-- le garantit, car elle seule voit tout.
create or replace function socle.refuser_suppression_service_habite()
returns trigger
language plpgsql
security definer
set search_path = socle, public
as $$
declare n int;
begin
  if new.supprime_le is not null and old.supprime_le is null then
    select count(*) into n
    from socle.profiles
    where profil_personnalise_id = new.id and actif;

    if n > 0 then
      raise exception
        'Ce service compte encore % compte(s) actif(s) : réaffectez-les ou '
        'désactivez-les avant de le supprimer.', n
        using errcode = 'restrict_violation';
    end if;
  end if;
  return new;
end $$;

drop trigger if exists refuser_suppression_service_habite on socle.profil_personnalise;
create trigger refuser_suppression_service_habite
before update on socle.profil_personnalise
for each row execute function socle.refuser_suppression_service_habite();

-- ============================================================================
-- Contrôle : doit retourner 0 ligne.
-- Un service supprimé qui garderait des comptes actifs.
-- ============================================================================
select p.libelle, count(*) as comptes_actifs
from socle.profil_personnalise p
join socle.profiles c on c.profil_personnalise_id = p.id and c.actif
where p.supprime_le is not null
group by p.libelle;
