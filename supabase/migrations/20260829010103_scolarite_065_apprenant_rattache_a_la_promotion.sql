-- ============================================================================
-- SCOLARITÉ (ENSOA GSES) — repris de 065_apprenant_rattache_a_la_promotion.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- Migration : un élève s'inscrit dans une promotion, pas dans une phase.
--
-- La règle a changé : entrer dans une promotion, c'est être admis à toutes
-- ses phases. La phase cesse donc d'être ce qui rattache l'élève à
-- l'école — c'est la promotion. Sans cette colonne, le rattachement se
-- déduisait de `classe_id`, et un élève inscrit sous la première phase
-- n'existait pour aucune autre : on ne pouvait pas lui saisir de note en
-- deuxième phase, et la moyenne du bulletin, qui les couvre toutes, était
-- fausse.
--
-- `classe_id` ne disparaît pas pour autant, et ne devient pas décoratif :
-- il dit où l'élève se trouve en ce moment. C'est ce dont ont besoin les
-- permissions, absences, consultations et visites médicales, qui exigent
-- toutes une phase. Les deux colonnes disent donc deux choses différentes :
--
--   promotion_id — où il est inscrit, et donc ce qu'il compose ;
--   classe_id    — la phase qu'il suit aujourd'hui.
--
-- Un stagiaire n'a pas de promotion : son stage est son seul rattachement.

alter table scolarite.apprenants
  add column if not exists promotion_id uuid
    references scolarite.promotions (id) on delete cascade;

create index if not exists apprenants_promotion_idx
  on scolarite.apprenants (promotion_id);

-- Reprise de l'existant : chaque élève hérite de la promotion de la phase
-- sous laquelle il avait été enregistré.
update scolarite.apprenants a
set promotion_id = c.promotion_id
from scolarite.classes c
where c.id = a.classe_id
  and c.promotion_id is not null
  and a.promotion_id is null;

-- Un élève déplacé d'une phase à l'autre reste dans sa promotion ; changer
-- de phase ne doit pas non plus le sortir de celle où il est inscrit. On
-- tient donc la promotion à jour depuis la phase tant qu'elle en a une,
-- plutôt que de laisser les deux diverger en silence.
create or replace function scolarite.trg_apprenant_promotion()
returns trigger
language plpgsql
as $$
declare
  v_promotion uuid;
begin
  if new.classe_id is null then
    return new;
  end if;

  select promotion_id into v_promotion
  from scolarite.classes where id = new.classe_id;

  -- Une phase donne sa promotion ; un stage n'en a pas, et l'élève qui y
  -- passe n'en garde aucune.
  new.promotion_id := v_promotion;
  return new;
end;
$$;

drop trigger if exists apprenant_suit_sa_promotion on scolarite.apprenants;
create trigger apprenant_suit_sa_promotion
  before insert or update of classe_id on scolarite.apprenants
  for each row execute function scolarite.trg_apprenant_promotion();
