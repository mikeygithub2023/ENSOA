-- ============================================================================
-- Toute soute a ses « Activités Ordinaires ».
--
-- Jusqu'ici, enregistrer un dépotage demandait de désigner la répartition
-- bénéficiaire : le carburant entrait directement dans BA1, CA1 ou CA2. Cela
-- ne correspond pas à la réalité du dépôt — un camion-citerne livre DANS LA
-- SOUTE, pas dans une affectation. La ventilation vient après, et c'est une
-- décision de commandement, pas un geste de réception.
--
-- Le carburant reçu entre donc désormais dans une répartition unique, née
-- avec la soute : « Activités Ordinaires ». Les autres répartitions se
-- serviront plus tard par un dépotage interne, prélevé sur celle-ci — ce qui
-- n'est pas l'objet de cette migration, mais que ce modèle rend possible
-- sans rien changer d'autre.
--
-- POURQUOI UN DÉCLENCHEUR ET NON UNE LIGNE DANS L'ÉCRAN. Une soute créée
-- sans sa répartition d'accueil serait une soute où l'on ne peut rien
-- déposer, et rien à l'écran ne dirait pourquoi. La base le garantit, et
-- elle le garantit aussi pour une soute créée à la main ou par import.
-- ============================================================================

-- --- La répartition d'accueil, commune à toutes les soutes ------------------
-- `repartition.libelle` est unique : il n'existe qu'une ligne « Activités
-- Ordinaires », et chaque soute s'y rattache par sa propre ligne de stock.
-- C'est le modèle existant — une répartition vit dans plusieurs soutes à la
-- fois —, on ne le change pas.
insert into logistique.repartition (libelle)
values ('Activités Ordinaires')
on conflict (libelle) do nothing;

-- --- Toute soute nouvelle reçoit sa ligne -----------------------------------
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
  where libelle = 'Activités Ordinaires';

  -- `type_stock_id` reste nul : une ligne de stock porte à la fois le gasoil
  -- et le super, dans deux colonnes. Le type n'y ajoute rien, et le
  -- renseigner obligerait à choisir arbitrairement l'un des deux.
  insert into logistique.soute_type_stock
    (soute_id, repartition_id, type_stock_id,
     qte_gasoil, qte_super, seuil_nominal, seuil_critique)
  values (new.id, v_repartition, null, 0, 0, 0, 0);

  return new;
end $$;

drop trigger if exists ouvrir_les_activites_ordinaires on logistique.soute;
create trigger ouvrir_les_activites_ordinaires
after insert on logistique.soute
for each row execute function logistique.ouvrir_les_activites_ordinaires();

-- --- Les soutes déjà ouvertes rattrapent leur retard ------------------------
insert into logistique.soute_type_stock
  (soute_id, repartition_id, type_stock_id,
   qte_gasoil, qte_super, seuil_nominal, seuil_critique)
select s.id, r.id, null, 0, 0, 0, 0
from logistique.soute s
cross join logistique.repartition r
where r.libelle = 'Activités Ordinaires'
  and not exists (
    select 1 from logistique.soute_type_stock sts
    where sts.soute_id = s.id and sts.repartition_id = r.id
  );

-- ============================================================================
-- Contrôle : doit retourner 0 ligne.
-- Une soute où l'on ne pourrait rien déposer.
-- ============================================================================
select s.id, s.libelle
from logistique.soute s
where not exists (
  select 1
  from logistique.soute_type_stock sts
  join logistique.repartition r on r.id = sts.repartition_id
  where sts.soute_id = s.id and r.libelle = 'Activités Ordinaires'
);
