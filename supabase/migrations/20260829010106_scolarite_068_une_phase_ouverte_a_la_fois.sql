-- ============================================================================
-- SCOLARITÉ (ENSOA GSES) — repris de 068_une_phase_ouverte_a_la_fois.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- Migration : une promotion n'a qu'une phase ouverte à la fois.
--
-- La migration 066 créait toutes les phases d'avance et verrouillait les
-- suivantes. C'est une mécanique de plus à comprendre, pour le même
-- résultat qu'une règle simple : on ne crée la phase suivante qu'une fois
-- la précédente clôturée. Tant qu'une phase est ouverte, la promotion n'en
-- accepte pas d'autre — il n'y a donc plus rien à verrouiller, puisque ce
-- qui n'existe pas ne se saisit pas.
--
-- La migration des élèves se déplace en conséquence. Elle avait lieu à la
-- clôture, vers une phase suivante qui devait déjà exister ; elle a
-- désormais lieu à la CRÉATION de la phase suivante, qui vient après la
-- clôture. Les élèves actifs de la dernière phase close entrent dans la
-- nouvelle.

-- --- 1. Le rang se calcule tout seul ----------------------------------------
-- L'écran ne demande pas l'ordre d'une phase : il se déduit de celles qui
-- la précèdent, et une phase créée est toujours la dernière du cursus.

create or replace function scolarite.trg_classe_rang_et_unicite()
returns trigger
language plpgsql
security definer
set search_path = scolarite, socle, public
as $$
declare
  v_ouverte text;
begin
  if new.type <> 'phase' or new.promotion_id is null then
    return new;
  end if;

  -- Une seule phase ouverte par promotion : la suivante ne se crée qu'une
  -- fois celle-ci clôturée.
  select nom into v_ouverte
  from scolarite.classes
  where promotion_id = new.promotion_id
    and type = 'phase'
    and cloturee_le is null
    and id is distinct from new.id
  order by ordre desc
  limit 1;

  if v_ouverte is not null then
    raise exception
      'La phase « % » est encore ouverte : clôturez-la avant d''en créer '
      'une nouvelle dans cette promotion.', v_ouverte;
  end if;

  select coalesce(max(ordre), 0) + 1 into new.ordre
  from scolarite.classes
  where promotion_id = new.promotion_id and type = 'phase';

  return new;
end;
$$;

drop trigger if exists une_phase_ouverte on scolarite.classes;
create trigger une_phase_ouverte
  before insert on scolarite.classes
  for each row execute function scolarite.trg_classe_rang_et_unicite();

-- --- 2. Les élèves entrent dans la phase qui s'ouvre -------------------------

create or replace function scolarite.trg_migrer_vers_nouvelle_phase()
returns trigger
language plpgsql
security definer
set search_path = scolarite, socle, public
as $$
declare
  v_precedente uuid;
begin
  if new.type <> 'phase' or new.promotion_id is null then
    return new;
  end if;

  -- La dernière phase close de la promotion : c'est d'elle que viennent
  -- les élèves.
  select id into v_precedente
  from scolarite.classes
  where promotion_id = new.promotion_id
    and type = 'phase'
    and id <> new.id
    and cloturee_le is not null
  order by ordre desc
  limit 1;

  if v_precedente is null then
    return new;
  end if;

  -- Seuls les actifs montent : un radié ou un suspendu ne poursuit pas, un
  -- diplômé a fini.
  update scolarite.apprenants
  set classe_id = new.id
  where classe_id = v_precedente and statut = 'actif';

  return new;
end;
$$;

drop trigger if exists migrer_vers_nouvelle_phase on scolarite.classes;
create trigger migrer_vers_nouvelle_phase
  after insert on scolarite.classes
  for each row execute function scolarite.trg_migrer_vers_nouvelle_phase();

-- --- 3. Le verrou « phase suivante » n'a plus lieu d'être --------------------
-- Une phase qui existe est soit ouverte, soit close. Il ne peut plus y en
-- avoir en attente derrière une autre, et garder ce contrôle ferait
-- échouer la création d'une phase dont la précédente vient d'être close.

create or replace function scolarite.exiger_phase_ouverte(p_classe_id uuid)
returns void
language plpgsql
stable
security definer
set search_path = scolarite, socle, public
as $$
declare
  v_classe record;
begin
  select nom, cloturee_le, type into v_classe
  from scolarite.classes where id = p_classe_id;

  if v_classe.type is distinct from 'phase' then
    return;
  end if;

  if v_classe.cloturee_le is not null then
    raise exception
      'La phase « % » est clôturée : elle ne peut plus être modifiée.',
      v_classe.nom;
  end if;
end;
$$;

-- --- 4. CA 1 et CA 2 s'en vont ----------------------------------------------
-- Elles avaient été créées d'avance, ce que la règle n'admet plus. Elles ne
-- portaient qu'un module Sport créé d'office : ni élève, ni cours, ni note.

delete from scolarite.classes where nom in ('CA 1', 'CA 2') and type = 'phase';
