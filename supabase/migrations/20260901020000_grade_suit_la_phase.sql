-- ============================================================================
-- Le grade de l'élève suit sa phase.
--
-- Un élève en FCB ou en CA 1 est « Élève sous-officier d'active de première
-- année » ; en CA 2, il est « de deuxième année ». Ce n'est pas une étiquette
-- qu'on choisit : c'est une conséquence de la phase où il se trouve.
--
-- L'application propose déjà ce grade à l'inscription et à l'import. Il
-- manquait le moment qui compte le plus : la clôture d'une phase, où les
-- élèves passent à la suivante. Sans quoi une promotion entière passait en
-- CA 2 en restant « de première année » sur ses bulletins.
--
-- La règle est écrite ici, côté serveur, parce que c'est ici que la migration
-- des élèves a lieu — en une transaction, avec elle.
-- ============================================================================

create or replace function scolarite.grade_de_la_phase(p_nom text)
returns text
language sql
immutable
as $$
  -- Les noms se saisissent à la main : « CA 1 », « CA1 », « ca 1 » désignent
  -- la même phase. On compare donc sans espaces ni casse.
  select case upper(replace(coalesce(p_nom, ''), ' ', ''))
    when 'FCB'    then 'Elève sous-officier d''active de première année'
    when 'CA1'    then 'Elève sous-officier d''active de première année'
    when 'ESOA1'  then 'Elève sous-officier d''active de première année'
    when 'CA2'    then 'Elève sous-officier d''active de deuxième année'
    when 'ESOA2'  then 'Elève sous-officier d''active de deuxième année'
    when 'ESOS1'  then 'Elève sous-officier spécialiste de première année'
    when 'ESOS2'  then 'Elève sous-officier spécialiste de deuxième année'
    else null
  end;
$$;

comment on function scolarite.grade_de_la_phase(text) is
  'Le grade que porte un élève du fait de la phase où il se trouve. Nul pour '
  'une phase hors barème — le grade saisi est alors conservé tel quel.';

-- --- La clôture emmène le grade avec l'élève --------------------------------
--
-- On ne touche qu'aux élèves effectivement déplacés, et seulement quand la
-- phase d'arrivée a un grade au barème : un grade saisi à la main pour une
-- phase hors barème n'est pas écrasé.
create or replace function scolarite.appliquer_grade_de_phase()
returns trigger
language plpgsql
as $$
declare
  v_grade text;
begin
  if new.classe_id is distinct from old.classe_id then
    select scolarite.grade_de_la_phase(c.nom) into v_grade
    from scolarite.classes c
    where c.id = new.classe_id and c.type = 'phase';

    if v_grade is not null then
      new.grade := v_grade;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists apprenant_grade_suit_la_phase on scolarite.apprenants;

-- Sur `before update` : le grade est corrigé dans la même écriture que le
-- changement de phase, qu'il vienne de la clôture d'une phase ou d'une
-- correction à la main depuis la fiche de l'élève.
create trigger apprenant_grade_suit_la_phase
  before update on scolarite.apprenants
  for each row
  execute function scolarite.appliquer_grade_de_phase();
