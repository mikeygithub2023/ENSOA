-- Le grade d'un élève suit sa phase — et sa division.
--
-- La règle écrite le 1er septembre ne regardait que le nom de la phase :
-- « FCB » donnait « élève sous-officier d'active de première année », pour
-- tout le monde. Or la Formation Commune de Base se fait des deux côtés de
-- l'école : la Division de Formation Initiale la fait passer à ses
-- généralistes, la Division de Formation des Spécialistes à ses
-- spécialistes. Les seconds sont élèves sous-officiers *spécialistes*, et
-- c'est ce que doivent porter leurs bulletins.
--
-- Les phases déjà nommées ESOS 1 et ESOS 2 disaient la spécialité dans leur
-- nom ; FCB, CA 1 et CA 2 ne la disent pas. La division tranche désormais.
--
-- La même règle vit côté application, dans
-- `lib/modules/scolarite/features/apprenants/grade_defaults.dart` : si vous
-- modifiez ce barème, modifiez aussi celui-là.

-- L'ancienne forme à un seul argument s'en va : la laisser vivre à côté de
-- la nouvelle, c'est garder une règle qui se trompe sur la moitié de
-- l'école, et laisser le hasard de l'appel décider laquelle s'applique.
drop function if exists scolarite.grade_de_la_phase(text);

create or replace function scolarite.grade_de_la_phase(
  p_nom text,
  p_division_code text
)
returns text
language sql
immutable
as $$
  -- Les noms se saisissent à la main : « CA 1 », « CA1 », « ca 1 » désignent
  -- la même phase. On compare donc sans espaces ni casse.
  select case upper(replace(coalesce(p_nom, ''), ' ', ''))
    when 'FCB'    then case when p_division_code = 'formation_specialistes'
                         then 'Elève sous-officier spécialiste de première année'
                         else 'Elève sous-officier d''active de première année'
                       end
    when 'CA1'    then case when p_division_code = 'formation_specialistes'
                         then 'Elève sous-officier spécialiste de première année'
                         else 'Elève sous-officier d''active de première année'
                       end
    when 'ESOA1'  then 'Elève sous-officier d''active de première année'
    when 'CA2'    then case when p_division_code = 'formation_specialistes'
                         then 'Elève sous-officier spécialiste de deuxième année'
                         else 'Elève sous-officier d''active de deuxième année'
                       end
    when 'ESOA2'  then 'Elève sous-officier d''active de deuxième année'
    when 'ESOS1'  then 'Elève sous-officier spécialiste de première année'
    when 'ESOS2'  then 'Elève sous-officier spécialiste de deuxième année'
    else null
  end;
$$;

comment on function scolarite.grade_de_la_phase(text, text) is
  'Le grade que porte un élève du fait de la phase où il se trouve et de la '
  'division qui la donne : en FCB, CA 1 et CA 2, un spécialiste est élève '
  'sous-officier spécialiste. Nul pour une phase hors barème — le grade '
  'saisi est alors conservé tel quel.';

-- --- Le déclencheur lit maintenant la division de la phase d'arrivée --------
create or replace function scolarite.appliquer_grade_de_phase()
returns trigger
language plpgsql
as $$
declare
  v_grade text;
begin
  if new.classe_id is distinct from old.classe_id then
    -- La division est celle de la phase d'arrivée, pas celle que porte la
    -- fiche : un élève qui change de division change de grade avec elle.
    select scolarite.grade_de_la_phase(c.nom, d.code) into v_grade
    from scolarite.classes c
    join socle.divisions d on d.id = c.division_id
    where c.id = new.classe_id and c.type = 'phase';

    if v_grade is not null then
      new.grade := v_grade;
    end if;
  end if;
  return new;
end;
$$;

-- --- Les élèves déjà enregistrés -------------------------------------------
-- Ceux de la Division de Formation des Spécialistes portent le grade des
-- généralistes : c'est précisément ce que la règle vient corriger. On ne
-- touche qu'à ceux dont le grade est au barème — un grade saisi à la main
-- pour un cas particulier n'est pas écrasé.
update scolarite.apprenants a
set grade = scolarite.grade_de_la_phase(c.nom, d.code)
from scolarite.classes c
join socle.divisions d on d.id = c.division_id
where c.id = a.classe_id
  and c.type = 'phase'
  and d.code = 'formation_specialistes'
  and a.grade in (
    'Elève sous-officier d''active de première année',
    'Elève sous-officier d''active de deuxième année'
  )
  and scolarite.grade_de_la_phase(c.nom, d.code) is not null;
