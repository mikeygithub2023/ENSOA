-- ============================================================================
-- Le personnel de l'école s'absente aussi, et part en permission.
--
-- Les absences (migration 008) et les permissions (007) ont été écrites
-- quand l'école ne tenait que des élèves : la phase y était obligatoire.
-- La Division de Commandement et Logistique est arrivée depuis, avec du
-- personnel qui ne suit aucune phase. Résultat : ses 255 militaires
-- paraissaient dans les deux onglets, sans qu'on puisse y porter la moindre
-- écriture — la base l'aurait refusée.
--
-- Un adjudant de l'école s'absente comme un élève, et part en permission
-- comme lui. La phase devient donc facultative, comme elle l'est déjà pour
-- les locaux disciplinaires (migration du même jour) et pour la fiche
-- elle-même.
--
-- Rien d'autre ne change : la division, elle, reste obligatoire, et c'est
-- elle qui borne la RLS. Les lignes déjà enregistrées portent toutes une
-- phase et la gardent.
-- ============================================================================

alter table scolarite.absences alter column classe_id drop not null;
alter table scolarite.permissions alter column classe_id drop not null;

comment on column scolarite.absences.classe_id is
  'La phase ou le stage où l''absence a été constatée. Nulle pour le '
  'personnel de l''école, qui ne suit ni l''une ni l''autre.';

comment on column scolarite.permissions.classe_id is
  'La phase ou le stage d''où part le permissionnaire. Nulle pour le '
  'personnel de l''école, qui ne suit ni l''une ni l''autre.';

-- ============================================================================
-- Contrôle : les trois colonnes doivent rendre « YES » — information_schema
-- répond YES/NO, et YES veut dire « n'est plus obligatoire ».
-- ============================================================================
select table_name, column_name, is_nullable
from information_schema.columns
where table_schema = 'scolarite'
  and table_name in ('absences', 'permissions', 'locaux_disciplinaires')
  and column_name = 'classe_id'
order by table_name;
