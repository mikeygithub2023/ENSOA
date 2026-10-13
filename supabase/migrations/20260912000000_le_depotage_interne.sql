-- ============================================================================
-- Le dépotage interne : servir une répartition sur les Activités Ordinaires.
--
-- Le carburant reçu entre dans « Activités Ordinaires ». Il faut maintenant
-- pouvoir en prélever pour servir BA1, CA1, CA2 — c'est la ventilation, une
-- décision de commandement qui vient après la réception.
--
-- CE N'EST PAS UN DÉPOTAGE, et cela n'entre donc pas dans la table des
-- dépotages. Un transfert interne ne fait pas entrer un litre de plus dans
-- l'école : l'inscrire comme une réception gonflerait les « entrées du
-- jour » du tableau de bord avec du carburant qui n'est jamais arrivé, et
-- le total de l'école cesserait de vouloir dire quelque chose. D'où une
-- table à part.
--
-- POURQUOI UNE FONCTION ET NON DEUX MISES À JOUR DEPUIS L'APPLICATION.
-- Trois raisons, dans l'ordre d'importance :
--
--   1. Le contrôle de solde doit être inviolable. L'application est un
--      binaire que son porteur contrôle ; un contrôle écrit dans Flutter se
--      contourne en appelant l'API directement. Ici, c'est la base qui
--      refuse de sortir plus que ce que contient la répartition.
--   2. L'atomicité. Deux mises à jour séparées, c'est du carburant qui
--      disparaît si la seconde échoue — réseau coupé, tablette éteinte.
--   3. La création à la demande de la ligne destinataire. Une répartition
--      qui n'a jamais rien reçu dans cette soute n'a pas encore de ligne de
--      stock ; la créer ici évite de l'oublier.
-- ============================================================================

create table if not exists logistique.depotage_interne (
  id bigint generated always as identity primary key,
  date timestamptz not null default now(),
  soute_id bigint references logistique.soute(id) not null,

  -- Les deux lignes de stock concernées. On les garde plutôt que les seules
  -- répartitions : une correction ultérieure doit pouvoir rendre exactement
  -- ce qu'elle a pris, à la ligne près.
  source_stock_id bigint references logistique.soute_type_stock(id) not null,
  destination_stock_id bigint references logistique.soute_type_stock(id) not null,

  type_carburant text not null check (type_carburant in ('Gasoil', 'Super')),
  quantite integer not null check (quantite > 0),
  utilisateur_id uuid references socle.profiles(id) not null,
  motif text,

  -- Se servir soi-même n'est pas un transfert.
  constraint depotage_interne_source_distincte
    check (source_stock_id <> destination_stock_id)
);

create index if not exists depotage_interne_soute_idx
  on logistique.depotage_interne (soute_id, date desc);

alter table logistique.depotage_interne enable row level security;

-- La lecture revient à l'école : le journal des mouvements internes fait
-- partie de ce que le commandement doit pouvoir relire.
drop policy if exists "depotage_interne select" on logistique.depotage_interne;
create policy "depotage_interne select" on logistique.depotage_interne
  for select to authenticated
  using (socle.est_de_l_ecole());

-- L'écriture passe exclusivement par la fonction ci-dessous : aucune
-- politique d'insertion directe. Une ligne posée à la main ne déplacerait
-- aucun carburant et ferait mentir le journal.
drop policy if exists admin_tout_pouvoir on logistique.depotage_interne;
create policy admin_tout_pouvoir on logistique.depotage_interne
  for all to authenticated
  using (socle.est_administrateur())
  with check (socle.est_administrateur());

grant select, insert, update, delete on logistique.depotage_interne to authenticated;
grant usage, select on all sequences in schema logistique to authenticated;

-- ============================================================================
-- Le transfert lui-même.
-- ============================================================================
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
  -- --- Qui a le droit ------------------------------------------------------
  -- La fonction s'exécute avec les droits de son auteur : elle doit donc
  -- vérifier elle-même, sans quoi elle serait une porte dérobée ouverte à
  -- tout compte connecté.
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

  -- --- La source : les Activités Ordinaires de cette soute -----------------
  select sts.id into v_source
  from logistique.soute_type_stock sts
  join logistique.repartition r on r.id = sts.repartition_id
  where sts.soute_id = p_soute_id
    and r.libelle = 'Activités Ordinaires';

  if v_source is null then
    raise exception
      'Cette soute n''a pas de répartition « Activités Ordinaires ».';
  end if;

  -- --- La destination, créée si elle n'existe pas encore -------------------
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

  -- --- Le solde ------------------------------------------------------------
  -- `for update` verrouille la ligne : deux soutiers qui ventilent la même
  -- soute en même temps ne peuvent pas lire tous deux le même disponible et
  -- le dépenser deux fois.
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

  -- --- Le mouvement --------------------------------------------------------
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
-- Un transfert dont la source ne serait pas une répartition d'accueil.
-- ============================================================================
select di.id
from logistique.depotage_interne di
join logistique.soute_type_stock sts on sts.id = di.source_stock_id
join logistique.repartition r on r.id = sts.repartition_id
where r.libelle <> 'Activités Ordinaires';
