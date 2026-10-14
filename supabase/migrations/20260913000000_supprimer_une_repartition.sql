-- ============================================================================
-- Supprimer une répartition sans effacer ce qu'elle a reçu.
--
-- Le `delete` échoue, et il a raison. Une répartition est retenue par deux
-- clés étrangères successives :
--
--     repartition  <-  soute_type_stock  <-  depotage
--                                        <-  distribution
--                                        <-  depotage_interne
--
-- Une répartition qui a servi une seule fois garde donc sa ligne de stock, et
-- cette ligne garde le mouvement qui l'a traversée. « BA2 » est à zéro litre
-- mais porte deux distributions : l'effacer trouerait le journal du
-- carburant — deux remises dont on ne saurait plus à qui elles étaient
-- destinées. Un registre de carburant qui perd des lignes ne vaut plus rien.
--
-- D'où une date de suppression plutôt qu'un `delete`, comme pour les
-- services : la ligne survit pour que les mouvements gardent le nom de leur
-- bénéficiaire, et elle cesse de paraître partout ailleurs — plus de
-- dépotage interne vers elle, plus de distribution depuis elle, plus de
-- ligne sur la carte de la soute.
-- ============================================================================

alter table logistique.repartition
  add column if not exists supprime_le timestamptz;

-- --- Le nom redevient disponible -------------------------------------------
-- « BA2 » supprimée doit pouvoir renaître : une unité dissoute puis recréée
-- reprend son appellation. L'unicité ne vaut donc que pour les vivantes. On
-- la rend aussi insensible à la casse, pour qu'on ne tienne pas « ba2 » et
-- « BA2 » pour deux répartitions.
do $$
declare c text;
begin
  select conname into c
  from pg_constraint
  where conrelid = 'logistique.repartition'::regclass
    and contype = 'u'
    and pg_get_constraintdef(oid) ilike '%(libelle)%';

  if c is not null then
    execute format('alter table logistique.repartition drop constraint %I', c);
  end if;
end $$;

create unique index if not exists repartition_libelle_vivant_idx
  on logistique.repartition (lower(libelle))
  where supprime_le is null;

-- --- Ce qu'on ne supprime pas ----------------------------------------------
-- Deux refus, et la base doit les porter elle-même : l'application est un
-- binaire que son porteur contrôle, et l'API s'appelle sans elle.
--
--   1. « Activités Ordinaires » est la porte d'entrée du carburant. La
--      supprimer rendrait toute soute inapte à recevoir un dépotage, et rien
--      à l'écran ne dirait pourquoi.
--   2. Une répartition qui porte encore des litres. Le carburant resterait
--      dans la soute sans destinataire : il compterait dans le total de
--      l'école sans appartenir à personne.
create or replace function logistique.refuser_suppression_repartition()
returns trigger
language plpgsql
security definer
set search_path = logistique, public
as $$
declare v_litres integer;
begin
  if new.supprime_le is null or old.supprime_le is not null then
    return new;
  end if;

  if old.libelle = 'Activités Ordinaires' then
    raise exception
      'La répartition d''accueil « Activités Ordinaires » ne se supprime '
      'pas : c''est par elle que le carburant entre dans les soutes.'
      using errcode = 'restrict_violation';
  end if;

  select coalesce(sum(qte_gasoil + qte_super), 0) into v_litres
  from logistique.soute_type_stock
  where repartition_id = new.id;

  if v_litres > 0 then
    raise exception
      '« % » porte encore % L. Ventilez-les ou distribuez-les avant de la '
      'supprimer.', old.libelle, v_litres
      using errcode = 'restrict_violation';
  end if;

  return new;
end $$;

drop trigger if exists refuser_suppression_repartition on logistique.repartition;
create trigger refuser_suppression_repartition
before update on logistique.repartition
for each row execute function logistique.refuser_suppression_repartition();

-- --- La répartition d'accueil se cherche parmi les vivantes -----------------
-- Le déclencheur qui ouvre une soute lisait « la » ligne portant ce nom.
-- Maintenant qu'un nom supprimé peut coexister avec son homonyme vivant, il
-- doit dire laquelle. « Activités Ordinaires » ne peut pas être supprimée
-- (ci-dessus), mais une fonction qui dépend d'une règle écrite ailleurs est
-- une fonction fragile.
create or replace function logistique.ouvrir_les_activites_ordinaires()
returns trigger
language plpgsql
security definer
set search_path = logistique, public
as $$
declare v_repartition bigint;
begin
  select id into v_repartition
  from logistique.repartition
  where libelle = 'Activités Ordinaires' and supprime_le is null;

  -- `type_stock_id` reste nul : une ligne de stock porte à la fois le gasoil
  -- et le super, dans deux colonnes.
  insert into logistique.soute_type_stock
    (soute_id, repartition_id, type_stock_id,
     qte_gasoil, qte_super, seuil_nominal, seuil_critique)
  values (new.id, v_repartition, null, 0, 0, 0, 0);

  return new;
end $$;

-- --- La ventilation ne sert pas une répartition supprimée ------------------
-- Même raison que ci-dessus : le contrôle appartient à la base. Le reste de
-- la fonction est inchangé.
create or replace function logistique.depoter_en_interne(
  p_soute_id bigint,
  p_repartition_cible bigint,
  p_type_carburant text,
  p_quantite integer,
  p_motif text default null
)
returns bigint
language plpgsql
security definer
set search_path = logistique, socle, public
as $$
declare
  v_source bigint;
  v_destination bigint;
  v_disponible integer;
  v_id bigint;
begin
  if not (
    socle.est_administrateur()
    or socle.current_user_role() in ('soutien_petrolier', 'chef_soutien_technique')
  ) then
    raise exception 'Seul le soutien pétrolier ventile le carburant.'
      using errcode = 'insufficient_privilege';
  end if;

  if p_quantite is null or p_quantite <= 0 then
    raise exception 'La quantité à transférer doit être positive.';
  end if;
  if p_type_carburant not in ('Gasoil', 'Super') then
    raise exception 'Type de carburant inconnu : %.', p_type_carburant;
  end if;

  -- Une répartition supprimée n'a plus de bénéficiaire : le carburant qu'on
  -- y verserait serait immobilisé, et invisible.
  if not exists (
    select 1 from logistique.repartition
    where id = p_repartition_cible and supprime_le is null
  ) then
    raise exception 'Cette répartition a été supprimée.'
      using errcode = 'restrict_violation';
  end if;

  select sts.id into v_source
  from logistique.soute_type_stock sts
  join logistique.repartition r on r.id = sts.repartition_id
  where sts.soute_id = p_soute_id
    and r.libelle = 'Activités Ordinaires'
    and r.supprime_le is null;

  if v_source is null then
    raise exception
      'Cette soute n''a pas de répartition « Activités Ordinaires ».';
  end if;

  select id into v_destination
  from logistique.soute_type_stock
  where soute_id = p_soute_id and repartition_id = p_repartition_cible;

  if v_destination is null then
    insert into logistique.soute_type_stock
      (soute_id, repartition_id, type_stock_id,
       qte_gasoil, qte_super, seuil_nominal, seuil_critique)
    values (p_soute_id, p_repartition_cible, null, 0, 0, 0, 0)
    returning id into v_destination;
  end if;

  if v_destination = v_source then
    raise exception
      'La destination est la répartition d''accueil : il n''y a rien à transférer.';
  end if;

  select case when p_type_carburant = 'Gasoil' then qte_gasoil else qte_super end
    into v_disponible
  from logistique.soute_type_stock
  where id = v_source
  for update;

  if v_disponible < p_quantite then
    raise exception
      'Activités Ordinaires ne contient que % L de %, et l''on en demande %.',
      v_disponible, p_type_carburant, p_quantite
      using errcode = 'check_violation';
  end if;

  if p_type_carburant = 'Gasoil' then
    update logistique.soute_type_stock
       set qte_gasoil = qte_gasoil - p_quantite where id = v_source;
    update logistique.soute_type_stock
       set qte_gasoil = qte_gasoil + p_quantite where id = v_destination;
  else
    update logistique.soute_type_stock
       set qte_super = qte_super - p_quantite where id = v_source;
    update logistique.soute_type_stock
       set qte_super = qte_super + p_quantite where id = v_destination;
  end if;

  insert into logistique.depotage_interne
    (soute_id, source_stock_id, destination_stock_id,
     type_carburant, quantite, utilisateur_id, motif)
  values (p_soute_id, v_source, v_destination,
          p_type_carburant, p_quantite, auth.uid(), p_motif)
  returning id into v_id;

  return v_id;
end $$;

grant execute on function logistique.depoter_en_interne(
  bigint, bigint, text, integer, text) to authenticated;

-- ============================================================================
-- Contrôle : doit retourner 0 ligne.
-- Une répartition supprimée qui garderait du carburant, ou la répartition
-- d'accueil marquée supprimée.
-- ============================================================================
select r.id, r.libelle,
       coalesce(sum(sts.qte_gasoil + sts.qte_super), 0) as litres
from logistique.repartition r
left join logistique.soute_type_stock sts on sts.repartition_id = r.id
where r.supprime_le is not null
group by r.id, r.libelle
having coalesce(sum(sts.qte_gasoil + sts.qte_super), 0) > 0
    or r.libelle = 'Activités Ordinaires';
