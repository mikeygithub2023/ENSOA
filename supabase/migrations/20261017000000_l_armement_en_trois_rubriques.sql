-- ============================================================================
-- L'armement se tient désormais en trois rubriques — Armement, Munitions,
-- Équipements — et chacune porte ses bons et son inventaire.
--
-- Deux choses changent en base.
--
-- 1. LA FICHE D'UNE ARME s'aligne sur le registre tenu à la main : une
--    désignation, un marquage, un numéro de série, une position actuelle,
--    un état, des observations. Les deux premières existaient déjà sous les
--    noms `type` et `modele` — seuls leurs libellés changent à l'écran, les
--    colonnes restent, et avec elles les bons de sortie qui s'y rattachent.
--    Les deux dernières manquaient : on les ajoute.
--
--    Les dates d'acquisition et d'inspection deviennent facultatives. Un
--    registre existant ne les porte pas, et les inventer à l'import —
--    « acquise aujourd'hui, à inspecter dans 90 jours » — remplirait
--    l'écran d'alertes fausses trois mois plus tard. Mieux vaut une case
--    vide qu'une date inventée.
--
--    L'ÉTAT D'UNE ARME devient ce que dit le registre : BON ou DÉFECTUEUX.
--    La colonne `etat` portait jusqu'ici quatre valeurs qui mêlaient deux
--    questions distinctes — en quel état est l'arme (bonne, défectueuse)
--    et où elle se trouve (à l'armurerie, en dotation). La seconde se lit
--    déjà ailleurs, et mieux : « position actuelle » dit où, et le bon de
--    sortie en cours dit chez qui. Seule la première reste un état.
--
--    `etat` n'est pas supprimée pour autant : les bons de sortie
--    continuent de l'écrire (`en_dotation` à la remise, `en_armurerie` au
--    retour), de sorte qu'une lecture SQL directe reste cohérente. Elle
--    n'est simplement plus montrée ni interrogée par l'application.
--
-- 2. LES MOUVEMENTS DE STOCK deviennent une écriture, et non plus un
--    ajustement muet.
--
--    Jusqu'ici, sortir 500 cartouches se faisait par un `update` du stock :
--    la quantité baissait, et rien ne disait qui les avait perçues, ni
--    quand, ni pourquoi. Une armurerie ne se tient pas ainsi. Désormais
--    toute entrée et toute sortie s'inscrit dans `mouvement_article`, et
--    c'est **le journal qui meut le stock** : un déclencheur applique le
--    mouvement à la quantité disponible.
--
--    L'ordre compte. Écrire le stock puis le journal laisserait, en cas
--    d'échec du second, un stock modifié sans trace. Ici les deux sont une
--    seule écriture, dans une seule transaction : ou les deux, ou aucune.
--
--    Le déclencheur refuse également de descendre sous zéro. Un stock
--    négatif n'est pas une donnée, c'est une erreur de saisie — et le
--    message le dit en clair, avec le reste disponible.
-- ============================================================================

-- --- 1. La fiche d'une arme ------------------------------------------------

alter table logistique.arme
  add column if not exists position_actuelle text;

alter table logistique.arme
  add column if not exists observations text;

alter table logistique.arme
  alter column date_acquisition drop not null;

alter table logistique.arme
  alter column prochaine_inspection drop not null;

comment on column logistique.arme.type is
  'Désignation de l''arme (PA, PM, FA...). Nommée « Type d''arme » jusqu''au '
  '17 octobre 2026 ; la colonne n''a pas changé, seul son libellé.';
comment on column logistique.arme.modele is
  'Marquage porté par l''arme. Nommé « Modèle » jusqu''au 17 octobre 2026.';
comment on column logistique.arme.position_actuelle is
  'Où se trouve l''arme : armurerie, compagnie, atelier...';

-- L'état au sens du registre : bon ou défectueux, rien d'autre.
alter table logistique.arme
  add column if not exists etat_general text not null default 'bon';

do $$
begin
  if not exists (
    select 1 from pg_constraint
     where conrelid = 'logistique.arme'::regclass
       and conname = 'arme_etat_general_connu'
  ) then
    alter table logistique.arme
      add constraint arme_etat_general_connu
      check (etat_general in ('bon', 'defectueux'));
  end if;
end $$;

-- Reprise de l'existant. Une arme en maintenance ou réformée était, de
-- fait, défectueuse ; les autres sont bonnes. Le `default` ci-dessus a
-- déjà mis 'bon' partout, on ne corrige donc que les deux cas.
update logistique.arme
   set etat_general = 'defectueux'
 where etat in ('en_maintenance', 'reforme');

comment on column logistique.arme.etat_general is
  'L''état au sens du registre : bon ou defectueux. C''est l''« État » '
  'que montre l''application depuis le 17 octobre 2026.';
comment on column logistique.arme.etat is
  'Situation interne, écrite par les bons de sortie (en_dotation / '
  'en_armurerie). Plus affichée ni interrogée par l''application : « où '
  'se trouve l''arme » se lit sur position_actuelle et sur le bon en '
  'cours.';

-- --- 2. Le journal des mouvements de munitions et d'équipements ------------

create table if not exists logistique.mouvement_article (
  id bigint generated always as identity primary key,
  -- Deux clés étrangères plutôt qu'un couple (famille, identifiant) : la
  -- base garde ainsi la main sur l'intégrité. Un mouvement ne peut pas
  -- désigner un calibre effacé, ni viser les deux familles à la fois.
  munition_id bigint references logistique.stock_munition(id),
  equipement_id bigint references logistique.equipement_protection(id),
  sens text not null check (sens in ('entree', 'sortie')),
  quantite integer not null check (quantite > 0),
  beneficiaire_matricule text,
  beneficiaire_nom text,
  motif text,
  date timestamptz not null default now(),
  auteur_id uuid references socle.profiles(id),
  constraint mouvement_article_un_seul_article check (
    (munition_id is not null)::int + (equipement_id is not null)::int = 1
  )
);

create index if not exists mouvement_article_munition_idx
  on logistique.mouvement_article (munition_id, date desc);
create index if not exists mouvement_article_equipement_idx
  on logistique.mouvement_article (equipement_id, date desc);

alter table logistique.mouvement_article enable row level security;

drop policy if exists "mouvement_article acces" on logistique.mouvement_article;
create policy "mouvement_article acces"
  on logistique.mouvement_article for all to authenticated
  using (socle.current_user_role() in ('armurerie', 'chef_soutien_technique'))
  with check (socle.current_user_role() in ('armurerie', 'chef_soutien_technique'));

drop policy if exists "mouvement_article_admin_ecriture"
  on logistique.mouvement_article;
create policy "mouvement_article_admin_ecriture"
  on logistique.mouvement_article for all to authenticated
  using (socle.current_user_role() = 'administrateur')
  with check (socle.current_user_role() = 'administrateur');

-- --- Le déclencheur qui meut le stock --------------------------------------

create or replace function logistique.appliquer_mouvement_article()
returns trigger
language plpgsql
as $$
declare
  v_delta integer;
  v_reste integer;
  v_nom text;
begin
  v_delta := case when new.sens = 'sortie' then -new.quantite
                  else new.quantite end;

  if new.munition_id is not null then
    select quantite_disponible, 'le calibre ' || calibre
      into v_reste, v_nom
      from logistique.stock_munition
     where id = new.munition_id
     for update;
  else
    select quantite_disponible, libelle
      into v_reste, v_nom
      from logistique.equipement_protection
     where id = new.equipement_id
     for update;
  end if;

  if v_reste + v_delta < 0 then
    -- Un message que l'utilisateur peut lire et corriger : il nomme
    -- l'article, ce qu'on demande et ce qui reste. (`raise exception`
    -- remonte en SQLSTATE P0001, que l'application affiche tel quel.)
    raise exception
      'Stock insuffisant : vous sortez % de % alors qu''il n''en reste que %.',
      new.quantite, v_nom, v_reste;
  end if;

  if new.munition_id is not null then
    update logistique.stock_munition
       set quantite_disponible = quantite_disponible + v_delta
     where id = new.munition_id;
  else
    update logistique.equipement_protection
       set quantite_disponible = quantite_disponible + v_delta
     where id = new.equipement_id;
  end if;

  return new;
end $$;

drop trigger if exists appliquer_mouvement_article
  on logistique.mouvement_article;
create trigger appliquer_mouvement_article
  after insert on logistique.mouvement_article
  for each row execute function logistique.appliquer_mouvement_article();

-- --- Le garde-fou des déclencheurs (migration du 14 septembre) -------------
--
-- Il parcourt toutes les fonctions de déclencheur des trois schémas et
-- refuse celles qui lisent un `new.x` absent de la table. On le relance ici
-- pour que la fonction ajoutée au-dessus y passe comme les autres.

do $$
declare
  r record;
  m text[];
  v_table text;
begin
  for r in
    select p.oid, p.proname, prosrc as src,
           c.relname as tbl, n.nspname as sch
      from pg_trigger t
      join pg_proc p on p.oid = t.tgfoid
      join pg_class c on c.oid = t.tgrelid
      join pg_namespace n on n.oid = c.relnamespace
     where not t.tgisinternal
       and n.nspname in ('socle', 'scolarite', 'logistique')
  loop
    for m in select regexp_matches(r.src, '\m(new|old)\.([a-z_][a-z0-9_]*)', 'gi')
    loop
      v_table := m[2];
      if not exists (
        select 1 from information_schema.columns
         where table_schema = r.sch and table_name = r.tbl
           and column_name = lower(v_table)
      ) then
        raise exception
          'Le déclencheur %.% lit %.% — cette colonne n''existe pas sur %.%',
          r.sch, r.proname, lower(m[1]), v_table, r.sch, r.tbl;
      end if;
    end loop;
  end loop;
end $$;
