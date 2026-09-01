-- ============================================================================
-- SCOLARITÉ (ENSOA GSES) — repris de 011_grade_defaut_eleves.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- Mise à jour ponctuelle : attribue le grade par défaut (mêmes règles que
-- lib/features/apprenants/grade_defaults.dart) aux élèves déjà enregistrés
-- avant l'introduction de cette fonctionnalité. N'écrase jamais un grade
-- déjà renseigné — ne comble que les grades vides.
update scolarite.apprenants a
set grade = case c.nom
  when 'FCB' then 'Elève sous-officier d''active de première année'
  when 'ESOA 1' then 'Elève sous-officier d''active de première année'
  when 'ESOA 2' then 'Elève sous-officier d''active de deuxième année'
  when 'ESOS 1' then 'Elève sous-officier spécialiste de première année'
  when 'ESOS 2' then 'Elève sous-officier spécialiste de deuxième année'
end
from scolarite.classes c
where a.classe_id = c.id
  and a.type = 'eleve'
  and (a.grade is null or trim(a.grade) = '')
  and c.nom in ('FCB', 'ESOA 1', 'ESOA 2', 'ESOS 1', 'ESOS 2');
