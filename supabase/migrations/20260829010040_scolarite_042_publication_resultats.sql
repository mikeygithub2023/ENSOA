-- ============================================================================
-- SCOLARITÉ (ENSOA GSES) — repris de 042_publication_resultats.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- Migration : publication des résultats d'un devoir.
--
-- La note reste cachée à l'élève tant que tous n'ont pas composé — sans quoi
-- les premiers en déduiraient les bonnes réponses et les transmettraient aux
-- suivants (voir la migration 041). Une fois le devoir clos, l'instructeur
-- publie les résultats et chacun voit le sien.
--
-- Le drapeau vit sur le devoir, pas sur la copie : on publie un devoir en
-- entier, jamais une copie isolée.
--
-- Fermé par défaut : un devoir tout juste créé ne divulgue rien.

alter table scolarite.cours
  add column resultats_publies boolean not null default false;

-- La fonction rend désormais la note, mais seulement si le devoir est
-- publié. Le filtre est ici, dans la base : l'application ne peut pas le
-- contourner puisque la note ne lui parvient tout simplement pas.
--
-- Les colonnes de sortie portent des noms distincts de ceux des tables :
-- une leçon de la migration 040, où l'homonymie avait rendu une requête
-- ambiguë.
drop function if exists scolarite.qcm_mes_compositions();

create function scolarite.qcm_mes_compositions()
returns table (
  devoir uuid,
  remis_le timestamptz,
  note_obtenue integer,
  bareme_total integer
)
language sql
security definer
set search_path = scolarite, socle, public
as $$
  select
    p.devoir_id,
    p.terminee_at,
    case when c.resultats_publies then p.note end,
    case when c.resultats_publies then p.bareme end
  from scolarite.qcm_participations p
  join scolarite.apprenants a on a.id = p.apprenant_id
  join scolarite.cours c on c.id = p.devoir_id
  where a.profile_id = auth.uid();
$$;

grant execute on function scolarite.qcm_mes_compositions() to authenticated;
