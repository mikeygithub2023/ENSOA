-- ============================================================================
-- SCOLARITÉ (ENSOA GSES) — repris de 044_profil_matieres_eleve.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- Migration : l'élève ne voit plus ni note ni rang, mais son niveau par
-- matière.
--
-- Une note chiffrée et un rang se comparent, s'échangent dans la chambrée et
-- finissent en confrontation. Un niveau par matière dit à l'élève où porter
-- son effort sans lui donner de quoi se mesurer à ses camarades.
--
-- Le chiffre ne quitte donc plus le serveur : la fonction ci-dessous calcule
-- la moyenne par matière et ne rend que le niveau atteint. Rien dans la
-- réponse ne permet de reconstituer une note, et encore moins celle d'un
-- autre.
--
-- Les quatre fonctions de la migration 043 sont supprimées :
--   * `mes_resultats()` et `mon_classement()` rendaient précisément ce que
--     l'on veut désormais taire ;
--   * `note_au_controle()` et `moyenne_apprenant()` étaient `security
--     definer` et, faute de révocation explicite, exécutables par tout
--     utilisateur connecté — un élève qui aurait connu l'identifiant d'un
--     camarade aurait obtenu sa moyenne. Elles n'ont plus d'appelant : on
--     les retire plutôt que de les garder sous clé.

drop function if exists scolarite.mes_resultats();
drop function if exists scolarite.mon_classement();
drop function if exists scolarite.moyenne_apprenant(uuid);
drop function if exists scolarite.note_au_controle(uuid, uuid);

-- Niveau de l'élève connecté dans chacune des matières où il a été noté.
--
-- La moyenne d'une matière pondère chaque note par le coefficient de
-- l'évaluation dont elle provient : un examen y pèse plus qu'un contrôle
-- continu, comme au bulletin. Une matière où il n'a aucune note n'apparaît
-- pas — elle n'est pas un point faible, elle n'a simplement pas encore été
-- évaluée.
--
-- Les seuils sont ceux de la notation de l'école, sur 20 :
--   14 et plus : fort — 10 à 14 : moyen — moins de 10 : faible.
--
-- Les paramètres de sortie portent des noms distincts des colonnes du corps
-- (`matiere_nom` et non `nom`) : une homonymie rendrait la référence
-- ambiguë et la fonction échouerait à l'exécution.
create function scolarite.mon_profil_matieres()
returns table (
  matiere_nom text,
  matiere_code text,
  niveau_atteint text,
  nombre_notes integer
)
language sql
security definer
set search_path = scolarite, socle, public
as $$
  with moi as (
    select a.id
    from scolarite.apprenants a
    where a.profile_id = auth.uid()
  ),
  par_matiere as (
    select
      n.matiere_id as mid,
      sum(n.note * c.coefficient) / nullif(sum(c.coefficient), 0) as moy,
      count(*)::integer as nb
    from scolarite.notes n
    join scolarite.controles c on c.id = n.controle_id
    join moi on n.apprenant_id = moi.id
    group by n.matiere_id
  )
  select
    m.nom,
    m.code,
    case
      when pm.moy >= 14 then 'fort'
      when pm.moy >= 10 then 'moyen'
      else 'faible'
    end,
    pm.nb
  from par_matiere pm
  join scolarite.matieres m on m.id = pm.mid
  where pm.moy is not null
  order by pm.moy desc, m.nom;
$$;

-- Exécutable par les seuls utilisateurs connectés — et pour chacun, la
-- fonction ne lit que ses propres notes, quelle que soit la main qui
-- l'appelle.
revoke execute on function scolarite.mon_profil_matieres() from public;
grant execute on function scolarite.mon_profil_matieres() to authenticated;
